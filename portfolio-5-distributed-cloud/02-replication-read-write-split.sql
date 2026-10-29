-- Primary-Replica Replication & Read-Write Query Splitting
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: FinPay Technologies Ltd
-- Author: Folajimi

-- Clean teardown of simulation metadata objects if re-running
DROP FUNCTION IF EXISTS fn_route_finpay_query(TEXT, VARCHAR, BOOLEAN) CASCADE;
DROP TABLE IF EXISTS distributed_cluster_nodes CASCADE;
DROP PUBLICATION IF EXISTS finpay_ledger_pub;

\echo '1. Configuring FinPay Multi-Region Cluster Topology Registry'

CREATE TABLE distributed_cluster_nodes (
    node_id VARCHAR(30) PRIMARY KEY,
    region VARCHAR(40) NOT NULL,
    availability_zone VARCHAR(30) NOT NULL,
    node_role VARCHAR(20) NOT NULL CHECK (node_role IN ('PRIMARY_WRITER', 'SYNC_STANDBY', 'ASYNC_READ_REPLICA')),
    endpoint_host VARCHAR(100) NOT NULL,
    replication_mode VARCHAR(20) NOT NULL CHECK (replication_mode IN ('PRIMARY', 'SYNCHRONOUS', 'ASYNCHRONOUS')),
    measured_lag_ms NUMERIC(8, 2) NOT NULL DEFAULT 0.00,
    node_status VARCHAR(20) NOT NULL DEFAULT 'HEALTHY' CHECK (node_status IN ('HEALTHY', 'DEGRADED', 'OFFLINE')),
    last_heartbeat TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO distributed_cluster_nodes (
    node_id, region, availability_zone, node_role, endpoint_host, replication_mode, measured_lag_ms, node_status
) VALUES
    ('finpay-pg-primary-01', 'NG-Lagos (Local Zone)', 'af-south-1-los-1a', 'PRIMARY_WRITER',     'pg-primary.lagos.internal.finpay.ng:5432',  'PRIMARY',      0.00,  'HEALTHY'),
    ('finpay-pg-standby-02', 'NG-Lagos (Victoria Isl)', 'af-south-1-los-1b', 'SYNC_STANDBY',     'pg-standby.lagos.internal.finpay.ng:5432',  'SYNCHRONOUS',  1.45,  'HEALTHY'),
    ('finpay-pg-replica-03', 'NG-Abuja (Central)',      'af-south-1a',       'ASYNC_READ_REPLICA','pg-replica.abuja.internal.finpay.ng:5432',  'ASYNCHRONOUS', 14.80, 'HEALTHY'),
    ('finpay-pg-dr-04',      'EU-West (Ireland DR)',    'eu-west-1a',        'ASYNC_READ_REPLICA','pg-dr.dublin.internal.finpay.ng:5432',      'ASYNCHRONOUS', 68.25, 'HEALTHY');

SELECT
    node_id,
    region,
    node_role,
    replication_mode,
    measured_lag_ms,
    node_status
FROM distributed_cluster_nodes
ORDER BY measured_lag_ms ASC;

\echo '2. Creating Logical Replication Publication for Core Ledger Tables'

-- Publish core FinPay tables for downstream analytical and cross-region replicas
CREATE PUBLICATION finpay_ledger_pub
    FOR TABLE accounts, transactions, transfers, fraud_alerts
    WITH (publish = 'insert, update');

SELECT
    pubname,
    puballtables,
    pubinsert,
    pubupdate,
    pubdelete
FROM pg_publication
WHERE pubname = 'finpay_ledger_pub';

SELECT
    pubname,
    schemaname,
    tablename
FROM pg_publication_tables
WHERE pubname = 'finpay_ledger_pub'
ORDER BY tablename;

\echo '3. Inspecting Live PostgreSQL WAL Position and Recovery Role'

SELECT
    pg_is_in_recovery() AS is_read_replica,
    CASE WHEN pg_is_in_recovery() THEN 'READ_REPLICA_STANDBY' ELSE 'PRIMARY_READ_WRITE_LEADER' END AS active_engine_role,
    pg_current_wal_lsn() AS current_wal_lsn,
    pg_walfile_name(pg_current_wal_lsn()) AS active_wal_segment_file,
    current_setting('wal_level') AS configured_wal_level,
    current_setting('max_wal_senders') AS max_wal_senders;

\echo '4. Implementing Read-Write Query Router Function (PgBouncer / ProxySQL Routing Logic)'

CREATE OR REPLACE FUNCTION fn_route_finpay_query(
    p_sql_operation TEXT,
    p_workflow_category VARCHAR(40),
    p_require_read_your_writes BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    selected_node_id VARCHAR(30),
    selected_region VARCHAR(40),
    selected_role VARCHAR(20),
    endpoint VARCHAR(100),
    routing_reason TEXT
) AS $$
DECLARE
    v_is_mutation BOOLEAN;
BEGIN
    v_is_mutation := (
        p_sql_operation ~* '^\s*(INSERT|UPDATE|DELETE|CALL|SELECT\s+\*\s+FROM\s+sp_execute_fund_transfer)'
        OR p_sql_operation ~* 'FOR\s+UPDATE'
    );

    IF v_is_mutation THEN
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            'Write/Lock operation detected: routed strictly to Primary Writer with synchronous standby commit.'::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role = 'PRIMARY_WRITER'
          AND n.node_status = 'HEALTHY'
        LIMIT 1;

    ELSIF p_require_read_your_writes THEN
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            'Session consistency required (Read-Your-Own-Writes after transfer): routed to Sync Standby (lag < 2ms).'::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role IN ('SYNC_STANDBY', 'PRIMARY_WRITER')
          AND n.node_status = 'HEALTHY'
        ORDER BY CASE WHEN n.node_role = 'SYNC_STANDBY' THEN 1 ELSE 2 END
        LIMIT 1;

    ELSE
        RETURN QUERY
        SELECT
            n.node_id,
            n.region,
            n.node_role,
            n.endpoint_host,
            ('Read-only analytical workload (' || p_workflow_category || '): offloaded to lowest-lag Async Read Replica.')::TEXT
        FROM distributed_cluster_nodes n
        WHERE n.node_role = 'ASYNC_READ_REPLICA'
          AND n.node_status = 'HEALTHY'
          AND n.measured_lag_ms < 50.00
        ORDER BY n.measured_lag_ms ASC
        LIMIT 1;
    END IF;
END;
$$ LANGUAGE plpgsql;

\echo '5. Verifying Read-Write Splitting Across FinPay Operational Workloads'

-- Workload A: P2P Fund Transfer (Write / Row Lock)
SELECT * FROM fn_route_finpay_query(
    'SELECT * FROM sp_execute_fund_transfer(''0123456789'', ''0223456781'', ''000000'', ''FinPay'', ''Sarah Okafor'', 15000, ''Rent'')',
    'CORE_LEDGER_TRANSFER',
    TRUE
);

-- Workload B: Post-Transfer Immediate Balance Check (Read-Your-Writes Consistency)
SELECT * FROM fn_route_finpay_query(
    'SELECT available_balance FROM accounts WHERE account_number = ''0123456789''',
    'POST_TRANSFER_BALANCE_CHECK',
    TRUE
);

-- Workload C: Monthly Statement & EOD NIP Settlement Report (Heavy Analytical Read)
SELECT * FROM fn_route_finpay_query(
    'SELECT destination_bank_code, count(*), sum(amount) FROM transfers GROUP BY destination_bank_code',
    'EOD_SETTLEMENT_ANALYTICS',
    FALSE
);

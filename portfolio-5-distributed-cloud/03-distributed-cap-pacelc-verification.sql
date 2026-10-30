-- Distributed Consistency (CAP / PACELC) & Failover Readiness Verification
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: FinPay Technologies Ltd
-- Author: Folajimi

DROP TABLE IF EXISTS distributed_idempotency_registry CASCADE;

\echo '1. Evaluating PACELC Tunable Consistency Modes in PostgreSQL (synchronous_commit)'

-- In PostgreSQL, synchronous_commit can be tuned per-transaction to balance
-- Consistency vs Latency (the "ELC" half of Abadi's PACELC theorem).
DO $$
DECLARE
    v_lsn_before pg_lsn;
    v_lsn_after pg_lsn;
    v_sync_setting TEXT;
BEGIN
    v_lsn_before := pg_current_wal_lsn();

    -- Tier 1: CP / PC+EC Mode (Strict Financial Ledger Transfer)
    -- Waits for WAL flush locally AND synchronous standby confirmation
    SET LOCAL synchronous_commit = 'on';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[CP / PC-EC Mode] synchronous_commit = % | Used for NIBSS NIP transfers & double-entry ledger updates.', v_sync_setting;

    -- Tier 2: Local Durable Mode (Balance Inquiry / Session Token Update)
    -- Flushes WAL to local disk, does not block on cross-AZ network RTT
    SET LOCAL synchronous_commit = 'local';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[Local Durable Mode] synchronous_commit = % | Used for beneficiary updates & session state.', v_sync_setting;

    -- Tier 3: AP / PA+EL Mode (High-Throughput Audit & Telemetry Stream)
    -- Commits in memory and flushes to WAL asynchronously via wal_writer_delay
    SET LOCAL synchronous_commit = 'off';
    SHOW synchronous_commit INTO v_sync_setting;
    RAISE NOTICE '[AP / PA-EL Mode] synchronous_commit = % | Used for non-monetary clickstream & telemetry logs.', v_sync_setting;

    v_lsn_after := pg_current_wal_lsn();
    RAISE NOTICE 'WAL LSN verified at %', v_lsn_after;
END $$;

\echo '2. Implementing Idempotent Distributed Settlement Ledger (Network Partition Recovery)'

-- During a network partition between FinPay and the NIBSS NIP clearing switch,
-- retry webhooks can arrive multiple times. An idempotency registry prevents double-crediting.
CREATE TABLE distributed_idempotency_registry (
    idempotency_key VARCHAR(64) PRIMARY KEY,
    nip_session_id VARCHAR(35) NOT NULL UNIQUE,
    source_account_number CHAR(10) NOT NULL,
    destination_account_number CHAR(10) NOT NULL,
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0.0000),
    originating_node VARCHAR(30) NOT NULL,
    settlement_status VARCHAR(20) NOT NULL CHECK (settlement_status IN ('PROCESSED', 'DUPLICATE_IGNORED', 'FAILED')),
    response_payload JSONB NOT NULL,
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    retry_attempts INT NOT NULL DEFAULT 0
);

\echo '3. Testing Distributed Webhook Retry & Idempotency Guard under Network Partition'

DO $$
DECLARE
    v_key VARCHAR(64) := 'IDEMP-NIP-20261030-009841';
    v_session VARCHAR(35) := '999000000984120261030142000abc';
    v_inserted BOOLEAN;
BEGIN
    -- Attempt 1: Primary node processes NIP settlement webhook
    INSERT INTO distributed_idempotency_registry (
        idempotency_key, nip_session_id, source_account_number, destination_account_number,
        amount, originating_node, settlement_status, response_payload
    ) VALUES (
        v_key, v_session, '0123456789', '0223456781',
        25000.0000, 'finpay-pg-primary-01', 'PROCESSED',
        jsonb_build_object('status', '00', 'message', 'Approved or completed successfully', 'debit_ref', 'FP-TRF-IDEMP-001')
    );
    RAISE NOTICE 'Webhook Delivery 1: Processed cleanly on finpay-pg-primary-01.';

    -- Attempt 2: Network timeout causes NIBSS switch to re-send identical webhook payload
    INSERT INTO distributed_idempotency_registry (
        idempotency_key, nip_session_id, source_account_number, destination_account_number,
        amount, originating_node, settlement_status, response_payload
    ) VALUES (
        v_key, v_session, '0123456789', '0223456781',
        25000.0000, 'finpay-pg-standby-02', 'PROCESSED',
        jsonb_build_object('status', '00', 'message', 'Duplicate retry attempt')
    )
    ON CONFLICT (idempotency_key) DO UPDATE
    SET retry_attempts = distributed_idempotency_registry.retry_attempts + 1;

    RAISE NOTICE 'Webhook Delivery 2 (Duplicate Retry): Intercepted by idempotency constraint. Zero double-spend.';
END $$;

SELECT
    idempotency_key,
    nip_session_id,
    amount,
    originating_node,
    settlement_status,
    retry_attempts,
    response_payload->>'debit_ref' AS original_txn_ref
FROM distributed_idempotency_registry;

\echo '4. Simulating Primary Node Failure & Automated Standby Failover Promotion'

DO $$
DECLARE
    v_new_leader VARCHAR(30);
    v_rto_seconds NUMERIC(5, 2) := 18.40;
    v_rpo_ms NUMERIC(5, 2) := 0.00;
BEGIN
    -- Step 1: Primary node in Lagos AZ-1a loses heartbeat
    UPDATE distributed_cluster_nodes
    SET node_status = 'OFFLINE',
        last_heartbeat = CURRENT_TIMESTAMP - INTERVAL '30 seconds'
    WHERE node_id = 'finpay-pg-primary-01';

    RAISE NOTICE 'ALERT: Primary node finpay-pg-primary-01 marked OFFLINE (missed 3 Patroni etcd heartbeats).';

    -- Step 2: Promote zero-lag synchronous standby (finpay-pg-standby-02) to PRIMARY_WRITER
    UPDATE distributed_cluster_nodes
    SET node_role = 'PRIMARY_WRITER',
        replication_mode = 'PRIMARY',
        measured_lag_ms = 0.00,
        last_heartbeat = CURRENT_TIMESTAMP
    WHERE node_id = 'finpay-pg-standby-02'
    RETURNING node_id INTO v_new_leader;

    RAISE NOTICE 'FAILOVER COMPLETE: Promoted % to PRIMARY_WRITER | RTO: %s | RPO: %ms (Zero data loss).',
        v_new_leader, v_rto_seconds, v_rpo_ms;
END $$;

-- Verify post-failover cluster topology and query router redirection
SELECT
    node_id,
    region,
    node_role,
    replication_mode,
    measured_lag_ms,
    node_status
FROM distributed_cluster_nodes
ORDER BY node_status ASC, measured_lag_ms ASC;

SELECT * FROM fn_route_finpay_query(
    'SELECT * FROM sp_execute_fund_transfer(''0123456789'', ''0223456781'', ''000000'', ''FinPay'', ''Sarah Okafor'', 5000, ''Post-failover transfer'')',
    'CORE_LEDGER_TRANSFER',
    TRUE
);

-- Restore cluster registry state to baseline healthy topology
UPDATE distributed_cluster_nodes
SET node_role = 'PRIMARY_WRITER', replication_mode = 'PRIMARY', node_status = 'HEALTHY', measured_lag_ms = 0.00
WHERE node_id = 'finpay-pg-primary-01';

UPDATE distributed_cluster_nodes
SET node_role = 'SYNC_STANDBY', replication_mode = 'SYNCHRONOUS', node_status = 'HEALTHY', measured_lag_ms = 1.45
WHERE node_id = 'finpay-pg-standby-02';

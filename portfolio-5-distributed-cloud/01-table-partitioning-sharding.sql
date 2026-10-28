-- Horizontal Sharding & Declarative Range Partitioning
-- MIT 8103 Advanced Database Systems - Portfolio 5
-- Case Study: FinPay Technologies Ltd
-- Author: Folajimi

-- Clean teardown of partitioned and sharded tables if re-running
DROP TABLE IF EXISTS transactions_partitioned CASCADE;
DROP TABLE IF EXISTS accounts_sharded CASCADE;

\echo '1. Creating Monthly Range-Partitioned Ledger (transactions_partitioned)'

-- Note: PostgreSQL requires any PRIMARY KEY or UNIQUE constraint on a partitioned table
-- to include all partition key columns (created_at).
CREATE TABLE transactions_partitioned (
    transaction_id UUID NOT NULL DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(64) NOT NULL,
    account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    transaction_type VARCHAR(10) NOT NULL CHECK (transaction_type IN ('DEBIT', 'CREDIT')),
    category VARCHAR(30) NOT NULL,
    amount NUMERIC(18, 4) NOT NULL CHECK (amount > 0.0000),
    fee NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (fee >= 0.0000),
    balance_after NUMERIC(18, 4) NOT NULL CHECK (balance_after >= 0.0000),
    status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    narration VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_id, created_at),
    UNIQUE (transaction_reference, created_at)
) PARTITION BY RANGE (created_at);

-- Create monthly child partitions covering FinPay's 2026 operational windows
CREATE TABLE transactions_p2026_05 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-05-01 00:00:00+00') TO ('2026-06-01 00:00:00+00');

CREATE TABLE transactions_p2026_06 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-06-01 00:00:00+00') TO ('2026-07-01 00:00:00+00');

CREATE TABLE transactions_p2026_07 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-07-01 00:00:00+00') TO ('2026-08-01 00:00:00+00');

CREATE TABLE transactions_p2026_08 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-08-01 00:00:00+00') TO ('2026-09-01 00:00:00+00');

CREATE TABLE transactions_p2026_09 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-09-01 00:00:00+00') TO ('2026-10-01 00:00:00+00');

CREATE TABLE transactions_p2026_10 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

CREATE TABLE transactions_p2026_11 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');

CREATE TABLE transactions_p_default PARTITION OF transactions_partitioned DEFAULT;

-- Create partitioned B-Tree index propagated automatically to all child partitions
CREATE INDEX idx_txns_part_account_created
    ON transactions_partitioned(account_id, created_at DESC);

CREATE INDEX idx_txns_part_type_status_created
    ON transactions_partitioned(transaction_type, status, created_at)
    INCLUDE (amount);

-- Migrate all 15,008 records from the monolithic transactions table into the partitioned hierarchy,
-- distributing synthetic history across the 6-month window (May 2026 - Oct 2026) while preserving
-- baseline October 2026 records verbatim.
INSERT INTO transactions_partitioned (
    transaction_id, transaction_reference, account_id, transaction_type,
    category, amount, fee, balance_after, status, narration, created_at
)
SELECT
    transaction_id,
    transaction_reference,
    account_id,
    transaction_type,
    category,
    amount,
    fee,
    balance_after,
    status,
    narration,
    CASE
        WHEN transaction_reference LIKE 'FP-TXN-%' THEN
            TIMESTAMP WITH TIME ZONE '2026-05-01 00:00:00+00'
            + ((abs(hashtext(transaction_reference)) % 180) * INTERVAL '1 day')
            + ((abs(hashtext(transaction_id::text)) % 86400) * INTERVAL '1 second')
        ELSE created_at
    END
FROM transactions;

ANALYZE transactions_partitioned;

\echo '2. Inspecting Tuple Distribution Across Monthly Partitions'

SELECT
    inhrelid::regclass AS partition_name,
    pg_get_expr(c.relpartbound, c.oid) AS partition_range_bound,
    c.reltuples::bigint AS tuple_count,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size
FROM pg_inherits i
JOIN pg_class c ON i.inhrelid = c.oid
WHERE i.inhparent = 'transactions_partitioned'::regclass
ORDER BY c.relname;

\echo '3. Creating 4-Way Hash-Sharded Account Table (accounts_sharded)'

CREATE TABLE accounts_sharded (
    account_id UUID NOT NULL,
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    account_number CHAR(10) NOT NULL,
    account_type VARCHAR(20) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'NGN',
    available_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (available_balance >= 0.0000),
    ledger_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (ledger_balance >= 0.0000),
    account_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    shard_region VARCHAR(30) NOT NULL DEFAULT 'NG-LAGOS-PRIMARY',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_number, account_id)
) PARTITION BY HASH (account_number);

-- Create 4 logical hash shards (Modulus 4, Remainder 0..3) representing distributed shard nodes
CREATE TABLE accounts_shard_00 PARTITION OF accounts_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);

CREATE TABLE accounts_shard_01 PARTITION OF accounts_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);

CREATE TABLE accounts_shard_02 PARTITION OF accounts_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);

CREATE TABLE accounts_shard_03 PARTITION OF accounts_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Populate sharded accounts from baseline accounts table
INSERT INTO accounts_sharded (
    account_id, customer_id, account_number, account_type,
    currency, available_balance, ledger_balance, account_status,
    shard_region, created_at, updated_at
)
SELECT
    account_id,
    customer_id,
    account_number,
    account_type,
    currency,
    available_balance,
    ledger_balance,
    account_status,
    CASE (abs(hashtext(account_number)) % 4)
        WHEN 0 THEN 'SHARD-00 (Lagos-VI-Node1)'
        WHEN 1 THEN 'SHARD-01 (Lagos-Ikeja-Node2)'
        WHEN 2 THEN 'SHARD-02 (Abuja-Central-Node3)'
        ELSE 'SHARD-03 (PortHarcourt-Node4)'
    END,
    created_at,
    updated_at
FROM accounts;

ANALYZE accounts_sharded;

\echo '4. Verifying Uniform Hash Sharding Balance Across 4 Nodes'

SELECT
    tableoid::regclass AS shard_partition,
    count(*) AS accounts_hosted,
    round((count(*)::numeric / sum(count(*)) OVER ()) * 100, 2) AS distribution_pct,
    round(sum(available_balance), 2) AS total_liquidity_ngn
FROM accounts_sharded
GROUP BY tableoid
ORDER BY tableoid::regclass::text;

\echo '5. Benchmarking Partition Pruning on October 2026 NIP Settlement Audit'

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    category,
    status,
    count(*) AS txn_count,
    sum(amount) AS total_volume_ngn
FROM transactions_partitioned
WHERE created_at >= '2026-10-01 00:00:00+00'
  AND created_at <  '2026-11-01 00:00:00+00'
  AND transaction_type = 'DEBIT'
GROUP BY category, status
ORDER BY total_volume_ngn DESC;

\echo '6. Verifying Single-Shard Targeting on NUBAN Lookup (John Adeyemi: 0123456789)'

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    account_number,
    account_type,
    available_balance,
    account_status,
    tableoid::regclass AS routed_shard
FROM accounts_sharded
WHERE account_number = '0123456789';

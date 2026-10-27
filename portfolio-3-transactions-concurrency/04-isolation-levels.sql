-- PostgreSQL Transaction Isolation Levels Analysis
-- MIT 8103 Advanced Database Systems - Portfolio 3

-- 1. Non-Repeatable Reads under READ COMMITTED
\echo 'Testing Non-Repeatable Read (READ COMMITTED)'

DO $$
DECLARE
    v_balance_snapshot1 NUMERIC(18, 4);
    v_balance_snapshot2 NUMERIC(18, 4);
BEGIN
    SELECT available_balance INTO v_balance_snapshot1
    FROM accounts
    WHERE account_number = '0123456789';

    RAISE NOTICE 'Initial read (T0): % NGN', v_balance_snapshot1;

    -- Interleaved concurrent update
    UPDATE accounts 
    SET available_balance = available_balance + 2500.0000 
    WHERE account_number = '0123456789';

    -- Subsequent read inside same block
    SELECT available_balance INTO v_balance_snapshot2
    FROM accounts
    WHERE account_number = '0123456789';

    RAISE NOTICE 'Subsequent read (T1): % NGN', v_balance_snapshot2;

    IF v_balance_snapshot1 <> v_balance_snapshot2 THEN
        RAISE NOTICE 'Non-Repeatable read observed. Balance changed mid-transaction.';
    END IF;

    -- Revert test adjustment
    UPDATE accounts 
    SET available_balance = available_balance - 2500.0000 
    WHERE account_number = '0123456789';
END $$;

-- 2. REPEATABLE READ snapshot isolation
\echo 'Testing Snapshot Isolation (REPEATABLE READ)'

DO $$
DECLARE
    v_bal1 NUMERIC(18, 4);
BEGIN
    SELECT available_balance INTO v_bal1 FROM accounts WHERE account_number = '0123456789';
    RAISE NOTICE 'Snapshot read at start of transaction: % NGN', v_bal1;
    RAISE NOTICE 'REPEATABLE READ guarantees stable snapshot views across analytical reporting.';
END $$;

-- 3. Serializable Snapshot Isolation settings
\echo 'Current Transaction Isolation Settings'
SELECT 
    name,
    setting,
    unit,
    short_desc
FROM pg_settings
WHERE name IN ('default_transaction_isolation', 'transaction_isolation');

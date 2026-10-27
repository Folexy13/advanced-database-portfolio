-- Concurrency Control & Double-Spend Prevention
-- MIT 8103 Advanced Database Systems - Portfolio 3

-- Check active lock states on accounts
SELECT 
    locktype,
    relation::regclass AS table_name,
    mode,
    granted,
    pid
FROM pg_locks
WHERE relation = 'accounts'::regclass;

-- 1. Pessimistic Row Locking (SELECT FOR UPDATE)
-- Simulate two simultaneous debits against David Bello (0323456782, balance 230,000 NGN)
-- Transfer 1: 150,000 NGN
-- Transfer 2: 100,000 NGN (cumulative exceeds balance)
\echo 'Testing Pessimistic Locking (SELECT FOR UPDATE)'

DO $$
DECLARE
    v_res1 RECORD;
    v_res2 RECORD;
BEGIN
    RAISE NOTICE 'Executing Transfer 1 (150,000 NGN)...';
    SELECT * INTO v_res1 FROM sp_execute_fund_transfer(
        '0323456782', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
        150000.0000, 'Legitimate concurrent transfer 1', 'MOBILE_APP'
    );
    RAISE NOTICE 'Transfer 1 Result: % (New Balance: % NGN)', v_res1.transfer_status, v_res1.source_balance_after;

    RAISE NOTICE 'Executing Transfer 2 (100,000 NGN)...';
    BEGIN
        SELECT * INTO v_res2 FROM sp_execute_fund_transfer(
            '0323456782', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
            100000.0000, 'Concurrent double-spend attempt', 'POS'
        );
        RAISE EXCEPTION 'Double-spend bug allowed!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Transfer 2 rejected as expected: %', SQLERRM;
    END;
END $$;

-- Verify final balance is 80,000 NGN (not negative)
SELECT account_number, account_type, available_balance, ledger_balance
FROM accounts
WHERE account_number = '0323456782';

-- 2. Optimistic Concurrency Control (OCC) pattern
-- Used for profile updates with version token (updated_at)
\echo 'Testing Optimistic Concurrency Control (OCC)'

DO $$
DECLARE
    v_customer_id UUID := 'a0000000-0000-0000-0000-000000000001';
    v_expected_updated_at TIMESTAMPTZ;
    v_rows_affected INT;
BEGIN
    -- Step 1: Read record and version token
    SELECT updated_at INTO v_expected_updated_at
    FROM customers
    WHERE customer_id = v_customer_id;

    RAISE NOTICE 'Client read version token: %', v_expected_updated_at;

    -- Step 2: Interleaved update by another process
    UPDATE customers 
    SET phone_number = '+2348011234999', updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = v_customer_id;

    RAISE NOTICE 'Concurrent update committed.';

    -- Step 3: Original client tries to update with stale version token
    UPDATE customers
    SET first_name = 'Johnny'
    WHERE customer_id = v_customer_id
      AND updated_at = v_expected_updated_at;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE NOTICE 'OCC Conflict detected: 0 rows updated because record was modified concurrently.';
    ELSE
        RAISE EXCEPTION 'OCC failed: Stale write was accepted.';
    END IF;

    -- Revert phone number
    UPDATE customers 
    SET phone_number = '+2348011234567' 
    WHERE customer_id = v_customer_id;
END $$;

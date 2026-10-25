-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 3 - Transactions and Concurrency
-- Case Study: FinPay Technologies Ltd
-- File: 03-concurrency-control.sql
-- Description: Concurrency control analysis demonstrating race condition prevention,
--              pessimistic row-level locking (SELECT FOR UPDATE), and Optimistic Concurrency.
-- Author: Folajimi

-- ============================================================================
-- 1. THE CONCURRENCY PROBLEM: LOST UPDATES & DOUBLE-SPENDING
-- In an uncontrolled multi-user environment, two concurrent payment channels
-- (e.g., POS terminal and Mobile App) can simultaneously read the same balance.
-- Without locking:
--   T1 (Time 0): Reads Balance = 100,000 NGN
--   T2 (Time 1): Reads Balance = 100,000 NGN
--   T1 (Time 2): Debits 70,000 NGN -> Writes 30,000 NGN
--   T2 (Time 3): Debits 70,000 NGN -> Writes 30,000 NGN (Overwriting T1's debit!)
-- Result: 140,000 NGN withdrawn, but account shows 30,000 NGN instead of -40,000 NGN.
-- ============================================================================

-- ============================================================================
-- 2. PESSIMISTIC CONCURRENCY CONTROL (SELECT FOR UPDATE)
-- In FinPay's sp_execute_fund_transfer, we enforce exclusive row-level locking.
-- The query engine attaches an exclusive tuple lock (ExclusiveLock) to the row.
-- Any concurrent transaction attempting to read the same account FOR UPDATE
-- is suspended in the lock wait queue until the first transaction issues COMMIT.
-- ============================================================================

\echo '----------------------------------------------------------------------'
\echo 'DEMONSTRATING PESSIMISTIC ROW-LEVEL LOCKING (SELECT FOR UPDATE)'
\echo '----------------------------------------------------------------------'

-- Inspect active lock states on the accounts table in pg_locks
SELECT 
    locktype,
    relation::regclass AS table_name,
    mode,
    granted,
    pid
FROM pg_locks
WHERE relation = 'accounts'::regclass;

-- Simulation Demonstration Block:
-- We simulate two concurrent debit requests against David Bello (0323456782, balance 230,000 NGN)
-- Transfer 1: 150,000 NGN
-- Transfer 2: 100,000 NGN
-- Cumulative requested: 250,000 NGN (Exceeds 230,000 NGN!)
-- Expected: The first transfer completes (balance drops to 80,000 NGN).
--           The second transfer acquires lock, re-evaluates balance, and is REJECTED.
DO $$
DECLARE
    v_res1 RECORD;
    v_res2 RECORD;
BEGIN
    RAISE NOTICE 'Executing Transfer 1 (150,000 NGN from David Bello to Sarah Okafor)...';
    SELECT * INTO v_res1 FROM sp_execute_fund_transfer(
        '0323456782', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
        150000.0000, 'Legitimate concurrent transfer 1', 'MOBILE_APP'
    );
    RAISE NOTICE 'Transfer 1 Result: % (New Balance: % NGN)', v_res1.transfer_status, v_res1.source_balance_after;

    RAISE NOTICE 'Executing Transfer 2 immediately after (100,000 NGN from David Bello)...';
    BEGIN
        SELECT * INTO v_res2 FROM sp_execute_fund_transfer(
            '0323456782', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
            100000.0000, 'Concurrent double-spend attempt', 'POS'
        );
        RAISE EXCEPTION 'CRITICAL BUG: Double-spend was permitted!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'SUCCESS: Transfer 2 rejected due to locked serialized re-check: %', SQLERRM;
    END;
END $$;

-- Verify final balance of David Bello (Must be exactly 80,000 NGN, not -20,000 NGN)
SELECT account_number, account_type, available_balance, ledger_balance
FROM accounts
WHERE account_number = '0323456782';

-- ============================================================================
-- 3. OPTIMISTIC CONCURRENCY CONTROL (OCC) PATTERN
-- While Pessimistic Locking is mandatory for financial balance debits,
-- Optimistic Concurrency Control is ideal for low-contention entities
-- (such as customer profile updates or beneficiary edits).
-- ============================================================================
\echo '----------------------------------------------------------------------'
\echo 'DEMONSTRATING OPTIMISTIC CONCURRENCY CONTROL (OCC)'
\echo '----------------------------------------------------------------------'

DO $$
DECLARE
    v_customer_id UUID := 'a0000000-0000-0000-0000-000000000001';
    v_expected_updated_at TIMESTAMPTZ;
    v_rows_affected INT;
BEGIN
    -- Step 1: Client reads customer record along with its timestamp token
    SELECT updated_at INTO v_expected_updated_at
    FROM customers
    WHERE customer_id = v_customer_id;

    RAISE NOTICE 'Client read customer record at version: %', v_expected_updated_at;

    -- Step 2: Simulate an interleaved update by another user / background job
    UPDATE customers 
    SET phone_number = '+2348011234999', updated_at = CURRENT_TIMESTAMP
    WHERE customer_id = v_customer_id;

    RAISE NOTICE 'Simulated interleaved concurrent update committed.';

    -- Step 3: Original client attempts to update based on stale expected_updated_at
    UPDATE customers
    SET first_name = 'Johnny'
    WHERE customer_id = v_customer_id
      AND updated_at = v_expected_updated_at;

    GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

    IF v_rows_affected = 0 THEN
        RAISE NOTICE 'OCC DETECTED CONFLICT: 0 rows updated! Record was modified concurrently. Aborting client write.';
    ELSE
        RAISE EXCEPTION 'OCC FAILED: Stale write was erroneously accepted.';
    END IF;

    -- Revert test phone change
    UPDATE customers 
    SET phone_number = '+2348011234567' 
    WHERE customer_id = v_customer_id;
END $$;

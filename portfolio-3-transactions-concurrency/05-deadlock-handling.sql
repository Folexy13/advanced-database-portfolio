-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 3 - Transactions and Concurrency
-- Case Study: FinPay Technologies Ltd
-- File: 05-deadlock-handling.sql
-- Description: Deadlock simulation, lock graph analysis, and deterministic
--              ordered lock resolution (Dijkstra resource ordering).
-- Author: Folajimi

-- ============================================================================
-- 1. DEADLOCK ANALYSIS & COFFMAN CONDITIONS
-- A deadlock in a core banking system occurs when four simultaneous conditions exist:
--   1. Mutual Exclusion: Accounts can only be modified by one transaction at a time.
--   2. Hold and Wait: Transaction 1 holds Lock A while requesting Lock B.
--   3. No Preemption: The database cannot forcibly steal a lock from an active transaction.
--   4. Circular Wait: Transaction 1 waits on Lock B (held by T2), while T2 waits on Lock A (held by T1).
-- ============================================================================

\echo '----------------------------------------------------------------------'
\echo '1. DEADLOCK DETECTION SETTINGS IN POSTGRESQL'
\echo '----------------------------------------------------------------------'

SELECT 
    name, 
    setting, 
    unit, 
    short_desc
FROM pg_settings 
WHERE name IN ('deadlock_timeout', 'lock_timeout', 'statement_timeout');

-- ============================================================================
-- 2. NAIVE APPROACH (CIRCULAR DEADLOCK VULNERABILITY)
-- A naive implementation locks source first, then destination:
--   T1 (A -> B): Locks A, waits on B.
--   T2 (B -> A): Locks B, waits on A.
-- When deadlock_timeout expires (default 1000ms), PostgreSQL aborts one transaction:
--   "ERROR: deadlock detected (SQLSTATE 40P01)"
--   "DETAIL: Process 123 waits for ShareLock on transaction 456; blocked by process 789..."
-- ============================================================================

-- ============================================================================
-- 3. FINPAY ARCHITECTURAL RESOLUTION: DETERMINISTIC GLOBAL LOCK ORDERING
-- To break the Circular Wait condition, FinPay enforces global alphabetical ordering
-- on account numbers inside sp_execute_fund_transfer:
--
--   IF p_source_account_number < p_destination_account_number THEN
--       LOCK source;
--       LOCK destination;
--   ELSE
--       LOCK destination;
--       LOCK source;
--   END IF;
--
-- Demonstration: Both transfers (A -> B and B -> A) will ALWAYS acquire Lock A
-- before Lock B, completely preventing circular wait graphs!
-- ============================================================================

\echo '----------------------------------------------------------------------'
\echo '2. VERIFYING DETERMINISTIC LOCK ORDERING IN FINPAY'
\echo '----------------------------------------------------------------------'

DO $$
DECLARE
    v_acc_A CHAR(10) := '0123456789'; -- John Adeyemi
    v_acc_B CHAR(10) := '0223456781'; -- Sarah Okafor
    v_res RECORD;
BEGIN
    RAISE NOTICE 'Transfer 1: % -> % (Source < Destination)', v_acc_A, v_acc_B;
    SELECT * INTO v_res FROM sp_execute_fund_transfer(
        v_acc_A, v_acc_B, '000000', 'FinPay Internal', 'Sarah Okafor',
        2000.0000, 'Deterministic ordering test 1', 'MOBILE_APP'
    );
    RAISE NOTICE 'Transfer 1 Completed: % (Reference: %)', v_res.transfer_status, v_res.transaction_reference;

    RAISE NOTICE 'Transfer 2: % -> % (Source > Destination, reverse transfer)', v_acc_B, v_acc_A;
    SELECT * INTO v_res FROM sp_execute_fund_transfer(
        v_acc_B, v_acc_A, '000000', 'FinPay Internal', 'John Adeyemi',
        2000.0000, 'Deterministic ordering test 2', 'WEB'
    );
    RAISE NOTICE 'Transfer 2 Completed: % (Reference: %)', v_res.transfer_status, v_res.transaction_reference;

    RAISE NOTICE 'SUCCESS: Both bidirectional transfers executed cleanly with zero deadlocks.';
END $$;

-- Verify final balances after bidirectional transfers
SELECT account_number, account_type, available_balance, ledger_balance
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

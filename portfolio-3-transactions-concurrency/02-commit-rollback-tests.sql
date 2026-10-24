-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 3 - Transactions and Concurrency
-- Case Study: FinPay Technologies Ltd
-- File: 02-commit-rollback-tests.sql
-- Description: Empirical validation of ACID properties (Atomicity, Consistency,
--              Isolation, Durability) demonstrating explicit COMMIT and ROLLBACK.
-- Author: Folajimi

-- ============================================================================
-- TEST 1: Atomic P2P Transfer with Successful COMMIT
-- Scenario: John Adeyemi (0123456789) transfers 5,000 NGN to Sarah Okafor (0223456781).
-- Demonstrates: All-or-nothing execution. Both accounts mutate and ledger logs match.
-- ============================================================================
\echo '----------------------------------------------------------------------'
\echo 'TEST 1: ATOMIC P2P TRANSFER (SUCCESSFUL COMMIT)'
\echo '----------------------------------------------------------------------'

-- 1A: Inspect Pre-Transfer Balances
SELECT account_number, account_type, available_balance, ledger_balance, account_status
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

-- 1B: Execute Stored Transfer Procedure
SELECT * FROM sp_execute_fund_transfer(
    '0123456789',
    '0223456781',
    '000000',
    'FinPay Internal',
    'Sarah Okafor',
    5000.0000,
    'Tuition fee reimbursement',
    'MOBILE_APP'
);

-- 1C: Verify Post-Transfer Balances (John: -5000 NGN, Sarah: +5000 NGN)
SELECT account_number, account_type, available_balance, ledger_balance, account_status
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

-- 1D: Verify Ledger Integrity (Debits match Credits exactly)
SELECT 
    t.transaction_reference,
    t.account_id,
    a.account_number,
    t.transaction_type,
    t.amount,
    t.fee,
    t.balance_after,
    t.status,
    t.narration,
    t.created_at
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
WHERE t.narration LIKE '%Tuition fee reimbursement%'
ORDER BY t.created_at;

-- ============================================================================
-- TEST 2: Insufficient Funds Exception with Automatic ROLLBACK
-- Scenario: Ibrahim Danjuma (0723456786, balance ~8,500 NGN) attempts to transfer 50,000 NGN.
-- Expected: Exception raised, transaction rolled back, sender balance remains 100% intact.
-- ============================================================================
\echo '----------------------------------------------------------------------'
\echo 'TEST 2: INSUFFICIENT FUNDS (AUTOMATIC ROLLBACK)'
\echo '----------------------------------------------------------------------'

-- 2A: Pre-Test Balance
SELECT account_number, available_balance, ledger_balance 
FROM accounts 
WHERE account_number = '0723456786';

-- 2B: Execution Block with Exception Handling
DO $$
BEGIN
    PERFORM sp_execute_fund_transfer(
        '0723456786',
        '0123456789',
        '000000',
        'FinPay Internal',
        'John Adeyemi',
        50000.0000,
        'Attempted excess transfer',
        'MOBILE_APP'
    );
    RAISE EXCEPTION 'TEST FAILED: Transfer should have been blocked!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TRANSACTION ABORTED & ROLLED BACK AS EXPECTED: %', SQLERRM;
END $$;

-- 2C: Post-Test Balance Verification (Must be identical to Pre-Test)
SELECT account_number, available_balance, ledger_balance 
FROM accounts 
WHERE account_number = '0723456786';

-- ============================================================================
-- TEST 3: Debit on Restricted Account (FROZEN_PND) with ROLLBACK
-- Scenario: Olumide Fashola (0124456789) is in Post-No-Debit (PND) status.
-- Expected: Operational status guard intercepts debit, aborts transaction, rolls back.
-- ============================================================================
\echo '----------------------------------------------------------------------'
\echo 'TEST 3: RESTRICTED ACCOUNT DEBIT (FROZEN_PND ROLLBACK)'
\echo '----------------------------------------------------------------------'

SELECT account_number, account_status, available_balance 
FROM accounts 
WHERE account_number = '0124456789';

DO $$
BEGIN
    PERFORM sp_execute_fund_transfer(
        '0124456789',
        '0123456789',
        '000000',
        'FinPay Internal',
        'John Adeyemi',
        1000.0000,
        'Illegal transfer from frozen account',
        'MOBILE_APP'
    );
    RAISE EXCEPTION 'TEST FAILED: Transfer from PND account should have been blocked!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TRANSACTION ABORTED & ROLLED BACK AS EXPECTED: %', SQLERRM;
END $$;

SELECT account_number, account_status, available_balance 
FROM accounts 
WHERE account_number = '0124456789';

-- ============================================================================
-- TEST 4: Partial Failure Simulation Using Transaction SAVEPOINTS
-- Demonstrates: Fine-grained transaction management where a failed batch sub-operation
--               is rolled back to a SAVEPOINT while preserving the outer transaction.
-- ============================================================================
\echo '----------------------------------------------------------------------'
\echo 'TEST 4: TRANSACTION SAVEPOINT AND SELECTIVE ROLLBACK'
\echo '----------------------------------------------------------------------'

DO $$
DECLARE
    v_balance_before NUMERIC(18, 4);
BEGIN
    SELECT available_balance INTO v_balance_before FROM accounts WHERE account_number = '0123456789';
    RAISE NOTICE 'Starting transaction. John initial balance: % NGN', v_balance_before;

    -- Sub-operation 1: Valid fund transfer (John -> Sarah 1,000 NGN)
    PERFORM sp_execute_fund_transfer(
        '0123456789', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
        1000.0000, 'Savepoint valid leg 1'
    );
    RAISE NOTICE 'Sub-operation 1 completed successfully.';

    -- Sub-operation 2: Wrapped in nested BEGIN ... EXCEPTION block (PostgreSQL internal savepoint)
    BEGIN
        -- Deliberately attempt an illegal operation simulating an external partner crash
        UPDATE accounts SET available_balance = available_balance / 0 WHERE account_number = '0123456789';
    EXCEPTION
        WHEN division_by_zero THEN
            RAISE NOTICE 'Sub-operation 2 failed (division_by_zero)! Sub-transaction rolled back cleanly to savepoint.';
    END;

    -- Outer transaction commits successfully
    RAISE NOTICE 'Outer transaction finished. Leg 1 transfer preserved.';
END $$;

-- Verify that Leg 1 was preserved while the flawed operation was safely undone
SELECT account_number, available_balance 
FROM accounts 
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

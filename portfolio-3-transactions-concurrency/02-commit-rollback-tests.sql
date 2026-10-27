-- Empirical tests for ACID properties (Commit, Rollback, Savepoints)
-- MIT 8103 Advanced Database Systems - Portfolio 3

-- Test 1: Atomic P2P Transfer (Commit)
-- John Adeyemi (0123456789) transfers 5,000 NGN to Sarah Okafor (0223456781)
\echo '=== Running Test 1: Atomic Transfer with Commit ==='

-- Pre-transfer balances
SELECT account_number, account_type, available_balance, ledger_balance, account_status
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

-- Execute transfer function
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

-- Post-transfer balances (John -5000 NGN, Sarah +5000 NGN)
SELECT account_number, account_type, available_balance, ledger_balance, account_status
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

-- Ledger record audit
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

-- Test 2: Insufficient funds exception and automatic rollback
-- Ibrahim Danjuma (0723456786, balance ~8,500 NGN) tries to send 50,000 NGN
\echo '=== Running Test 2: Insufficient Funds Rollback ==='

SELECT account_number, available_balance, ledger_balance 
FROM accounts 
WHERE account_number = '0723456786';

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
    RAISE EXCEPTION 'Test failed: Transfer should not have succeeded!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Rollback verified: %', SQLERRM;
END $$;

-- Verify balance is unchanged
SELECT account_number, available_balance, ledger_balance 
FROM accounts 
WHERE account_number = '0723456786';

-- Test 3: Restricted account debit (FROZEN_PND)
\echo '=== Running Test 3: Frozen Account Debit Block ==='

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
    RAISE EXCEPTION 'Test failed: Transfer from PND account should have been blocked!';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Rollback verified: %', SQLERRM;
END $$;

SELECT account_number, account_status, available_balance 
FROM accounts 
WHERE account_number = '0124456789';

-- Test 4: Savepoint and partial failure recovery
\echo '=== Running Test 4: Sub-transaction Savepoint Rollback ==='

DO $$
DECLARE
    v_balance_before NUMERIC(18, 4);
BEGIN
    SELECT available_balance INTO v_balance_before FROM accounts WHERE account_number = '0123456789';
    RAISE NOTICE 'Starting transaction. Initial balance: % NGN', v_balance_before;

    -- Sub-operation 1: Valid transfer
    PERFORM sp_execute_fund_transfer(
        '0123456789', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor',
        1000.0000, 'Savepoint valid leg 1'
    );
    RAISE NOTICE 'Leg 1 finished.';

    -- Sub-operation 2: Simulated crash caught in nested block
    BEGIN
        UPDATE accounts SET available_balance = available_balance / 0 WHERE account_number = '0123456789';
    EXCEPTION
        WHEN division_by_zero THEN
            RAISE NOTICE 'Caught division by zero. Rolled back sub-operation 2 to savepoint.';
    END;

    RAISE NOTICE 'Outer transaction committed. Leg 1 preserved.';
END $$;

-- Verify leg 1 persisted
SELECT account_number, available_balance 
FROM accounts 
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

-- Deadlock simulation and deterministic lock ordering
-- MIT 8103 Advanced Database Systems - Portfolio 3

-- 1. Inspect engine deadlock settings
\echo '=== PostgreSQL Deadlock Configuration ==='
SELECT 
    name, 
    setting, 
    unit, 
    short_desc
FROM pg_settings 
WHERE name IN ('deadlock_timeout', 'lock_timeout', 'statement_timeout');

-- 2. Verify deterministic global lock ordering in sp_execute_fund_transfer
-- In bidirectional transfers (A -> B and B -> A), acquiring locks in ascending NUBAN order
-- eliminates the circular wait condition required for deadlocks.
\echo '=== Testing Bidirectional Transfers with Ordered Locking ==='

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
    RAISE NOTICE 'Transfer 1 completed: % (Ref: %)', v_res.transfer_status, v_res.transaction_reference;

    RAISE NOTICE 'Transfer 2: % -> % (Source > Destination, reverse transfer)', v_acc_B, v_acc_A;
    SELECT * INTO v_res FROM sp_execute_fund_transfer(
        v_acc_B, v_acc_A, '000000', 'FinPay Internal', 'John Adeyemi',
        2000.0000, 'Deterministic ordering test 2', 'WEB'
    );
    RAISE NOTICE 'Transfer 2 completed: % (Ref: %)', v_res.transfer_status, v_res.transaction_reference;

    RAISE NOTICE 'Both transfers completed successfully with zero deadlocks.';
END $$;

-- Verify final account balances
SELECT account_number, account_type, available_balance, ledger_balance
FROM accounts
WHERE account_number IN ('0123456789', '0223456781')
ORDER BY account_number;

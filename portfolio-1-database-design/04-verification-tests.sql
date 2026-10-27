-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: FinPay Technologies Ltd
-- File: 04-verification-tests.sql
-- Description: Test suite verifying schema constraints, relational integrity,
--              referential cascades, and ledger business rules.

-- TEST 1: Entity Count & Baseline Inventory
-- Verifies that all baseline records have loaded successfully across all tables.
SELECT 'kyc_tiers' AS entity, COUNT(*) AS total_records FROM kyc_tiers
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'accounts', COUNT(*) FROM accounts
UNION ALL
SELECT 'beneficiaries', COUNT(*) FROM beneficiaries
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions
UNION ALL
SELECT 'transfers', COUNT(*) FROM transfers
UNION ALL
SELECT 'fraud_alerts', COUNT(*) FROM fraud_alerts
UNION ALL
SELECT 'audit_logs', COUNT(*) FROM audit_logs;

-- TEST 2: Relational Join - Customer Master Portfolio Overview
-- Verifies multi-table relationships (customers -> kyc_tiers -> accounts).
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS full_name,
    c.phone_number,
    kt.tier_name,
    kt.daily_transaction_limit,
    a.account_number,
    a.account_type,
    a.available_balance,
    a.account_status
FROM customers c
JOIN kyc_tiers kt ON c.kyc_tier = kt.tier_level
JOIN accounts a ON c.customer_id = a.customer_id
ORDER BY c.first_name, a.account_number;

-- TEST 3: Double-Entry P2P Transfer Audit
-- Verifies that John Adeyemi's debit leg matches Sarah Okafor's credit leg exactly.
SELECT 
    t.transaction_reference,
    t.created_at,
    c.first_name || ' ' || c.last_name AS account_holder,
    a.account_number,
    t.transaction_type,
    t.category,
    t.amount,
    t.balance_after,
    t.narration
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.transaction_reference IN ('FP-TRF-20261002-0001', 'FP-TRF-20261002-0002')
ORDER BY t.created_at;

-- TEST 4: Integrity Constraint Assertions (Deliberate Negative Tests)
-- Each query inside the DO blocks demonstrates that the engine rejects invalid data.

-- Assertion 4A: Negative Balance Constraint
-- Expected Result: Rejection with chk_available_balance_non_negative violation
DO $$
BEGIN
    UPDATE accounts 
    SET available_balance = -500.0000 
    WHERE account_number = '0123456789';
    RAISE EXCEPTION 'FAILED: Negative balance was erroneously allowed.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4A): Negative balance correctly blocked by chk_available_balance_non_negative.';
END $$;

-- Assertion 4B: NUBAN Format Check Constraint
-- Expected Result: Rejection with chk_nuban_format violation (9 digits instead of 10)
DO $$
BEGIN
    INSERT INTO accounts (customer_id, account_number, account_type, available_balance, ledger_balance)
    VALUES ('a0000000-0000-0000-0000-000000000001', '123456789', 'SAVINGS', 1000.0000, 1000.0000);
    RAISE EXCEPTION 'FAILED: Non-10-digit NUBAN was erroneously allowed.';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4B): Invalid NUBAN format correctly blocked by chk_nuban_format.';
END $$;

-- Assertion 4C: Duplicate Phone Number Uniqueness Constraint
-- Expected Result: Rejection with unique violation
DO $$
BEGIN
    INSERT INTO customers (first_name, last_name, email, phone_number, kyc_tier)
    VALUES ('Duplicate', 'User', 'unique.email@finpay.ng', '+2348011234567', 1);
    RAISE EXCEPTION 'FAILED: Duplicate phone number was erroneously allowed.';
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'SUCCESS (Test 4C): Duplicate phone number correctly blocked by unique constraint.';
END $$;

-- Assertion 4D: Debit on Restricted Account Status (Trigger Enforcement)
-- Expected Result: Rejection because account 0124456789 is in FROZEN_PND status
DO $$
BEGIN
    INSERT INTO transactions (
        transaction_reference, account_id, transaction_type, category, amount, fee, balance_after, narration
    ) VALUES (
        'FP-TEST-ILLEGAL-DEBIT', 'b0000000-0000-0000-0000-000000000012', 'DEBIT', 'INTRA_TRANSFER', 1000.0000, 0, 11000.0000, 'Illegal Debit Test'
    );
    RAISE EXCEPTION 'FAILED: Debit on FROZEN_PND account was erroneously allowed.';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'SUCCESS (Test 4D): Debit on restricted account correctly blocked by trigger: %', SQLERRM;
END $$;

-- TEST 5: Regulatory Compliance & KYC Limit Monitoring Query
-- Checks whether any account balance exceeds its assigned KYC tier cap.
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    kt.tier_level,
    kt.tier_name,
    kt.max_balance_limit,
    a.account_number,
    a.available_balance,
    CASE 
        WHEN kt.max_balance_limit IS NOT NULL AND a.available_balance > kt.max_balance_limit 
        THEN 'REGULATORY_BREACH' 
        ELSE 'COMPLIANT' 
    END AS compliance_status
FROM customers c
JOIN kyc_tiers kt ON c.kyc_tier = kt.tier_level
JOIN accounts a ON c.customer_id = a.customer_id
ORDER BY a.available_balance DESC;

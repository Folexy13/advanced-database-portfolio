-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: FinPay Technologies Ltd (Core Banking & Payment Settlement System)
-- File: 01-schema.sql
-- Description: DDL Schema definition with relational tables, primary keys,
--              foreign keys, and data integrity constraints.
-- Target RDBMS: PostgreSQL 14+ (Compatible with ANSI SQL standards)

-- Ensure pgcrypto is available for UUID generation (PostgreSQL 13+ includes gen_random_uuid() natively)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Clean teardown of existing schema objects (in reverse dependency order)
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS fraud_alerts CASCADE;
DROP TABLE IF EXISTS transfers CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS beneficiaries CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS kyc_tiers CASCADE;

-- 1. ENTITY: kyc_tiers (Reference/Lookup Table)
-- Purpose: Defines regulatory KYC tier ceilings mandated by the Central Bank
--          of Nigeria (CBN) for mobile money & digital banking operations.
CREATE TABLE kyc_tiers (
    tier_level INT PRIMARY KEY,
    tier_name VARCHAR(50) NOT NULL UNIQUE,
    daily_transaction_limit NUMERIC(15, 2) NOT NULL CHECK (daily_transaction_limit > 0),
    single_transaction_limit NUMERIC(15, 2) NOT NULL CHECK (single_transaction_limit > 0),
    max_balance_limit NUMERIC(15, 2) CHECK (max_balance_limit IS NULL OR max_balance_limit > 0),
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_single_le_daily CHECK (single_transaction_limit <= daily_transaction_limit)
);

COMMENT ON TABLE kyc_tiers IS 'Reference table for CBN-mandated customer KYC tier classifications and transfer limits.';

-- 2. ENTITY: customers (Customer Master Data)
-- Purpose: Stores verified personal information, hashed national identifiers,
--          contact details, and current KYC standing.
CREATE TABLE customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(15) NOT NULL UNIQUE,
    bvn_hash CHAR(64) UNIQUE, -- SHA-256 hash of 11-digit Bank Verification Number
    nin_hash CHAR(64) UNIQUE, -- SHA-256 hash of 11-digit National Identity Number
    kyc_tier INT NOT NULL DEFAULT 1 REFERENCES kyc_tiers(tier_level) ON DELETE RESTRICT,
    account_status VARCHAR(25) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_customer_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT chk_customer_phone CHECK (phone_number ~ '^\+234[0-9]{10}$'),
    CONSTRAINT chk_customer_status CHECK (account_status IN ('ACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION', 'DEACTIVATED'))
);

COMMENT ON TABLE customers IS 'Master record of FinPay retail and merchant customers with hashed identity credentials.';

-- 3. ENTITY: accounts (Financial Accounts & Digital Wallets)
-- Purpose: Maintains 10-digit NUBAN accounts, balance ledgers, and operational
--          statuses with strict non-negative constraints.
CREATE TABLE accounts (
    account_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    account_number CHAR(10) NOT NULL UNIQUE, -- 10-digit NUBAN format
    account_type VARCHAR(20) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'NGN',
    available_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    ledger_balance NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    account_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_nuban_format CHECK (account_number ~ '^[0-9]{10}$'),
    CONSTRAINT chk_account_type CHECK (account_type IN ('SAVINGS', 'CURRENT', 'MERCHANT_WALLET', 'ESCROW')),
    CONSTRAINT chk_currency_iso CHECK (currency IN ('NGN', 'USD', 'GBP', 'EUR')),
    CONSTRAINT chk_available_balance_non_negative CHECK (available_balance >= 0.0000),
    CONSTRAINT chk_ledger_balance_non_negative CHECK (ledger_balance >= 0.0000),
    CONSTRAINT chk_account_status CHECK (account_status IN ('ACTIVE', 'DORMANT', 'FROZEN_PND', 'CLOSED'))
);

COMMENT ON TABLE accounts IS 'Core banking accounts and digital wallets with real-time available and ledger balances.';

-- 4. ENTITY: beneficiaries (Saved Payees Directory)
-- Purpose: Accelerates repetitive P2P and inter-bank transfers by caching
--          verified counterparty account numbers and destination routing codes.
CREATE TABLE beneficiaries (
    beneficiary_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    beneficiary_account_number CHAR(10) NOT NULL,
    bank_code VARCHAR(6) NOT NULL, -- Central Bank institution routing code (e.g., 000013 for GTBank)
    bank_name VARCHAR(100) NOT NULL,
    account_name VARCHAR(120) NOT NULL,
    nickname VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_beneficiary_nuban CHECK (beneficiary_account_number ~ '^[0-9]{10}$'),
    CONSTRAINT uq_customer_beneficiary UNIQUE (customer_id, beneficiary_account_number, bank_code)
);

COMMENT ON TABLE beneficiaries IS 'Frequent transfer recipient directory per customer.';

-- 5. ENTITY: transactions (Core Financial Ledger)
-- Purpose: Immutable double-entry transaction journal recording all fund
--          movements, fees, balance checkpoints, and classifications.
CREATE TABLE transactions (
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_reference VARCHAR(64) NOT NULL UNIQUE,
    account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    transaction_type VARCHAR(10) NOT NULL,
    category VARCHAR(30) NOT NULL,
    amount NUMERIC(18, 4) NOT NULL,
    fee NUMERIC(18, 4) NOT NULL DEFAULT 0.0000,
    balance_after NUMERIC(18, 4) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'SUCCESS',
    narration VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_transaction_type CHECK (transaction_type IN ('DEBIT', 'CREDIT')),
    CONSTRAINT chk_transaction_category CHECK (category IN (
        'INTRA_TRANSFER',
        'INTER_TRANSFER_NIP',
        'BILL_PAYMENT',
        'AIRTIME_DATA',
        'DEPOSIT',
        'REVERSAL',
        'MERCHANT_PAYMENT'
    )),
    CONSTRAINT chk_transaction_amount_positive CHECK (amount > 0.0000),
    CONSTRAINT chk_transaction_fee_non_negative CHECK (fee >= 0.0000),
    CONSTRAINT chk_balance_after_non_negative CHECK (balance_after >= 0.0000),
    CONSTRAINT chk_transaction_status CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED', 'REVERSED'))
);

COMMENT ON TABLE transactions IS 'Primary financial ledger recording all debits, credits, charges, and running balances.';

-- 6. ENTITY: transfers (NIP and P2P Settlement Specifics)
-- Purpose: Subtype table capturing inter-bank routing metadata, NIBSS session
--          identifiers, channels, and counterparty details.
CREATE TABLE transfers (
    transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(transaction_id) ON DELETE RESTRICT,
    source_account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    destination_bank_code VARCHAR(6) NOT NULL,
    destination_bank_name VARCHAR(100) NOT NULL,
    destination_account_number CHAR(10) NOT NULL,
    destination_account_name VARCHAR(120) NOT NULL,
    nip_session_id VARCHAR(35) UNIQUE, -- NIBSS Instant Payment 30-digit unique session ID
    channel VARCHAR(20) NOT NULL DEFAULT 'MOBILE_APP',
    transfer_status VARCHAR(20) NOT NULL DEFAULT 'COMPLETED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_dest_nuban CHECK (destination_account_number ~ '^[0-9]{10}$'),
    CONSTRAINT chk_transfer_channel CHECK (channel IN ('MOBILE_APP', 'WEB', 'POS', 'API', 'USSD')),
    CONSTRAINT chk_transfer_status CHECK (transfer_status IN ('INITIATED', 'PROCESSING', 'COMPLETED', 'FAILED', 'REVERSED'))
);

COMMENT ON TABLE transfers IS 'Detailed payment settlement records for internal P2P and external NIBSS Instant Payments.';

-- 7. ENTITY: fraud_alerts (Risk & AML Surveillance)
-- Purpose: Automatically flags anomalous activities (rapid balance drain,
--          unusual transaction velocities, limit threshold breaches).
CREATE TABLE fraud_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(transaction_id) ON DELETE SET NULL,
    rule_code VARCHAR(50) NOT NULL,
    risk_score INT NOT NULL,
    severity VARCHAR(15) NOT NULL,
    status VARCHAR(25) NOT NULL DEFAULT 'FLAGGED',
    review_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMPTZ,
    CONSTRAINT chk_risk_score_range CHECK (risk_score BETWEEN 0 AND 100),
    CONSTRAINT chk_fraud_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_fraud_status CHECK (status IN ('FLAGGED', 'UNDER_INVESTIGATION', 'RESOLVED_FALSE_POSITIVE', 'CONFIRMED_FRAUD')),
    CONSTRAINT chk_rule_code CHECK (rule_code IN (
        'RAPID_BALANCE_DRAIN',
        'DAILY_LIMIT_EXCEEDED',
        'UNUSUAL_GEO_LOCATION',
        'OFF_PEAK_VELOCITY',
        'MULTIPLE_FAILED_PINS'
    ))
);

COMMENT ON TABLE fraud_alerts IS 'Compliance and risk monitoring incident log for suspicious financial behavior.';

-- 8. ENTITY: audit_logs (Immutable Change-Data-Capture Trail)
-- Purpose: Enterprise forensics table tracking administrative and financial state
--          mutations with previous and updated JSON representations.
CREATE TABLE audit_logs (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    record_id VARCHAR(64) NOT NULL,
    action VARCHAR(10) NOT NULL,
    old_state JSONB,
    new_state JSONB,
    changed_by VARCHAR(100) NOT NULL DEFAULT 'SYSTEM_PROCESS',
    client_ip VARCHAR(45),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_audit_action CHECK (action IN ('INSERT', 'UPDATE', 'DELETE'))
);

COMMENT ON TABLE audit_logs IS 'Append-only audit trail capturing structural and financial state modifications.';

-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: FinPay Technologies Ltd
-- File: 02-constraints.sql
-- Description: Business rules, operational triggers, audit trail capture,
--              and foreign key relational indexes.
-- ============================================================================

-- ============================================================================
-- 1. FOREIGN KEY & ACCESS PATH INDEXES
-- Purpose: Accelerate join performance, enforce efficient referential integrity
--          checks, and prevent table scans during relational queries.
-- ============================================================================
CREATE INDEX idx_accounts_customer_id ON accounts(customer_id);
CREATE INDEX idx_beneficiaries_customer_id ON beneficiaries(customer_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_created_at ON transactions(created_at);
CREATE INDEX idx_transfers_source_account_id ON transfers(source_account_id);
CREATE INDEX idx_transfers_transaction_id ON transfers(transaction_id);
CREATE INDEX idx_fraud_alerts_account_id ON fraud_alerts(account_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(table_name, record_id);

-- ============================================================================
-- 2. TRIGGER FUNCTION: update_timestamp_column
-- Purpose: Automatically updates the 'updated_at' column whenever a row is modified.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_customers_updated_at
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_accounts_updated_at
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- 3. TRIGGER FUNCTION: audit_account_balance_changes
-- Purpose: Automatically records any balance or status mutation on financial
--          accounts into the immutable audit_logs table.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_audit_account_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.available_balance <> NEW.available_balance OR 
        OLD.ledger_balance <> NEW.ledger_balance OR 
        OLD.account_status <> NEW.account_status) THEN
        
        INSERT INTO audit_logs (
            table_name,
            record_id,
            action,
            old_state,
            new_state,
            changed_by,
            client_ip
        ) VALUES (
            'accounts',
            OLD.account_id::VARCHAR,
            'UPDATE',
            jsonb_build_object(
                'available_balance', OLD.available_balance,
                'ledger_balance', OLD.ledger_balance,
                'account_status', OLD.account_status,
                'updated_at', OLD.updated_at
            ),
            jsonb_build_object(
                'available_balance', NEW.available_balance,
                'ledger_balance', NEW.ledger_balance,
                'account_status', NEW.account_status,
                'updated_at', CURRENT_TIMESTAMP
            ),
            CURRENT_USER,
            inet_client_addr()::VARCHAR
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_account_mutations
AFTER UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION fn_audit_account_changes();

-- ============================================================================
-- 4. TRIGGER FUNCTION: enforce_account_operational_status
-- Purpose: Prevents debit transactions against accounts that are not in 'ACTIVE' status
--          (e.g., FROZEN_PND - Post-No-Debit, DORMANT, or CLOSED).
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_validate_account_status_for_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN
    SELECT account_status INTO v_status
    FROM accounts
    WHERE account_id = NEW.account_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Account % does not exist.', NEW.account_id;
    END IF;

    -- If the transaction is a DEBIT and account is restricted, reject immediately
    IF NEW.transaction_type = 'DEBIT' AND v_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Transaction rejected: Account % is currently in % status (Debits restricted).',
            NEW.account_id, v_status;
    END IF;

    -- If account is CLOSED, reject all transactions (debits and credits)
    IF v_status = 'CLOSED' THEN
        RAISE EXCEPTION 'Transaction rejected: Account % is CLOSED.', NEW.account_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_transaction_status
BEFORE INSERT ON transactions
FOR EACH ROW
EXECUTE FUNCTION fn_validate_account_status_for_transaction();

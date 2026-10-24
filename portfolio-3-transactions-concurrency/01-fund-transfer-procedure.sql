-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 3 - Transactions and Concurrency
-- Case Study: FinPay Technologies Ltd
-- File: 01-fund-transfer-procedure.sql
-- Description: ACID-compliant stored function implementing atomic fund transfers
--              with deterministic row locking, KYC limit checks, and audit logging.
-- Author: Folajimi

CREATE OR REPLACE FUNCTION sp_execute_fund_transfer(
    p_source_account_number CHAR(10),
    p_destination_account_number CHAR(10),
    p_destination_bank_code VARCHAR(6),
    p_destination_bank_name VARCHAR(100),
    p_destination_account_name VARCHAR(120),
    p_amount NUMERIC(18, 4),
    p_narration VARCHAR(255),
    p_channel VARCHAR(20) DEFAULT 'MOBILE_APP'
)
RETURNS TABLE (
    transfer_status VARCHAR(20),
    message TEXT,
    transaction_reference VARCHAR(64),
    source_balance_after NUMERIC(18, 4),
    fee_charged NUMERIC(18, 4)
) AS $$
DECLARE
    v_source_account_id UUID;
    v_source_customer_id UUID;
    v_source_balance NUMERIC(18, 4);
    v_source_status VARCHAR(20);
    
    v_dest_account_id UUID;
    v_dest_balance NUMERIC(18, 4);
    v_dest_status VARCHAR(20);
    
    v_fee NUMERIC(18, 4) := 0.0000;
    v_total_debit NUMERIC(18, 4);
    v_debit_balance_after NUMERIC(18, 4);
    v_credit_balance_after NUMERIC(18, 4);
    
    v_daily_limit NUMERIC(15, 2);
    v_today_debits NUMERIC(18, 4) := 0.0000;
    
    v_debit_txn_id UUID;
    v_credit_txn_id UUID;
    v_debit_ref VARCHAR(64);
    v_credit_ref VARCHAR(64);
    v_nip_session_id VARCHAR(35) := NULL;
    v_is_internal BOOLEAN;
BEGIN
    -- 1. Input Validation
    IF p_amount <= 0.0000 THEN
        RAISE EXCEPTION 'Transfer amount must be strictly greater than zero.';
    END IF;

    IF p_source_account_number = p_destination_account_number AND p_destination_bank_code = '000000' THEN
        RAISE EXCEPTION 'Self-transfers between identical accounts are not permitted.';
    END IF;

    v_is_internal := (p_destination_bank_code = '000000' OR p_destination_bank_code = 'FINPAY');
    
    -- Calculate transfer fee: Intra-bank is free (0.00 NGN); NIP inter-bank incurs 10.75 NGN
    IF NOT v_is_internal THEN
        v_fee := 10.7500;
    END IF;
    
    v_total_debit := p_amount + v_fee;

    -- 2. Deadlock Prevention Strategy: Deterministic Locking Order
    -- When locking multiple rows, always lock accounts in alphabetical NUBAN order.
    -- This guarantees concurrent transfers between Account A and Account B never deadlock.
    IF v_is_internal THEN
        IF p_source_account_number < p_destination_account_number THEN
            -- Lock source first, then destination
            SELECT account_id, customer_id, available_balance, account_status
            INTO v_source_account_id, v_source_customer_id, v_source_balance, v_source_status
            FROM accounts
            WHERE account_number = p_source_account_number
            FOR UPDATE;

            SELECT account_id, available_balance, account_status
            INTO v_dest_account_id, v_dest_balance, v_dest_status
            FROM accounts
            WHERE account_number = p_destination_account_number
            FOR UPDATE;
        ELSE
            -- Lock destination first, then source
            SELECT account_id, available_balance, account_status
            INTO v_dest_account_id, v_dest_balance, v_dest_status
            FROM accounts
            WHERE account_number = p_destination_account_number
            FOR UPDATE;

            SELECT account_id, customer_id, available_balance, account_status
            INTO v_source_account_id, v_source_customer_id, v_source_balance, v_source_status
            FROM accounts
            WHERE account_number = p_source_account_number
            FOR UPDATE;
        END IF;

        IF v_dest_account_id IS NULL THEN
            RAISE EXCEPTION 'Destination internal account % does not exist.', p_destination_account_number;
        END IF;

        IF v_dest_status = 'CLOSED' THEN
            RAISE EXCEPTION 'Destination account % is CLOSED and cannot accept credits.', p_destination_account_number;
        END IF;
    ELSE
        -- External NIP Transfer: Only lock the source account row
        SELECT account_id, customer_id, available_balance, account_status
        INTO v_source_account_id, v_source_customer_id, v_source_balance, v_source_status
        FROM accounts
        WHERE account_number = p_source_account_number
        FOR UPDATE;
    END IF;

    IF v_source_account_id IS NULL THEN
        RAISE EXCEPTION 'Source account % does not exist.', p_source_account_number;
    END IF;

    -- 3. Operational Account Status Verification
    IF v_source_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Transfer rejected: Source account % is in % status (Debits restricted).',
            p_source_account_number, v_source_status;
    END IF;

    -- 4. Sufficient Balance Check
    IF v_source_balance < v_total_debit THEN
        RAISE EXCEPTION 'Transfer rejected: Insufficient funds. Available: % NGN, Required: % NGN.',
            v_source_balance, v_total_debit;
    END IF;

    -- 5. CBN Tier Daily Limit Verification
    SELECT kt.daily_transaction_limit INTO v_daily_limit
    FROM customers c
    JOIN kyc_tiers kt ON c.kyc_tier = kt.tier_level
    WHERE c.customer_id = v_source_customer_id;

    SELECT COALESCE(SUM(t.amount), 0.0000) INTO v_today_debits
    FROM transactions t
    WHERE t.account_id = v_source_account_id
      AND t.transaction_type = 'DEBIT'
      AND t.status = 'SUCCESS'
      AND t.created_at >= date_trunc('day', CURRENT_TIMESTAMP);

    IF (v_today_debits + p_amount) > v_daily_limit THEN
        RAISE EXCEPTION 'Transfer rejected: CBN Daily KYC Limit exceeded. Limit: % NGN, Today Debits: % NGN, Requested: % NGN.',
            v_daily_limit, v_today_debits, p_amount;
    END IF;

    -- 6. Atomic Ledger State Mutation (Debit Leg)
    v_debit_balance_after := v_source_balance - v_total_debit;
    
    UPDATE accounts 
    SET available_balance = v_debit_balance_after,
        ledger_balance = ledger_balance - v_total_debit,
        updated_at = CURRENT_TIMESTAMP
    WHERE account_id = v_source_account_id;

    v_debit_ref := 'FP-TRF-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 5);
    v_debit_txn_id := gen_random_uuid();

    INSERT INTO transactions (
        transaction_id, transaction_reference, account_id, transaction_type, category,
        amount, fee, balance_after, status, narration, created_at
    ) VALUES (
        v_debit_txn_id,
        v_debit_ref,
        v_source_account_id,
        'DEBIT',
        CASE WHEN v_is_internal THEN 'INTRA_TRANSFER' ELSE 'INTER_TRANSFER_NIP' END,
        p_amount,
        v_fee,
        v_debit_balance_after,
        'SUCCESS',
        p_narration,
        CURRENT_TIMESTAMP
    );

    -- 7. Atomic Ledger State Mutation (Credit Leg for Intra-bank)
    IF v_is_internal THEN
        v_credit_balance_after := v_dest_balance + p_amount;

        UPDATE accounts 
        SET available_balance = v_credit_balance_after,
            ledger_balance = ledger_balance + p_amount,
            updated_at = CURRENT_TIMESTAMP
        WHERE account_id = v_dest_account_id;

        v_credit_ref := 'FP-CRD-' || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISSMS') || '-' || substr(md5(random()::text), 1, 5);
        v_credit_txn_id := gen_random_uuid();

        INSERT INTO transactions (
            transaction_id, transaction_reference, account_id, transaction_type, category,
            amount, fee, balance_after, status, narration, created_at
        ) VALUES (
            v_credit_txn_id,
            v_credit_ref,
            v_dest_account_id,
            'CREDIT',
            'INTRA_TRANSFER',
            p_amount,
            0.0000,
            v_credit_balance_after,
            'SUCCESS',
            'Transfer from ' || p_source_account_number || ': ' || p_narration,
            CURRENT_TIMESTAMP
        );
    ELSE
        -- Generate external NIBSS 30-digit session ID
        v_nip_session_id := '999' || p_destination_bank_code || to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS') || lpad((random() * 999999)::int::text, 6, '0');
    END IF;

    -- 8. Record Settlement Details in transfers Table
    INSERT INTO transfers (
        transfer_id, transaction_id, source_account_id, destination_bank_code, destination_bank_name,
        destination_account_number, destination_account_name, nip_session_id, channel, transfer_status, created_at
    ) VALUES (
        gen_random_uuid(),
        v_debit_txn_id,
        v_source_account_id,
        p_destination_bank_code,
        p_destination_bank_name,
        p_destination_account_number,
        p_destination_account_name,
        v_nip_session_id,
        p_channel,
        'COMPLETED',
        CURRENT_TIMESTAMP
    );

    -- 9. Return Successful Execution Tuple
    RETURN QUERY SELECT 
        'SUCCESS'::VARCHAR(20),
        'Transfer processed successfully.'::TEXT,
        v_debit_ref,
        v_debit_balance_after,
        v_fee;
END;
$$ LANGUAGE plpgsql;

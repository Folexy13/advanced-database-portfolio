-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: FinPay Technologies Ltd
-- File: 01-data-generator.sql
-- Description: Volumetric synthetic dataset generator (100+ customers, 150+ accounts,
--              15,000+ transactions, 6,000+ transfers, 300+ fraud alerts).
-- Author: Folajimi

DO $$
DECLARE
    v_cust_count INT;
    v_acc_count INT;
    v_txn_count INT;
BEGIN
    RAISE NOTICE 'Starting FinPay volumetric data generation for Portfolio 2...';

    -- 1. Scale Customers: Insert 90 additional customers (bringing total to 102)
    INSERT INTO customers (
        customer_id, first_name, last_name, email, phone_number, bvn_hash, nin_hash, kyc_tier, account_status, created_at
    )
    SELECT
        gen_random_uuid(),
        (ARRAY['Chukwudi', 'Olumide', 'Adebayo', 'Fatima', 'Zainab', 'Kelechi', 'Nnamdi', 'Folake', 'Damilola', 'Temitope', 'Tariq', 'Simisola', 'Onyinye', 'Mustapha', 'Yetunde', 'Kayode', 'Chioma', 'Abubakar'])[1 + ((i * 7 + 3) % 18)],
        (ARRAY['Okonkwo', 'Balogun', 'Danjuma', 'Adeleke', 'Babatunde', 'Eze', 'Okafor', 'Yusuf', 'Aliyu', 'Momodu', 'Suleiman', 'Nwachukwu', 'Ajayi', 'Ogundipe', 'Nwankwo', 'Garba', 'Bello', 'Adeyemi'])[1 + ((i * 11 + 5) % 18)],
        'customer.' || i || '.' || substr(md5(random()::text), 1, 8) || '@finpay.ng',
        '+234' || (8000000000 + i)::text,
        encode(digest('BVN-SALT-' || i::text || '-' || random()::text, 'sha256'), 'hex'),
        encode(digest('NIN-SALT-' || i::text || '-' || random()::text, 'sha256'), 'hex'),
        CASE 
            WHEN i % 5 = 0 THEN 3
            WHEN i % 2 = 0 THEN 2
            ELSE 1
        END,
        'ACTIVE',
        TIMESTAMP '2026-04-01 08:00:00+01' + (i * INTERVAL '18 hours')
    FROM generate_series(13, 102) AS i
    ON CONFLICT (phone_number) DO NOTHING;

    GET DIAGNOSTICS v_cust_count = ROW_COUNT;
    RAISE NOTICE 'Added % new customer records.', v_cust_count;

    -- 2. Scale Accounts: Ensure every customer has 1 to 2 accounts (Total ~160 accounts)
    INSERT INTO accounts (
        account_id, customer_id, account_number, account_type, currency, available_balance, ledger_balance, account_status, created_at
    )
    SELECT 
        gen_random_uuid(),
        c.customer_id,
        lpad((1000000000 + row_number() OVER (ORDER BY c.customer_id, s.n))::text, 10, '0'),
        CASE 
            WHEN s.n = 1 THEN 'SAVINGS'
            WHEN s.n = 2 AND c.kyc_tier = 3 THEN 'CURRENT'
            ELSE 'MERCHANT_WALLET'
        END,
        'NGN',
        round((5000 + (random() * 850000))::numeric, 4),
        round((5000 + (random() * 850000))::numeric, 4),
        'ACTIVE',
        c.created_at + INTERVAL '10 minutes'
    FROM customers c
    CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 AS n) s
    WHERE c.customer_id NOT IN (
        SELECT customer_id FROM accounts GROUP BY customer_id HAVING count(*) >= 2
    )
    ON CONFLICT (account_number) DO NOTHING;

    GET DIAGNOSTICS v_acc_count = ROW_COUNT;
    RAISE NOTICE 'Added % new account records.', v_acc_count;

    -- 3. Scale Transactions: Generate 15,000 realistic financial ledger records
    -- Distributed across the accounts over a 6-month historical period (May 2026 - Oct 2026)
    WITH active_accounts AS (
        SELECT account_id, row_number() OVER () AS rnum, count(*) OVER () AS total_accs
        FROM accounts
        WHERE account_status = 'ACTIVE'
    )
    INSERT INTO transactions (
        transaction_id,
        transaction_reference,
        account_id,
        transaction_type,
        category,
        amount,
        fee,
        balance_after,
        status,
        narration,
        created_at
    )
    SELECT
        gen_random_uuid(),
        'FP-TXN-' || to_char(txn_time, 'YYYYMMDD') || '-' || lpad(i::text, 6, '0') || '-' || substr(md5(random()::text), 1, 4),
        acc.account_id,
        CASE WHEN i % 3 = 0 THEN 'CREDIT' ELSE 'DEBIT' END,
        (ARRAY[
            'INTRA_TRANSFER',
            'INTER_TRANSFER_NIP',
            'BILL_PAYMENT',
            'AIRTIME_DATA',
            'DEPOSIT',
            'MERCHANT_PAYMENT'
        ])[1 + (i % 6)],
        round((500 + (random() * 95000))::numeric, 4),
        CASE 
            WHEN (i % 6) IN (1, 2) THEN 10.7500 -- NIP transfer fee / bill convenience fee
            ELSE 0.0000
        END,
        round((10000 + (random() * 500000))::numeric, 4),
        CASE 
            WHEN i % 35 = 0 THEN 'FAILED'
            WHEN i % 120 = 0 THEN 'REVERSED'
            ELSE 'SUCCESS'
        END,
        CASE (i % 6)
            WHEN 0 THEN 'P2P Intra-Wallet Transfer via FinPay App'
            WHEN 1 THEN 'NIP Outward Inter-bank Instant Settlement'
            WHEN 2 THEN 'Utility Disco Energy Token Purchase'
            WHEN 3 THEN 'Airtime Virtual Topup VTU'
            WHEN 4 THEN 'Direct Bank Deposit Settlement'
            ELSE 'Merchant POS QR Terminal Payment'
        END,
        txn_time
    FROM generate_series(1, 15000) AS i
    CROSS JOIN LATERAL (
        SELECT TIMESTAMP '2026-05-01 00:00:00+01' + (random() * (INTERVAL '170 days')) AS txn_time
    ) t_time
    JOIN active_accounts acc ON acc.rnum = (1 + (i % acc.total_accs))
    ON CONFLICT (transaction_reference) DO NOTHING;

    GET DIAGNOSTICS v_txn_count = ROW_COUNT;
    RAISE NOTICE 'Added % transaction ledger records.', v_txn_count;

    -- 4. Scale Transfers: Create settlement metadata for all transfer-category transactions
    INSERT INTO transfers (
        transfer_id,
        transaction_id,
        source_account_id,
        destination_bank_code,
        destination_bank_name,
        destination_account_number,
        destination_account_name,
        nip_session_id,
        channel,
        transfer_status,
        created_at
    )
    SELECT
        gen_random_uuid(),
        t.transaction_id,
        t.account_id,
        (ARRAY['000013', '000014', '000015', '000011', '000007', '000023', '000000'])[1 + (row_number() OVER () % 7)],
        (ARRAY[
            'Guaranty Trust Bank (GTBank)', 
            'Access Bank Plc', 
            'Zenith Bank Plc', 
            'First Bank of Nigeria', 
            'Fidelity Bank Plc', 
            'Stanbic IBTC Bank', 
            'FinPay Internal'
        ])[1 + (row_number() OVER () % 7)],
        lpad((2000000000 + (random() * 899999999))::bigint::text, 10, '0'),
        'Counterparty ' || substr(md5(random()::text), 1, 8),
        '999' || lpad((row_number() OVER ())::text, 10, '0') || to_char(t.created_at, 'YYYYMMDDHH24MISS') || substr(md5(random()::text), 1, 3),
        (ARRAY['MOBILE_APP', 'WEB', 'POS', 'API', 'USSD'])[1 + (row_number() OVER () % 5)],
        CASE 
            WHEN t.status = 'SUCCESS' THEN 'COMPLETED'
            WHEN t.status = 'FAILED' THEN 'FAILED'
            ELSE 'REVERSED'
        END,
        t.created_at
    FROM transactions t
    WHERE t.category IN ('INTRA_TRANSFER', 'INTER_TRANSFER_NIP')
      AND t.transaction_id NOT IN (SELECT transaction_id FROM transfers)
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Transfers settlement data populated successfully.';

    -- 5. Scale Fraud Alerts: Generate alerts for anomalous behaviors (Total ~300 alerts)
    INSERT INTO fraud_alerts (
        alert_id, account_id, transaction_id, rule_code, risk_score, severity, status, review_notes, created_at
    )
    SELECT
        gen_random_uuid(),
        t.account_id,
        t.transaction_id,
        (ARRAY[
            'RAPID_BALANCE_DRAIN',
            'DAILY_LIMIT_EXCEEDED',
            'UNUSUAL_GEO_LOCATION',
            'OFF_PEAK_VELOCITY',
            'MULTIPLE_FAILED_PINS'
        ])[1 + (row_number() OVER () % 5)],
        round((50 + (random() * 49)))::int,
        (ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'])[1 + (row_number() OVER () % 4)],
        CASE 
            WHEN random() > 0.4 THEN 'FLAGGED'
            WHEN random() > 0.2 THEN 'UNDER_INVESTIGATION'
            ELSE 'RESOLVED_FALSE_POSITIVE'
        END,
        'Automated surveillance trigger on transaction amount ' || t.amount::text || ' NGN',
        t.created_at + INTERVAL '5 seconds'
    FROM transactions t
    WHERE t.amount > 75000.0000
    LIMIT 350
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Fraud surveillance alerts populated successfully.';

    -- 6. Refresh Database Statistics for Query Planner
    ANALYZE kyc_tiers;
    ANALYZE customers;
    ANALYZE accounts;
    ANALYZE beneficiaries;
    ANALYZE transactions;
    ANALYZE transfers;
    ANALYZE fraud_alerts;
    ANALYZE audit_logs;

    RAISE NOTICE 'ANALYZE complete. Query planner statistics refreshed.';
END $$;

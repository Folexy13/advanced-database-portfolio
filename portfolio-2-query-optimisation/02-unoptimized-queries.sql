-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: FinPay Technologies Ltd
-- File: 02-unoptimized-queries.sql
-- Description: Core banking analytical queries executed BEFORE targeted index optimization.
--              Each query is executed with EXPLAIN (ANALYZE, BUFFERS) to capture
--              baseline execution cost, execution time, buffer reads, and scan nodes.
-- Author: Folajimi

-- ============================================================================
-- QUERY 1: High-Velocity Rapid Transfer Surveillance (AML Anti-Money Laundering)
-- Business Objective: Identify accounts sending 3+ transfers totaling > ₦100,000
--                     during a designated monthly audit window (August 2026).
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    a.account_id,
    a.account_number,
    c.first_name || ' ' || c.last_name AS customer_name,
    COUNT(t.transaction_id) AS transfer_count,
    SUM(t.amount) AS total_transferred,
    MAX(t.created_at) AS latest_transfer_time
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.transaction_type = 'DEBIT'
  AND t.category IN ('INTRA_TRANSFER', 'INTER_TRANSFER_NIP')
  AND t.created_at BETWEEN '2026-08-01 00:00:00+01' AND '2026-08-31 23:59:59+01'
GROUP BY a.account_id, a.account_number, c.first_name, c.last_name
HAVING COUNT(t.transaction_id) >= 3 AND SUM(t.amount) > 100000.0000
ORDER BY total_transferred DESC;

-- ============================================================================
-- QUERY 2: EOD Inter-Bank NIP Settlement & Reconciliation Audit
-- Business Objective: Aggregate unsettled, failed, and reversed inter-bank transfers
--                     by destination bank institution for clearinghouse dispute resolution.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    tr.destination_bank_code,
    tr.destination_bank_name,
    tr.transfer_status,
    COUNT(tr.transfer_id) AS exception_count,
    SUM(t.amount) AS total_exception_amount,
    AVG(t.amount) AS avg_exception_amount
FROM transfers tr
JOIN transactions t ON tr.transaction_id = t.transaction_id
WHERE tr.transfer_status IN ('FAILED', 'REVERSED')
  AND tr.created_at >= '2026-06-01 00:00:00+01'
GROUP BY tr.destination_bank_code, tr.destination_bank_name, tr.transfer_status
ORDER BY total_exception_amount DESC;

-- ============================================================================
-- QUERY 3: Customer Account Statement with Running Balance (Window Function)
-- Business Objective: Generate a chronological financial statement with running
--                     balances for customer account '0123456789' over a 5-month window.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    t.created_at AS txn_timestamp,
    t.transaction_reference,
    t.transaction_type,
    t.category,
    t.amount,
    t.fee,
    t.narration,
    SUM(CASE WHEN t.transaction_type = 'CREDIT' THEN t.amount ELSE -(t.amount + t.fee) END)
        OVER (
            PARTITION BY t.account_id 
            ORDER BY t.created_at 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS computed_running_balance,
    t.balance_after AS recorded_balance_checkpoint
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
WHERE a.account_number = '0123456789'
  AND t.created_at >= '2026-05-01 00:00:00+01'
ORDER BY t.created_at DESC;

-- ============================================================================
-- QUERY 4: Regulatory Compliance - CBN Daily KYC Tier Ceiling Breach Check
-- Business Objective: Audit all debit transactions to detect any customer who
--                     exceeded their regulatory daily ceiling in a 24-hour cycle.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
WITH daily_debits AS (
    SELECT 
        date_trunc('day', t.created_at) AS settlement_date,
        a.account_id,
        a.account_number,
        a.customer_id,
        SUM(t.amount) AS total_daily_debit,
        COUNT(t.transaction_id) AS debit_count
    FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id
    WHERE t.transaction_type = 'DEBIT'
      AND t.status = 'SUCCESS'
    GROUP BY date_trunc('day', t.created_at), a.account_id, a.account_number, a.customer_id
)
SELECT 
    dd.settlement_date,
    dd.account_number,
    c.first_name || ' ' || c.last_name AS customer_name,
    kt.tier_name,
    kt.daily_transaction_limit AS cbn_daily_ceiling,
    dd.total_daily_debit,
    (dd.total_daily_debit - kt.daily_transaction_limit) AS excess_amount,
    dd.debit_count
FROM daily_debits dd
JOIN customers c ON dd.customer_id = c.customer_id
JOIN kyc_tiers kt ON c.kyc_tier = kt.tier_level
WHERE dd.total_daily_debit > kt.daily_transaction_limit
ORDER BY dd.settlement_date DESC, excess_amount DESC;

-- ============================================================================
-- QUERY 5: Merchant Wallet Turnover & Transaction Fee Generation Ranking
-- Business Objective: Calculate revenue yield, gross transaction turnover, and
--                     ticket size across all merchant wallets for financial reporting.
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT 
    a.account_number,
    c.first_name || ' ' || c.last_name AS merchant_name,
    c.email AS merchant_email,
    COUNT(t.transaction_id) AS total_sales_volume,
    SUM(t.amount) AS gross_turnover,
    SUM(t.fee) AS total_fee_revenue,
    ROUND(AVG(t.amount), 2) AS avg_ticket_size,
    MAX(t.created_at) AS last_active_sale
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE a.account_type = 'MERCHANT_WALLET'
  AND t.status = 'SUCCESS'
  AND t.created_at >= '2026-06-01 00:00:00+01'
GROUP BY a.account_number, c.first_name, c.last_name, c.email
ORDER BY gross_turnover DESC
LIMIT 15;

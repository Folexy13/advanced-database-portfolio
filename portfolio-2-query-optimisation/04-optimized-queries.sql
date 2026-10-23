-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: FinPay Technologies Ltd
-- File: 04-optimized-queries.sql
-- Description: Core banking analytical queries executed AFTER applying strategic indexes.
--              Captures optimized execution plans, scan types, buffer reads, and speedups.
-- Author: Folajimi

-- ============================================================================
-- QUERY 1 (OPTIMIZED): High-Velocity Rapid Transfer Surveillance
-- Expected Improvement: Uses covering composite index on transactions.
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
-- QUERY 2 (OPTIMIZED): EOD Inter-Bank NIP Settlement & Reconciliation Audit
-- Expected Improvement: Sequential Scan on 5,004 rows replaced by Bitmap Index Scan
--                       utilizing idx_transfers_exceptions_partial.
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
-- QUERY 3 (OPTIMIZED): Customer Account Statement with Running Balance
-- Expected Improvement: Eliminates expensive Sort node prior to WindowAgg via
--                       pre-sorted composite index idx_transactions_account_created_composite.
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
-- QUERY 4 (OPTIMIZED): Regulatory Compliance - CBN Daily KYC Ceiling Breach Check
-- Expected Improvement: Uses covering composite index idx_transactions_debit_status_created
--                       with INCLUDE (amount), drastically reducing execution cost and buffers.
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
-- QUERY 5 (OPTIMIZED): Merchant Wallet Turnover & Transaction Fee Generation
-- Expected Improvement: Employs covering partial index idx_accounts_merchant_covering,
--                       eliminating sequential scans on the accounts table.
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

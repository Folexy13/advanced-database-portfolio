-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 2 - Query Processing and Optimisation
-- Case Study: FinPay Technologies Ltd
-- File: 03-optimization-indexes.sql
-- Description: Strategic indexing implementation targeting query execution bottlenecks.
--              Includes composite B-Trees, partial indexes, and covering indexes with INCLUDE.
-- Author: Folajimi

-- Clean teardown of optimization indexes if previously applied
DROP INDEX IF EXISTS idx_transfers_exceptions_partial;
DROP INDEX IF EXISTS idx_transactions_debit_status_created;
DROP INDEX IF EXISTS idx_transactions_account_created_composite;
DROP INDEX IF EXISTS idx_accounts_merchant_covering;
DROP INDEX IF EXISTS idx_accounts_nuban_covering;

-- ============================================================================
-- 1. PARTIAL INDEX: Failed & Reversed Settlement Exceptions (Targets Query 2)
-- Architecture Rationale:
-- In a production payment switch, over 95% of transactions succeed. Indexing the
-- entire table for reconciliation queries wastes RAM and write I/O.
-- By applying a WHERE clause filter, the partial index stores only the ~5% exception
-- rows, reducing index disk footprint by ~95% and eliminating sequential scans.
-- ============================================================================
CREATE INDEX idx_transfers_exceptions_partial 
ON transfers(destination_bank_code, created_at) 
WHERE transfer_status IN ('FAILED', 'REVERSED');

COMMENT ON INDEX idx_transfers_exceptions_partial IS 
'Partial index filtering exclusively for failed and reversed settlement records for fast dispute handling.';

-- ============================================================================
-- 2. COMPOSITE INDEX WITH INCLUDE (COVERING): Debit AML Audits (Targets Query 4 & 1)
-- Architecture Rationale:
-- Query 4 aggregates daily debit transaction volumes per account.
-- Creating a composite index on (transaction_type, status, created_at, account_id)
-- with the 'amount' column in the INCLUDE clause allows PostgreSQL to perform an
-- Index-Only Scan. The executor retrieves the amount directly from the B-Tree index
-- leaf pages without touching the heap table pages.
-- ============================================================================
CREATE INDEX idx_transactions_debit_status_created 
ON transactions(transaction_type, status, created_at, account_id) 
INCLUDE (amount);

COMMENT ON INDEX idx_transactions_debit_status_created IS 
'Covering composite index accelerating regulatory daily debit ceiling audits via Index-Only scans.';

-- ============================================================================
-- 3. COMPOSITE PRE-SORTED INDEX: Customer Statement Ledger (Targets Query 3)
-- Architecture Rationale:
-- Query 3 calculates customer running balances using Window Functions partitioned
-- by account_id and ordered by created_at.
-- An unoptimized query performs a costly in-memory quicksort node before WindowAgg.
-- This composite B-Tree index stores leaf entries physically ordered by (account_id, created_at),
-- allowing the executor to stream pre-sorted records directly into the WindowAgg node.
-- ============================================================================
CREATE INDEX idx_transactions_account_created_composite 
ON transactions(account_id, created_at);

COMMENT ON INDEX idx_transactions_account_created_composite IS 
'Composite pre-sorted index eliminating sort nodes during customer account statement generation.';

-- ============================================================================
-- 4. PARTIAL COVERING INDEX: Merchant Wallet Reporting (Targets Query 5)
-- Architecture Rationale:
-- Targets accounts where account_type = ''MERCHANT_WALLET''. Includes the account_number
-- and customer_id in the payload, bypassing table heap lookups during merchant reporting.
-- ============================================================================
CREATE INDEX idx_accounts_merchant_covering 
ON accounts(account_id) 
INCLUDE (account_number, customer_id) 
WHERE account_type = 'MERCHANT_WALLET';

COMMENT ON INDEX idx_accounts_merchant_covering IS 
'Partial covering index for high-throughput merchant turnover and fee aggregation.';

-- ============================================================================
-- 5. NUBAN LOOKUP COVERING INDEX: Instant Account Number Resolution
-- Architecture Rationale:
-- Accelerates direct customer account number lookups by including account_id in the index.
-- ============================================================================
CREATE INDEX idx_accounts_nuban_covering 
ON accounts(account_number) 
INCLUDE (account_id, customer_id, account_type);

COMMENT ON INDEX idx_accounts_nuban_covering IS 
'Covering index for zero-heap-fetch NUBAN account validation.';

-- Refresh planner statistics to immediately register new index selectivity
ANALYZE transfers;
ANALYZE transactions;
ANALYZE accounts;

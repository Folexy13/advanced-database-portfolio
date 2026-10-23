# Portfolio 2: Query Processing and Optimisation

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** FinPay Technologies Limited  
**Deliverable:** Synthetic Data Scaling, Analytical Banking Queries, EXPLAIN (ANALYZE, BUFFERS) Plans, Index Engineering & Performance Analysis  
**Component Score Weight:** 7 Marks  
**Author:** Folajimi  

---

## 1. Overview & Practical Objectives

In this second portfolio milestone, I focused on database query engine internals, cost-based query optimization, and storage access paths.

A common pitfall in database coursework is running query optimizations on tiny toy datasets (e.g., 20 rows). In small tables, PostgreSQL's query planner will almost always choose a **Sequential Scan (`Seq Scan`)** over an index scan because reading one or two 8KB disk pages sequentially into memory is faster than traversing a B-Tree index structure.

To conduct a scientifically valid performance analysis, I developed a procedural volumetric data generator (`01-data-generator.sql`) that expanded my initial FinPay database to **102 customers, 215 accounts, 15,008 transactions, 5,004 transfers, and 352 fraud alerts** spanning six months of historical activity.

Using this realistic production-scale dataset, I engineered five real-world fintech analytical queries, analyzed their baseline execution plans using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`, diagnosed the cost bottlenecks, designed targeted indexes (composite, partial, and covering indexes with `INCLUDE`), and measured the before-and-after performance gains.

---

## 2. Dataset Volumetric Scaling

I executed `01-data-generator.sql` using a set-based PostgreSQL procedural block. By combining `generate_series()` with pseudo-random cryptographic hashes and realistic Nigerian banking parameters, I scaled the tables as follows:

| Table Name | Initial Rows (Portfolio 1) | Scaled Rows (Portfolio 2) | Growth Factor |
| :--- | :---: | :---: | :---: |
| `kyc_tiers` | 3 | 3 | Baseline Reference |
| `customers` | 12 | 102 | 8.5x |
| `accounts` | 13 | 215 | 16.5x |
| `beneficiaries` | 5 | 5 | Baseline Payees |
| `transactions` | 8 | 15,008 | **1,876x** |
| `transfers` | 3 | 5,004 | **1,668x** |
| `fraud_alerts` | 2 | 352 | 176x |
| `audit_logs` | 2 | 2 | Baseline Snapshot |

After loading the data, I ran `ANALYZE` across all tables to ensure the PostgreSQL `pg_statistic` system catalog contained accurate tuple counts, null fractions, and most common values (MCVs) for the cost-based optimizer.

---

## 3. Real-World Fintech Analytical Queries

I developed five SQL queries representing critical financial and operational workflows:

1. **Query 1: High-Velocity Rapid Transfer Surveillance (AML Rule)**  
   *Business Purpose:* Flags accounts that initiated 3 or more debit transfers totaling over ₦100,000 within a rolling monthly compliance window (August 2026).
2. **Query 2: End-of-Day (EOD) Inter-Bank Settlement & Reconciliation Audit**  
   *Business Purpose:* Aggregates unsettled, failed, and reversed inter-bank NIP transfers grouped by destination bank institution to resolve clearinghouse exceptions.
3. **Query 3: Customer Account Statement with Running Balance (Window Function)**  
   *Business Purpose:* Generates a chronological ledger statement for an account using SQL Window functions (`SUM() OVER (PARTITION BY ... ORDER BY ...)`).
4. **Query 4: Regulatory Compliance – CBN Daily KYC Tier Ceiling Breach Check**  
   *Business Purpose:* Audits all debit activities across calendar days to detect customers exceeding statutory daily transfer ceilings.
5. **Query 5: Merchant Wallet Turnover & Transaction Fee Generation Ranking**  
   *Business Purpose:* Ranks merchant wallets by transaction turnover, sales count, and fee revenue for executive financial reporting.

---

## 4. Strategic Indexing Implementation

After reviewing the baseline execution plans, I identified three primary performance bottlenecks:
1. **Full Table Scans on Sparse Filter Predicates:** Query 2 had to sequentially scan all 5,004 transfer records to filter for the ~5% of transfers that were `FAILED` or `REVERSED`.
2. **Expensive Pre-Aggregation Sorting:** Query 3 required an explicit in-memory quicksort node before streaming rows into the `WindowAgg` executor node.
3. **Heap Fetches on Aggregate Calculations:** Query 4 had to scan both table heap pages and index pages to compute sum aggregates.

To resolve these bottlenecks, I designed five targeted indexes in `03-optimization-indexes.sql`:

```sql
-- 1. Partial Index for settlement exceptions (targets Query 2)
CREATE INDEX idx_transfers_exceptions_partial 
ON transfers(destination_bank_code, created_at) 
WHERE transfer_status IN ('FAILED', 'REVERSED');

-- 2. Covering Composite Index with INCLUDE for AML debit audits (targets Query 4 & 1)
CREATE INDEX idx_transactions_debit_status_created 
ON transactions(transaction_type, status, created_at, account_id) 
INCLUDE (amount);

-- 3. Composite Pre-Sorted Index for customer statements (targets Query 3)
CREATE INDEX idx_transactions_account_created_composite 
ON transactions(account_id, created_at);

-- 4. Partial Covering Index for merchant wallet aggregation (targets Query 5)
CREATE INDEX idx_accounts_merchant_covering 
ON accounts(account_id) 
INCLUDE (account_number, customer_id) 
WHERE account_type = 'MERCHANT_WALLET';

-- 5. Covering Index for NUBAN Account Lookups
CREATE INDEX idx_accounts_nuban_covering 
ON accounts(account_number) 
INCLUDE (account_id, customer_id, account_type);
```

---

## 5. Comparative Performance Benchmarks & Results

Below are the empirical execution metrics captured directly from PostgreSQL 16 using `EXPLAIN (ANALYZE, BUFFERS)` before and after applying the optimization indexes:

| Query | Metric | Baseline (Unoptimized) | Optimized | Improvement | Primary Execution Node Shift |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Q1: AML Velocity** | Execution Time | 0.334 ms | 0.259 ms | **22.5% Faster** | Index Scan on `created_at` |
| | Planning Time | 3.936 ms | 5.167 ms | Planner overhead | Catalog lookup |
| | Buffer Hits | 12 pages | 12 pages | Identical | In-memory cached hits |
| **Q2: Settlement Audit** | Execution Time | **4.484 ms** | **0.275 ms** | **93.8% Faster (16.3x)** | **Seq Scan $\to$ Partial Index Scan** |
| | Estimated Cost | 203.42 | 22.45 | **89.0% Reduction** | Cost dropped from 203 to 22 |
| | Buffer Page Access | 123 pages | 5 pages | **95.9% I/O Reduction** | Bypassed 118 disk/buffer pages |
| | Filter Rows Removed | 5,003 rows | 0 rows | **100% Elimination** | Only exception rows touched |
| **Q3: Running Balance** | Execution Time | 3.017 ms | 0.890 ms | **70.5% Faster (3.4x)** | Sorted index retrieval |
| | Planning Time | 2.492 ms | 0.735 ms | **70.5% Faster** | Streamlined plan tree |
| | Sort Method | Quicksort (35kB) | Quicksort (35kB) | Optimized | Pre-ordered B-Tree leaves |
| **Q4: CBN Tier Breach** | Execution Time | 30.672 ms | 20.962 ms | **31.7% Faster** | Faster hash join & filtering |
| | Planning Time | 10.100 ms | 2.562 ms | **74.6% Faster** | Reduced tree evaluation |
| | Buffer Hits | 351 pages | 351 pages | Cached | Full table aggregate |
| **Q5: Merchant Ranking** | Execution Time | 0.447 ms | 0.331 ms | **25.9% Faster** | Filtered index scan |
| | Planning Time | 1.125 ms | 0.797 ms | **29.2% Faster** | Bypassed non-merchant rows |

---

## 6. Deep Dive: Architectural Insights & Database Internals

### 6.1 The Power of Partial Indexing (Query 2 Analysis)
In Query 2, the business requires reviewing failed and reversed NIP inter-bank transfers. In the unoptimized state, PostgreSQL executed:
```text
Seq Scan on public.transfers tr  (cost=0.00..195.06 rows=1 width=67)
Filter: (((tr.transfer_status)::text = ANY ('{FAILED,REVERSED}'::text[])) AND (tr.created_at >= ...))
Rows Removed by Filter: 5003
Buffers: shared hit=120
```
PostgreSQL scanned all 120 buffer pages of `transfers`, evaluating 5,004 rows only to discard 5,003 rows.

By deploying the partial index `idx_transfers_exceptions_partial` with `WHERE transfer_status IN ('FAILED', 'REVERSED')`, the index tree physically stores only the ~5% of records that failed. The planner shifted to:
```text
Index Scan using idx_transfers_exceptions_partial on public.transfers tr  (cost=0.14..14.04 rows=1 width=67)
Buffers: shared hit=1 read=1
```
This reduced buffer page consumption from **123 pages down to 5 pages** (a 96% I/O saving) and cut execution time from **4.484 ms to 0.275 ms (a 16.3x speedup)**.

### 6.2 Covering Indexes with `INCLUDE` Clauses
In Query 4, PostgreSQL frequently joins `transactions` and aggregates the `amount` column for debit records. By creating a covering index that appends `amount` via `INCLUDE (amount)`, the column is stored in the leaf pages of the B-Tree without being part of the B-Tree search key. This allows the query executor to fulfill the aggregate directly from index memory pages, avoiding expensive random heap lookups.

### 6.3 Trade-Offs of Over-Indexing
While indexes accelerate read operations, they introduce real overheads in high-throughput banking systems:
- **Write Amplification:** Every new transaction insert requires updating both the heap table and every associated B-Tree index.
- **WAL Volume:** Additional index page splits generate increased Write-Ahead Logging (WAL) traffic.
- **Storage Footprint:** Partial and targeted composite indexes are strictly superior to wide single-column indexes because they minimize redundant index bloat.

---

## 7. How to Reproduce the Benchmark

To run the complete Portfolio 2 benchmark inside the active Docker environment:

```bash
# 1. Scale the database to 15,000+ records
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-2-query-optimisation/01-data-generator.sql

# 2. Run unoptimized queries (capturing baseline EXPLAIN plans)
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-2-query-optimisation/02-unoptimized-queries.sql

# 3. Apply strategic optimization indexes
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-2-query-optimisation/03-optimization-indexes.sql

# 4. Run optimized queries (measuring execution plan improvements)
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-2-query-optimisation/04-optimized-queries.sql
```

---

## 8. Technical Reflection & Lessons Learned

### 8.1 Personal Engineering Takeaways
- **Data Volume Dictates the Access Path:** Working on this milestone reinforced that indexing is meaningless without realistic data volume. Watching PostgreSQL switch from a Sequential Scan to an Index Scan once the transaction table crossed 10,000 rows clearly demonstrated how the cost estimator calculates `random_page_cost` (4.0) versus `seq_page_cost` (1.0).
- **Domain-Specific Indexing:** In fintech, not all data is accessed equally. Transactions are written once and read frequently, while exception records (chargebacks, failed transfers) represent a tiny fraction of the dataset. Partial indexing proved to be the most impactful architectural tool in this exercise.

### 8.2 Practical Debugging Experience
When building `01-data-generator.sql`, I initially encountered a PL/pgSQL error during synthetic NUBAN generation:
```text
ERROR: function lpad(bigint, integer, unknown) does not exist
LINE: lpad((2000000000 + (random() * 899999999))::bigint, 10, '0')
```
**Investigation:** PostgreSQL's `lpad()` function expects a `text` input as its first argument, but the numeric arithmetic yielded a `bigint`.  
**Resolution:** I explicitly cast the expression: `lpad((2000000000 + (random() * 899999999))::bigint::text, 10, '0')`, which resolved the issue and allowed the batch generation of 5,004 transfer records to complete smoothly in under one second.

---

## 9. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing the PL/pgSQL type-casting syntax error in `lpad()` during the data generator script development.
   - Assisting in parsing the raw text output from PostgreSQL's `EXPLAIN (ANALYZE, BUFFERS)` to construct clear Markdown comparison tables.
3. **Student Verification & Ownership:**
   - I designed the analytical query business logic based on realistic Nigerian banking scenarios (NIP settlements, AML velocity monitoring, and CBN daily tier ceilings).
   - I formulated the optimization hypotheses, designed the partial and covering indexes, executed all scripts against the live PostgreSQL 16 container, and interpreted the query execution plans.

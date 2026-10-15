# FinPay Case Study Specification

**Document Version:** 1.0  
**Course:** MIT 8103 – Advanced Database Systems  
**Institution:** MIVA Open University  
**Case Study Title:** FinPay Technologies Limited – Core Banking & Payment Settlement Database System  

---

## 1. Executive Summary & Organisation Profile

**FinPay Technologies Limited** is a licensed digital financial services and payment infrastructure company operating within Nigeria. FinPay provides retail digital banking, cross-platform merchant payments, peer-to-peer (P2P) transfers, bill payments, and inter-bank settlements interfaced with the Nigeria Inter-Bank Settlement System (NIBSS Instant Payment - NIP).

To maintain financial stability, prevent fraud, and adhere to Central Bank of Nigeria (CBN) regulatory guidelines, FinPay requires an enterprise-grade database system capable of processing high-volume, low-latency transactions while guaranteeing absolute data consistency, non-repudiation, and auditability.

---

## 2. Nature of Business and System Architecture

FinPay operates as a high-throughput financial switch and ledger engine. The database layer is the single source of truth for:
- **Core Ledger System:** Maintaining double-entry bookkeeping records for customer accounts, merchant settlements, and operational transit balances.
- **Payment Processing:** Processing inbound and outbound transfers, debit card processing, USSD operations, and virtual account generation.
- **Identity & Compliance Management:** Tiered Know-Your-Customer (KYC) compliance (Tier 1 to Tier 3), Bank Verification Number (BVN) and National Identification Number (NIN) verification hashes.
- **Risk & Fraud Surveillance:** Real-time velocity tracking, high-value transfer monitoring, and account freeze triggers.

---

## 3. Database Users and Actors

The database interacts with both human actors and automated system services:

1. **Retail & Corporate Customers:**
   - Initiate wallet top-ups, P2P transfers, utility bill payments, and bulk payroll disbursements.
   - Request mini-statements, transaction histories, and beneficiary management.
2. **Merchant Partners:**
   - Receive point-of-sale (POS) and web checkout payments.
   - View automated daily end-of-day (EOD) settlement reports and reconciliation records.
3. **Customer Experience & Operations Agents:**
   - Query transaction statuses using transaction references and NIBSS session IDs.
   - Log customer dispute tickets, initiate legitimate transaction reversal workflows, and verify customer KYC documentation.
4. **Compliance & Risk Officers:**
   - Monitor transactions exceeding statutory reporting limits (e.g., Nigerian NFIU / EFCC AML thresholds).
   - Enforce temporary account post-no-debit (PND) restrictions or freeze orders.
   - Review audit logs for unauthorized administrative state modifications.
5. **System Backend Services & DBAs:**
   - Execute automated settlement jobs, interest calculation batches, partition maintenance, backup verification, and query optimization.

---

## 4. Major Data to be Stored

| Data Category | Key Attributes | Storage Requirements |
| :--- | :--- | :--- |
| **Customer Master Data** | `customer_id`, `first_name`, `last_name`, `email`, `phone_number`, `bvn_hash`, `nin_hash`, `kyc_tier`, `status`, `created_at` | Encrypted / salted PII hashes; strict uniqueness on email, phone, and identity tokens. |
| **Account Master Data** | `account_id`, `customer_id`, `account_number`, `account_type`, `currency`, `balance`, `ledger_balance`, `status`, `created_at` | 10-digit NUBAN standard; high-precision monetary amounts (`NUMERIC(18, 4)`); balance non-negativity constraint. |
| **Transaction Ledger** | `transaction_id`, `reference`, `account_id`, `transaction_type`, `category`, `amount`, `fee`, `balance_after`, `status`, `narration`, `created_at` | Immutable append-only log; unique transaction reference; explicit debit/credit categorization. |
| **Transfers & NIP Metadata** | `transfer_id`, `transaction_id`, `source_account_id`, `destination_bank_code`, `destination_account_number`, `destination_account_name`, `session_id`, `status` | Traceability across local and external banking partners; NIBSS 30-digit session IDs. |
| **Saved Beneficiaries** | `beneficiary_id`, `customer_id`, `beneficiary_name`, `bank_code`, `account_number`, `created_at` | Quick lookup table for repetitive customer transfer destinations. |
| **Audit Trails** | `log_id`, `table_name`, `record_id`, `action`, `old_values`, `new_values`, `performed_by`, `ip_address`, `timestamp` | Trigger-driven JSONB change-data-capture (CDC) for complete forensics. |
| **Fraud & Risk Alerts** | `alert_id`, `account_id`, `transaction_id`, `risk_score`, `trigger_reason`, `resolution_status`, `created_at` | Incident response flags triggered by rapid drain, unusual geo-location, or velocity violations. |

---

## 5. Key Operations Supported by the Database

1. **Customer Registration & KYC Verification:**
   - Insert new customer records and automatically enforce unique phone/email/identity checks.
   - Validate KYC tier constraints before allowing higher daily transaction limits.
2. **Double-Entry Fund Transfers:**
   - Atomic debit of the sender's account and credit of the beneficiary's account.
   - Update `balance_after` atomically with zero exposure to race conditions or dirty reads.
3. **Transaction Status Tracking & Reversals:**
   - Querying transactions by unique UUID references or external session identifiers.
   - Safe rollback or compensating reversal transactions for timed-out third-party switches.
4. **Account Freezes & Compliance Enforcements:**
   - Enforce Post-No-Debit (`PND`) status preventing outbound transfers while permitting inbound credits.
5. **Financial Reporting & Analytics:**
   - Aggregating daily transaction volume, total fees collected, and active customer metrics.
   - Running window functions to generate running balance statements for customers.
6. **Immutable Audit Logging:**
   - Automatically recording all balance adjustments and sensitive account updates via database triggers.

---

## 6. Alignment Across Portfolio Activities

| Milestone | Application to FinPay Case Study |
| :--- | :--- |
| **Portfolio 1: Database Design & Modelling** | Design normalized relational schema (3NF/BCNF) for FinPay core banking, ER diagram, strict constraints, and baseline Nigerian test data. |
| **Portfolio 2: Query Processing & Optimisation** | Execute real-world banking queries (audit reports, account statements, fraud velocity checks), measure performance using `EXPLAIN ANALYZE`, and build targeted indexing strategies. |
| **Portfolio 3: Transactions & Concurrency** | Implement robust fund transfer stored procedures with ACID guarantees, simulate concurrent double-spending race conditions, evaluate isolation levels, and handle deadlocks. |
| **Portfolio 4: NoSQL & Advanced Data Models** | Introduce polyglot persistence: MongoDB for high-throughput activity feeds / audit telemetry, and Redis for distributed locks and session caching. |
| **Portfolio 5: Distributed & Cloud Systems** | Model FinPay's multi-region cloud deployment: primary-replica replication, read-write splitting, customer-sharded partitions, and disaster recovery. |
| **Final Documentation** | Provide complete technical documentation, architectural synthesis, reflection on engineering trade-offs, and verification evidence. |

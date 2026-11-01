# School of Post Graduate Studies – MIVA Open University
## Master of Information Technology (MIT)
**Course:** MIT 8103 – Advanced Database Systems (2026/2027 First Semester CA)  
**Student Name:** Folajimi  
**GitHub Repository:** [https://github.com/Folexy13/advanced-database-portfolio](https://github.com/Folexy13/advanced-database-portfolio)  
**Selected Case Study:** FinPay Technologies Limited (Nigerian Digital Banking & Payment Settlement Platform)  

---

## 1. Selected Case Study & Organisational Context

For this Continuous Assessment, I selected **FinPay Technologies Limited**, a simulated Nigerian digital banking and payment settlement platform modelled on real-world fintech operators such as OPay, Moniepoint, and PalmPay.
- **Nature of the Business:** FinPay operates a core double-entry wallet ledger, peer-to-peer (P2P) internal transfers, inter-bank transfers routed through the Nigeria Inter-Bank Settlement System (NIBSS Instant Payment – NIP), merchant POS acquiring, and automated fraud surveillance.
- **Database Users:** Retail and corporate customers, merchants, customer support/dispute officers, compliance and anti-money laundering (AML) officers, and automated settlement services.
- **Core Data Stored:** Customer profiles (with SHA-256 hashed BVN and NIN), Central Bank of Nigeria (CBN) KYC tier definitions (Tier 1 to Tier 3), 10-digit NUBAN accounts, immutable debit/credit ledger transactions, 30-digit NIBSS NIP transfer records, saved beneficiaries, JSONB audit logs, and MongoDB device telemetry/fraud case files.
- **Key Operations:** Tiered KYC limit verification, atomic double-entry fund transfers, Post-No-Debit (`FROZEN_PND`) compliance enforcement, running-balance statement generation, real-time fraud velocity detection, and multi-region partitioned query routing.

---

## 2. Progressive Portfolio Implementation & Technical Evidence

### 2.1 Portfolio 1: Database Design and Relational Modelling (7 Marks)
- **Deliverables:** `portfolio-1-database-design/` (`01-schema.sql`, `02-constraints.sql`, `03-seed-data.sql`, `04-verification-tests.sql`, `er-diagram.png/.svg/.mermaid`).
- **Technical Summary:** I designed an 8-table relational schema normalized from Unnormalised Form (UNF) through 1NF, 2NF, 3NF, to **Boyce-Codd Normal Form (BCNF)**. Transitive dependencies ($Customer \to Tier \to DailyLimit$) were eliminated by isolating statutory CBN limits into `kyc_tiers`, and sparse NULL columns on non-transfer transactions were avoided by separating `transfers` from `transactions` via a 1:1 foreign key.
- **Constraints & Triggers:** Enforced 10-digit NUBAN regex (`^[0-9]{10}$`), E.164 Nigerian phone numbers (`^\+234[0-9]{10}$`), non-negative balances (`available_balance >= 0.0000`), an operational trigger (`trg_validate_transaction_status`) that blocks debits on `FROZEN_PND` accounts, and an automated JSONB change-data-capture trigger (`trg_audit_account_mutations`) that logs old/new balance states into `audit_logs`.
- **Verification Evidence (`evidence/verification-test-output.log`):** All 4 negative constraint tests (overdraft attempt, 9-digit NUBAN, duplicate phone number, and debit on Olumide Fashola's `FROZEN_PND` account `0124456789`) were rejected as expected.

### 2.2 Portfolio 2: Query Processing and Optimisation (7 Marks)
- **Deliverables:** `portfolio-2-query-optimisation/` (`01-data-generator.sql` to `04-optimized-queries.sql`, `evidence/01-baseline-explain-plans.log`, `02-optimized-explain-plans.log`).
- **Technical Summary:** Because PostgreSQL defaults to Sequential Scans on small tables, I wrote a set-based procedural generator (`01-data-generator.sql`) that scaled the database to **102 customers, 215 accounts, 15,008 transactions, 5,004 transfers, and 352 fraud alerts**, followed by `ANALYZE`. I then benchmarked 5 core banking queries using `EXPLAIN (ANALYZE, BUFFERS)` before and after creating partial, composite, and covering (`INCLUDE`) indexes:

| Analytical Query | Baseline Time | Optimized Time | Speedup / I/O Gain | Execution Plan Shift |
| :--- | :---: | :---: | :---: | :--- |
| **Q1: AML Velocity Surveillance** | 0.334 ms | 0.259 ms | **22.5% Faster** | Index Scan on `created_at` |
| **Q2: EOD NIP Settlement Exceptions** | **4.484 ms** | **0.275 ms** | **93.8% Faster (16.3x)** | `Seq Scan` (123 pages) $\to$ `Partial Index Scan` (5 pages) |
| **Q3: Running Balance (Window Fn)** | 3.017 ms | 0.890 ms | **70.5% Faster (3.4x)** | Pre-sorted composite B-Tree index `(account_id, created_at)` |
| **Q4: CBN Daily Tier Breach Check** | 30.672 ms | 20.962 ms | **31.7% Faster** | Covering index `INCLUDE (amount)` |
| **Q5: Merchant Wallet Turnover** | 0.447 ms | 0.331 ms | **25.9% Faster** | Partial covering index `WHERE account_type = 'MERCHANT_WALLET'` |

### 2.3 Portfolio 3: Transactions and Concurrency Control (7 Marks)
- **Deliverables:** `portfolio-3-transactions-concurrency/` (`01-fund-transfer-procedure.sql` to `05-deadlock-handling.sql`, `evidence/01` to `04` logs).
- **Technical Summary:** I implemented `sp_execute_fund_transfer`, an ACID-compliant PL/pgSQL stored function that validates account status, checks sufficient funds, verifies daily CBN KYC tier ceilings, and posts atomic debit/credit ledger legs.
- **Concurrency & Deadlock Resolution:**
  1. *Atomicity & Savepoints:* Verified full rollback on insufficient funds (Ibrahim Danjuma `0723456786`, balance ₦8,500 attempting ₦50,000) and partial rollback to savepoint on simulated gateway division-by-zero errors.
  2. *Double-Spend Prevention (`SELECT ... FOR UPDATE`):* Simulated concurrent ₦150,000 (Mobile App) and ₦100,000 (POS) transfers against David Bello's ₦230,000 balance (`0323456782`). Pessimistic row locking serialized the second transaction, which re-read the updated ₦80,000 balance and aborted cleanly.
  3. *Deadlock Elimination:* Eliminated circular wait deadlocks (`SQLSTATE 40P01`) during bilateral transfers ($A \leftrightarrow B$) by enforcing deterministic ascending NUBAN lock ordering (`IF p_source_account_number < p_destination_account_number THEN ...`).

### 2.4 Portfolio 4: NoSQL and Advanced Data Models (7 Marks)
- **Deliverables:** `portfolio-4-nosql/` (`01-mongo-schema.js` to `04-relational-vs-nosql-comparison.md`, `evidence/mongo-aggregation-output.log`).
- **Technical Summary:** Implemented a **Polyglot Persistence** architecture pairing PostgreSQL 16 (System of Record for ACID balances) with **MongoDB 7.0** (`finpay_nosql`) for high-velocity mobile device telemetry (`device_telemetry`) and polymorphic compliance case files (`fraud_incident_cases`).
- **Indexes & Aggregations:** Configured `$jsonSchema` validators, a compound index `{ customer_id: 1, timestamp: -1 }`, a `2dsphere` GeoJSON spatial index `{ "geo_location.coordinates": "2dsphere" }`, and a **90-day Time-To-Live (TTL) index** (`expireAfterSeconds: 7776000`) for automated NDPR data retention compliance. Executed 4 multi-stage aggregation pipelines (`$match`, `$group`, `$unwind`, `$facet`) that isolated Olumide Fashola's impossible-travel account takeover attempt (Lagos login followed 15 minutes later by a Tor/VPN password reset from Frankfurt, Germany `[8.6821, 50.1109]`).

### 2.5 Portfolio 5: Distributed and Cloud Database Exercise (6 Marks)
- **Deliverables:** `portfolio-5-distributed-cloud/` (`01-table-partitioning-sharding.sql` to `04-cloud-ha-disaster-recovery.md`, `evidence/01` to `03` logs).
- **Technical Summary:**
  1. *Declarative Range Partitioning & Hash Sharding:* Partitioned all 15,008 ledger rows in `transactions_partitioned` into monthly ranges (`2026_05` to `2026_11`). `EXPLAIN (ANALYZE, BUFFERS)` verified that an October 2026 audit pruned 7 partitions and scanned only `transactions_p2026_10` (2,185 rows, **50 buffer pages vs 351 pages**—an **85.7% I/O reduction**). Sharded 215 accounts across 4 hash partitions (`accounts_shard_00` to `03`), achieving an even 23.72%–27.44% distribution across nodes.
  2. *Replication & Read-Write Splitting:* Configured logical replication publication `finpay_ledger_pub` and built `fn_route_finpay_query` to route writes/locks to `finpay-pg-primary-01` (Lagos Local Zone), post-transfer `Read-Your-Writes` queries to synchronous standby `finpay-pg-standby-02` (`1.45 ms` lag), and analytical queries to `finpay-pg-replica-03` (Abuja, `14.80 ms` lag).
  3. *CAP/PACELC & Disaster Recovery:* Demonstrated per-transaction `synchronous_commit` tuning (`on` for CP/PC-EC ledger transfers vs `off` for AP/PA-EL telemetry), verified webhook deduplication via `distributed_idempotency_registry`, and simulated automated Patroni standby promotion achieving **$\text{RPO} = 0\text{ ms}$** and **$\text{RTO} = 18.40\text{ s}$**.

---

## 3. Individual Technical Reflection

### 3.1 Key Architectural Decisions & Trade-Offs
1. **Pessimistic Row Locks under `READ COMMITTED` vs `SERIALIZABLE`:** In Portfolio 3, I evaluated using `SERIALIZABLE` isolation globally. However, under high payment contention, Serializable Snapshot Isolation (SSI) triggers frequent `40001` serialization aborts requiring application retry loops. Using `READ COMMITTED` with deterministic NUBAN-ordered `SELECT ... FOR UPDATE` locks guaranteed zero lost updates and zero deadlocks without retry overhead.
2. **Polyglot Persistence Boundaries:** In Portfolio 4, I avoided embedding transaction arrays inside MongoDB customer documents because active accounts generate thousands of rows, which would breach MongoDB's 16MB BSON limit and cause write fragmentation. Keeping bounded financial ledgers in PostgreSQL (partitioned by month in Portfolio 5) and time-expiring telemetry in MongoDB leveraged the strengths of both engines.

### 3.2 Practical Challenges Encountered & Debugged
- **Duplicate BVN Hash Collision (Portfolio 1):** Initial Docker seeding failed with `ERROR: duplicate key value violates unique constraint "customers_bvn_hash_key"` because Customers 3 and 12 shared an identical SHA-256 string. I replaced Customer 12's hash and re-verified initialization.
- **`lpad()` Type Signature Error (Portfolio 2):** Generating synthetic 10-digit NUBANs in PL/pgSQL failed with `function lpad(bigint, integer, unknown) does not exist`. Casting `::bigint::text` resolved the type mismatch.
- **GeoJSON Coordinate Order (Portfolio 4):** MongoDB's `2dsphere` index initially rejected seed documents because coordinates were entered as `[latitude, longitude]` instead of RFC 7946 `[longitude, latitude]`. Inverting the array order fixed the spatial index build.
- **Partitioned Primary Key & Catalog Alias Scope (Portfolio 5):** PostgreSQL rejected `PRIMARY KEY (transaction_id)` on `transactions_partitioned` until the partition key `created_at` was included (`PRIMARY KEY (transaction_id, created_at)`). I also fixed an `ORDER BY alias::text` scoping error on `pg_inherits` by ordering on `c.relname`.

---

## 4. Academic Integrity, References & AI Use Declaration

### 4.1 AI Use Declaration (Section 11 Compliance)
1. **AI Tool Used:** Claude / AI Programming Assistant.
2. **What the AI Tool Was Used For:** Reviewing PostgreSQL 16 PL/pgSQL syntax edge cases (`lpad` casting, `SELECT ... FOR UPDATE` variable targets, partitioned composite keys), checking MongoDB `$jsonSchema` syntax, and formatting raw `EXPLAIN ANALYZE` outputs into Markdown tables.
3. **How Output Was Reviewed, Corrected, Tested, and Verified:** I conceived the FinPay case study, Nigerian regulatory rules (CBN KYC tiers, NUBAN format, NIBSS NIP sessions, `FROZEN_PND` triggers), and all 5 portfolio architectures. I executed every SQL and MongoDB script against live Docker containers, debugged all runtime errors encountered during testing, and captured the terminal logs in each portfolio's `evidence/` directory.

### 4.2 References
1. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019). *Database System Concepts* (7th ed.). McGraw-Hill.
2. Kleppmann, M. (2017). *Designing Data-Intensive Applications*. O'Reilly Media.
3. PostgreSQL Global Development Group. (2026). *PostgreSQL 16 Official Documentation*. https://www.postgresql.org/docs/16/
4. MongoDB, Inc. (2026). *MongoDB v7.0 Manual*. https://www.mongodb.com/docs/v7.0/
5. Abadi, D. J. (2012). Consistency Tradeoffs in Modern Distributed Database System Design. *IEEE Computer*, 45(2), 37–42.

# Advanced Database Systems Portfolio: FinPay
**Course Code:** MIT 8103 – Advanced Database Systems  
**Programme:** Master of Information Technology (SPGS), MIVA Open University  
**Academic Session:** 2026/2027 – First Semester Continuous Assessment  
**Author:** Folajimi  
**Repository:** [https://github.com/Folexy13/advanced-database-portfolio](https://github.com/Folexy13/advanced-database-portfolio)  

---

## 1. Executive Summary & Case Study Overview

**FinPay Technologies Limited** is a digital banking and payment service provider operating within the Nigerian financial technology ecosystem (modelled on high-throughput platforms such as OPay, Moniepoint, and PalmPay). FinPay provides retail and commercial digital wallet services, peer-to-peer (P2P) transfers, inter-bank NIP (NIBSS Instant Payment) settlements, bill payments, and merchant acquiring.

Per **Section 2 of the Assessment Guidelines**, the FinPay case study is used consistently across all five portfolio milestones:
- **Nature of the Business / System:** Core double-entry financial ledger, inter-bank payment switch, tiered KYC compliance engine, and real-time fraud surveillance platform.
- **Database Users & Actors:** Retail and corporate wallet holders, merchant partners, customer support/dispute operations agents, compliance and risk officers (CBN/NFIU reporting), and automated backend settlement services.
- **Major Data Stored:** Customer master records (with SHA-256 hashed BVN/NIN), 10-digit NUBAN accounts, immutable debit/credit transactions, 30-digit NIBSS NIP transfer metadata, saved beneficiaries, JSONB trigger-driven audit logs, polymorphic MongoDB fraud cases, and mobile device geospatial telemetry.
- **Key Operations Supported:** Tiered KYC validation (Tier 1 to Tier 3), atomic P2P and inter-bank fund transfers, Post-No-Debit (`FROZEN_PND`) compliance enforcement, window-function account statements, real-time velocity fraud detection, and multi-region partitioned query routing.

---

## 2. Portfolio Structure & Repository Map

Following the course syllabus, the repository is organized into five progressive portfolio directories plus comprehensive architectural and LMS submission documentation:

```text
advanced-database-portfolio/
├── docs/
│   ├── finpay-case-study.md                 # Detailed domain, entity dictionary & workflows
│   └── final-ca-submission-documentation.md # 3-page LMS synthesis report, reflection & references
├── portfolio-1-database-design/
│   ├── 01-schema.sql                        # Core DDL, types, constraints, 8 relational tables
│   ├── 02-constraints.sql                   # Integrity rules, checks, triggers & audit tables
│   ├── 03-seed-data.sql                     # Realistic Nigerian fintech baseline dataset
│   ├── 04-verification-tests.sql            # Schema validation & negative integrity assertions
│   ├── er-diagram.mermaid                   # Entity-Relationship diagram source
│   ├── er-diagram.png                       # Visual ER diagram export (raster)
│   ├── er-diagram.svg                       # Visual ER diagram export (vector)
│   ├── evidence/
│   │   └── verification-test-output.log     # Captured psql verification output
│   └── README.md                            # Technical report: Normalisation (UNF to BCNF)
├── portfolio-2-query-optimisation/
│   ├── 01-data-generator.sql                # Procedural generator (15,008 txns, 215 accounts)
│   ├── 02-unoptimized-queries.sql           # 5 banking analytical queries with baseline EXPLAIN
│   ├── 03-optimization-indexes.sql          # Partial, composite, and covering (INCLUDE) indexes
│   ├── 04-optimized-queries.sql             # Post-index EXPLAIN (ANALYZE, BUFFERS) execution
│   ├── evidence/
│   │   ├── 01-baseline-explain-plans.log    # Unoptimized execution plans
│   │   └── 02-optimized-explain-plans.log   # Post-index execution plans (up to 16.3x speedup)
│   └── README.md                            # Technical report: Benchmark analysis & planner internals
├── portfolio-3-transactions-concurrency/
│   ├── 01-fund-transfer-procedure.sql       # ACID fund transfer function with deterministic locks
│   ├── 02-commit-rollback-tests.sql         # Positive/negative atomicity & savepoint tests
│   ├── 03-concurrency-control.sql           # Double-spending prevention & OCC verification
│   ├── 04-isolation-levels.sql              # MVCC, non-repeatable reads, snapshot analysis
│   ├── 05-deadlock-handling.sql             # Deadlock simulation & NUBAN lock ordering resolution
│   ├── evidence/
│   │   ├── 01-commit-rollback-output.log    # Atomic commit/rollback & savepoint evidence
│   │   ├── 02-concurrency-control-output.log# Row lock serialization & OCC conflict logs
│   │   ├── 03-isolation-levels-output.log   # Isolation level verification output
│   │   └── 04-deadlock-handling-output.log  # Deterministic lock acquisition evidence
│   └── README.md                            # Technical report: Concurrency, ACID & lock graphs
├── portfolio-4-nosql/
│   ├── 01-mongo-schema.js                   # Collections with $jsonSchema, 2dsphere & TTL indexes
│   ├── 02-mongo-seed.js                     # Telemetry events & polymorphic fraud case documents
│   ├── 03-mongo-queries.js                  # Aggregation pipelines (VPN, velocity, $facet, $unwind)
│   ├── 04-relational-vs-nosql-comparison.md # Architectural trade-off evaluation matrix
│   ├── evidence/
│   │   └── mongo-aggregation-output.log     # Captured mongosh pipeline execution output
│   └── README.md                            # Technical report: Polyglot persistence & document models
├── portfolio-5-distributed-cloud/
│   ├── 01-table-partitioning-sharding.sql   # Monthly Range Partitioning & 4-way Hash Sharding
│   ├── 02-replication-read-write-split.sql  # Logical publication, WAL LSN & Read/Write router
│   ├── 03-distributed-cap-pacelc-verification.sql # Tunable sync commit, idempotency & failover
│   ├── 04-cloud-ha-disaster-recovery.md     # Multi-region AWS Lagos/Abuja/Dublin HA/DR blueprint
│   ├── evidence/
│   │   ├── 01-partition-pruning-output.log  # Partition pruning EXPLAIN (ANALYZE, BUFFERS) output
│   │   ├── 02-replication-routing-output.log# Replication topology & query routing output
│   │   └── 03-distributed-consistency-output.log # PACELC, idempotency & failover promotion logs
│   └── README.md                            # Technical report: Distributed databases & cloud DR
├── docker-compose.yml                       # Reproducible PostgreSQL 16 & MongoDB 7.0 stack
└── README.md                                # Portfolio master guide
```

---

## 3. Core Domain Capabilities & Operations Supported

| Functional Domain | Underlying Database Operations | Key Entities Involved |
| :--- | :--- | :--- |
| **Customer Onboarding & KYC** | Registration, BVN/NIN SHA-256 hashing, CBN Tier validation (Tier 1–3) | `customers`, `kyc_tiers` |
| **Account Management** | 10-digit NUBAN validation, balance non-negativity, PND freeze enforcement | `accounts`, `accounts_sharded` |
| **Fund Transfers (P2P & NIP)** | Atomic double-entry debit/credit, deterministic NUBAN row locking | `transactions`, `transfers` |
| **Beneficiary Directory** | Frequent recipient lookups, composite unique routing validation | `beneficiaries` |
| **Audit Trails & Security** | Trigger-captured JSONB `old_state`/`new_state` snapshots, 90-day TTL logs | `audit_logs`, `device_telemetry` |
| **Fraud & Risk Surveillance** | Impossible-travel GeoJSON checks, VPN/Tor flagging, AML velocity rules | `fraud_alerts`, `fraud_incident_cases` |
| **Distributed Scaling & DR** | Monthly partition pruning, 4-node hash sharding, read-write query routing | `transactions_partitioned`, `distributed_cluster_nodes` |

---

## 4. Assessment Component Breakdown & Summary of Evidence

| Milestone | Component Title | Weight | Status | Key Empirical Deliverable |
| :--- | :--- | :---: | :---: | :--- |
| **Portfolio 1** | [Database Design and Modelling](portfolio-1-database-design/README.md) | 7 Marks | **Completed** | 8 BCNF tables, ER diagram, regex NUBAN/phone checks, JSONB audit trigger, negative constraint suite |
| **Portfolio 2** | [Query Processing and Optimisation](portfolio-2-query-optimisation/README.md) | 7 Marks | **Completed** | Scaled to 15,008 txns; partial & covering indexes reduced Query 2 latency by **93.8% (16.3x speedup)** |
| **Portfolio 3** | [Transactions and Concurrency](portfolio-3-transactions-concurrency/README.md) | 7 Marks | **Completed** | `sp_execute_fund_transfer`, savepoint rollbacks, `SELECT FOR UPDATE` double-spend prevention, deadlock elimination |
| **Portfolio 4** | [NoSQL and Advanced Data Models](portfolio-4-nosql/README.md) | 7 Marks | **Completed** | MongoDB 7.0 `$jsonSchema`, `2dsphere` & 90-day TTL indexes, 4 fraud surveillance aggregation pipelines |
| **Portfolio 5** | [Distributed and Cloud Database Exercise](portfolio-5-distributed-cloud/README.md) | 6 Marks | **Completed** | Monthly range partitioning (**85.7% I/O pruning**), 4-way hash sharding, read/write router, Patroni HA/DR ($\text{RPO}=0$) |
| **Final Documentation** | [Portfolio Documentation & Technical Reflection](docs/final-ca-submission-documentation.md) | 6 Marks | **Completed** | Comprehensive LMS synthesis document, architectural trade-offs, debugging logs & AI declaration |
| **Total** | | **40 Marks** | **100% Complete** | |

---

## 5. Technology Stack & Environment
- **Relational DBMS:** PostgreSQL 16 (`postgres:16-alpine` – strict constraints, PL/pgSQL procedures, declarative partitioning, `EXPLAIN (ANALYZE, BUFFERS)`)
- **NoSQL Document Store:** MongoDB 7.0 (`mongo:7.0` – `$jsonSchema` validation, GeoJSON `2dsphere` spatial indexing, TTL expiration, aggregation pipelines)
- **Modelling & Tooling:** Mermaid.js, `psql`, `mongosh`, Docker Compose v2, Git / GitHub

---

## 6. Quick Start & End-to-End Reproduction (Docker Environment)

The repository provides a self-contained `docker-compose.yml` that provisions PostgreSQL 16 ( automatically initializing Portfolio 1's schema, constraints, and seed dataset on startup) and MongoDB 7.0:

```bash
# 1. Clone repository
git clone https://github.com/Folexy13/advanced-database-portfolio.git
cd advanced-database-portfolio

# 2. Start PostgreSQL 16 and MongoDB 7.0 containers
docker compose up -d

# 3. Portfolio 1: Run relational integrity and constraint verification tests
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-1/04-verification-tests.sql

# 4. Portfolio 2: Generate 15,000+ records, apply optimization indexes, and benchmark queries
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-2/01-data-generator.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-2/03-optimization-indexes.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-2/04-optimized-queries.sql

# 5. Portfolio 3: Compile atomic transfer procedure and run ACID / concurrency / deadlock suite
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-3/01-fund-transfer-procedure.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-3/02-commit-rollback-tests.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-3/03-concurrency-control.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-3/05-deadlock-handling.sql

# 6. Portfolio 4: Provision MongoDB schemas, seed telemetry, and execute fraud aggregation pipelines
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/01-mongo-schema.js
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/02-mongo-seed.js
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/03-mongo-queries.js

# 7. Portfolio 5: Execute partitioning, sharding, read-write routing, and CAP/PACELC failover suite
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-5/01-table-partitioning-sharding.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-5/02-replication-read-write-split.sql
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-5/03-distributed-cap-pacelc-verification.sql
```

### Database Connection Credentials
| Service | Host | Host Port | Container Port | Database | Username | Password |
| :--- | :--- | :---: | :---: | :--- | :--- | :--- |
| **PostgreSQL 16** | `localhost` | `5434` | `5432` | `finpay_db` | `finpay_admin` | `FinPaySecure2026!` |
| **MongoDB 7.0** | `localhost` | `27018` | `27017` | `finpay_nosql` | `finpay_mongo` | `FinPayMongo2026!` |

---

## 7. Academic Integrity, References & AI Use Declaration

*(Submitted in compliance with Sections 11 and 12 of the MIT 8103 Continuous Assessment Guidelines)*

### 7.1 AI Use Declaration
1. **AI Tools Used:** Claude / AI Programming Assistant
2. **What the AI Tool Was Used For:**
   - Reviewing PostgreSQL 16 PL/pgSQL syntax edge cases (such as `lpad()` explicit type casting, `SELECT ... INTO ... FOR UPDATE` cursor assignment, and partitioned composite primary keys).
   - Reviewing MongoDB `$jsonSchema` validation structure and formatting `EXPLAIN (ANALYZE, BUFFERS)` output into Markdown tables.
3. **How Output Was Reviewed, Corrected, Tested, and Verified:**
   - All domain modelling, Nigerian fintech business rules (CBN KYC Tier 1–3 limits, 10-digit NUBAN validation, NIBSS 30-digit NIP session tracking, `FROZEN_PND` account restrictions), and normalization proofs were designed by me.
   - Every SQL and JavaScript script was executed and verified against live PostgreSQL 16 and MongoDB 7.0 Docker containers.
   - I diagnosed and fixed multiple implementation bugs during testing (including duplicate SHA-256 BVN hashes in Portfolio 1, `lpad` type casting in Portfolio 2, PL/pgSQL lock target assignment in Portfolio 3, GeoJSON `[longitude, latitude]` coordinate ordering in Portfolio 4, and catalog alias ordering in Portfolio 5), capturing the real execution output logs in each portfolio's `evidence/` directory.

### 7.2 References & Technical Standards
1. Silberschatz, A., Korth, H. F., & Sudarshan, S. (2019). *Database System Concepts* (7th ed.). McGraw-Hill Education.
2. Kleppmann, M. (2017). *Designing Data-Intensive Applications: The Big Ideas Behind Reliable, Scalable, and Maintainable Systems*. O'Reilly Media.
3. PostgreSQL Global Development Group. (2026). *PostgreSQL 16 Documentation: Concurrency Control, Table Partitioning, and High Availability*. https://www.postgresql.org/docs/16/
4. MongoDB, Inc. (2026). *MongoDB 7.0 Manual: Schema Validation, 2dsphere Indexes, and Aggregation Pipeline*. https://www.mongodb.com/docs/v7.0/
5. Central Bank of Nigeria (CBN). (2023). *Regulatory Framework for Bank Verification Number (BVN) Operations and Three-Tiered Know-Your-Customer (KYC) Guidelines*.
6. Abadi, D. J. (2012). Consistency Tradeoffs in Modern Distributed Database System Design: CAP is Only Part of the Story. *IEEE Computer*, 45(2), 37–42.

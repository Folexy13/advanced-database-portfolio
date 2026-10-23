# Advanced Database Systems Portfolio: FinPay
**Course Code:** MIT 8103 – Advanced Database Systems  
**Programme:** Master of Information Technology (SPGS), MIVA Open University  
**Academic Session:** 2026/2027 – First Semester Continuous Assessment  
**Author:** Folajimi  
**Repository:** [https://github.com/Folexy13/advanced-database-portfolio](https://github.com/Folexy13/advanced-database-portfolio)  

---

## Executive Summary & Case Study Overview

**FinPay Technologies Ltd** is a digital banking and payment service provider operating within the Nigerian financial technology ecosystem. FinPay provides retail and commercial digital wallet services, peer-to-peer (P2P) transfers, inter-bank NIP (NIBSS Instant Payment) settlements, bill payments, and merchant acquiring.

This portfolio serves as a practical, production-grade database systems engineering project developed progressively throughout the semester. It demonstrates end-to-end competencies across database architecture, relational schema normalization, advanced SQL querying and execution plan optimization, ACID transaction control under concurrent execution, polyglot persistence utilizing NoSQL, and scalable distributed cloud architectures.

---

## Portfolio Structure & Roadmap

Following the assessment syllabus and guidelines, the repository is structured into modular portfolio milestones that evolve progressively:

```text
advanced-database-portfolio/
├── docs/
│   ├── finpay-case-study.md               # Detailed domain, entity dictionary & workflows
│   └── architecture-overview.md           # Systems and data flow architecture
├── portfolio-1-database-design/
│   ├── 01-schema.sql                      # Core DDL, types, constraints, relational tables
│   ├── 02-constraints.sql                 # Integrity rules, checks, triggers & audit tables
│   ├── 03-seed-data.sql                   # Realistic Nigerian fintech baseline dataset
│   ├── 04-verification-tests.sql          # Schema validation & integrity assertions
│   ├── er-diagram.mermaid                 # Entity-Relationship diagram source
│   ├── er-diagram.png                     # Visual ER diagram export (raster)
│   ├── er-diagram.svg                     # Visual ER diagram export (vector)
│   └── README.md                          # Technical report: Normalisation (3NF/BCNF) & design decisions
├── portfolio-2-query-optimisation/
│   ├── 01-data-generator.sql              # Procedural generator (15,000+ txns, 100+ customers)
│   ├── 02-unoptimized-queries.sql         # 5 banking analytical queries with baseline EXPLAIN plans
│   ├── 03-optimization-indexes.sql        # Partial, composite, and covering indexes
│   ├── 04-optimized-queries.sql           # Post-index EXPLAIN (ANALYZE, BUFFERS) execution
│   └── README.md                          # Technical report: Benchmark analysis & optimizer internals
├── portfolio-3-transactions-concurrency/  # [Upcoming] ACID guarantees, deadlocks & isolation levels
├── portfolio-4-nosql/                     # [Upcoming] Polyglot model (MongoDB/Redis) for event audit & logs
├── portfolio-5-distributed-cloud/         # [Upcoming] Replication, sharding & cloud DR architecture
└── README.md                              # Portfolio master guide
```

---

## Core Domain Capabilities & Operations Supported

| Functional Domain | Underlying Database Operations | Key Entities Involved |
| :--- | :--- | :--- |
| **Customer Onboarding & KYC** | Registration, BVN/NIN hashing, Tier validation (Tier 1 to Tier 3) | `customers`, `kyc_verifications` |
| **Account Management** | NUBAN generation, multi-currency ledger allocation, status freeze | `accounts`, `account_limits` |
| **Fund Transfers (P2P & NIP)** | Double-entry ledger updates, intra-bank credit/debit, balance checks | `transfers`, `transactions` |
| **Beneficiary Directory** | Frequent recipient lookups, routing validation | `beneficiaries` |
| **Audit Trails & Security** | Immutable ledger logs, state changes, IP/device capture | `audit_logs`, `session_history` |
| **Fraud & Risk Rules** | Velocity checks, suspicious transfer alerts, risk scoring | `fraud_alerts`, `risk_profiles` |

---

## Assessment Component Breakdown

| Milestone | Component Title | Weight | Status |
| :--- | :--- | :---: | :---: |
| **Portfolio 1** | Database Design and Modelling | 7 Marks | **Completed** |
| **Portfolio 2** | Query Processing and Optimisation | 7 Marks | **Completed** |
| **Portfolio 3** | Transactions and Concurrency | 7 Marks | Scheduled |
| **Portfolio 4** | NoSQL and Advanced Data Models | 7 Marks | Scheduled |
| **Portfolio 5** | Distributed and Cloud Database Exercise | 6 Marks | Scheduled |
| **Final Documentation** | Portfolio Documentation & Technical Reflection | 6 Marks | Scheduled |
| **Total** | | **40 Marks** | |

---

## Technology Stack & Environment
- **Relational DBMS:** PostgreSQL 16 (strict constraint enforcement, JSONB audit capability, CTEs, and execution plan tooling)
- **Document & Cache Stores:** MongoDB 7.0 / Redis 7.2 (telemetry, audit logs, and session locks)
- **Modelling & Tooling:** Mermaid.js, DBeaver, `psql`, Git / GitHub
- **Containerization:** Docker Compose v2+

---

## Quick Start (Docker Environment)

The repository provides a complete `docker-compose.yml` to instantly provision and seed the database environment without manual configuration:

```bash
# 1. Clone repository
git clone https://github.com/Folexy13/advanced-database-portfolio.git
cd advanced-database-portfolio

# 2. Start PostgreSQL service (runs on port 5434)
docker compose up -d finpay-postgres

# 3. Run Portfolio 1 verification test suite
docker compose exec finpay-postgres psql -U finpay_admin -d finpay_db -f /portfolio-1/04-verification-tests.sql

# 4. Connect to interactive psql session
docker compose exec -it finpay-postgres psql -U finpay_admin -d finpay_db
```

### Connection Credentials
| Service | Host | Port | Database | User | Password |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL** | `localhost` | `5434` | `finpay_db` | `finpay_admin` | `FinPaySecure2026!` |
| **MongoDB** | `localhost` | `27017` | `finpay_nosql` | `finpay_mongo` | `FinPayMongo2026!` |

---

## License & Academic Integrity
This repository is authored as an individual practical continuous assessment for MIVA Open University. All architectural designs, scripts, and analyses are strictly documented with reproducible technical evidence.

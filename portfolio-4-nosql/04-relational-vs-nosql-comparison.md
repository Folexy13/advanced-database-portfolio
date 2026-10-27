# Relational (PostgreSQL) vs Document (MongoDB) Architecture Matrix

**Case Study:** FinPay Technologies Limited  
**Author:** Folajimi  
**Context:** MIT 8103 Advanced Database Systems – Portfolio 4  

---

## 1. Architectural Comparison Matrix

| Architectural Dimension | Relational Store: PostgreSQL 16 | Document Store: MongoDB 7.0 |
| :--- | :--- | :--- |
| **Primary Domain in FinPay** | Core Financial Ledger (Accounts, Transactions, Transfers, KYC limits) | Telemetry, Device Security, Clickstream Audit, Fraud Investigation Cases |
| **Data Model Paradigm** | Tabular, strictly typed, normalized to Boyce-Codd Normal Form (BCNF) | Hierarchical, semi-structured BSON documents with JSON Schema validation |
| **Integrity & Constraints** | Foreign Keys (`ON DELETE RESTRICT`), CHECK constraints, regex NUBAN formatting | JSON Schema `$jsonSchema` document validators, application-enforced rules |
| **Consistency Guarantees** | Immediate consistency; full ACID compliance under pessimistic row locks | Tunable consistency (WiredTiger journaled writes; causal consistency) |
| **CAP Theorem Positioning** | **CP System:** Prioritizes strict Consistency over Partition tolerance | **CP/AP Configurable:** Configurable read/write concerns (`w: "majority"`, `readPreference: "secondary"`) |
| **Transaction Boundaries** | Multi-table atomic transactions with stored procedures (`BEGIN ... COMMIT`) | Multi-document transactions supported, but optimized for single-document atomicity |
| **Schema Evolution** | Structured DDL migrations (`ALTER TABLE`); schema changes require locks | Dynamic / Polymorphic: allows adding nested device fields without database locks |
| **Query Engine** | Declarative SQL, Window Functions (`SUM() OVER`), CTEs, Recursive queries | Aggregation Pipeline framework (`$match`, `$group`, `$unwind`, `$facet`), MapReduce |
| **Storage Optimization** | B-Tree indexes, partial indexes, and covering indexes with `INCLUDE` | B-Tree compound indexes, 2dsphere geospatial indexes, TTL auto-expiring indexes |
| **Write Throughput** | Bounded by WAL write latency, synchronous commit, and index updates | High write throughput via in-memory lock-free concurrency and append-friendly writes |
| **Lifecycle Management** | Indefinite archival required by statutory financial regulations (CBN/NDIC) | Automatic lifecycle cleanup using Time-To-Live (TTL) indexes (90-day retention) |

---

## 2. In-Depth Trade-Off Analysis for FinPay

### 2.1 Why Not Put Everything in MongoDB?
A common anti-pattern in modern development is attempting to store financial balances directly in document collections. In a core banking system, this introduces unacceptable operational risks:
1. **Lack of Declarative Relational Invariants:** PostgreSQL enforces `available_balance >= 0` and foreign key referential integrity at the database storage engine layer. Even if an application bug attempts to write an overdraft or delete a referenced customer, the database rejects the write. In MongoDB, referential integrity across collections must be maintained manually in application code.
2. **Double-Entry Reconciliation Complexity:** Financial transfers require simultaneous debits and credits across two independent entities. While MongoDB supports multi-document transactions, its execution overhead is significantly higher than relational row locks, and it lacks the native double-entry ledger tooling mature in relational engines.

### 2.2 Why Not Put Everything in PostgreSQL?
Attempting to force high-frequency device telemetry and fraud investigation notes into PostgreSQL creates distinct bottlenecks:
1. **Table Bloat & Write Amplification:** A mobile app user triggers 10–50 telemetry events per session (biometrics, screen taps, battery level, cellular carrier changes). Inserting millions of these rows into PostgreSQL rapidly bloats the relational heap and causes write contention on core ledger tables.
2. **Schema Rigidity on Polymorphic Incident Data:** Fraud cases are polymorphic: a card-skimming case has chip/PIN metadata, a SIM-swap case has telco porting logs, and an account-takeover case has Tor/VPN IP traces. In PostgreSQL, this requires either sparse tables with dozens of NULL columns or complex Entity-Attribute-Value (EAV) anti-patterns. In MongoDB, each case is naturally stored as a rich, self-contained document.
3. **Data Lifecycle (TTL Expiration):** Under the Nigerian Data Protection Regulation (NDPR), raw location and device telemetry should be pruned after 90 days. In PostgreSQL, bulk `DELETE` operations generate vacuum overhead and table bloat. MongoDB handles this natively and asynchronously at the storage layer via TTL indexes (`expireAfterSeconds: 7776000`).

---

## 3. Polyglot Persistence Architecture in FinPay

By pairing PostgreSQL 16 and MongoDB 7.0, FinPay adopts a **Polyglot Persistence** architecture:
- **System of Record (PostgreSQL):** Owns the single source of financial truth. Handles customer identities, NUBAN accounts, balance adjustments, and NIP clearinghouse settlements.
- **System of Engagement & Telemetry (MongoDB):** Owns the high-throughput security context. Ingests device fingerprints, powers real-time fraud scoring pipelines, and provides flexible case files for compliance officers.
- **Integration Bridge:** Collections in MongoDB reference customer and account records using standard UUID strings (`customer_id`, `account_id`), allowing fraud surveillance engines to join risk signals with core balances seamlessly.

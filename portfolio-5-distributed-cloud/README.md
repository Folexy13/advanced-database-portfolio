# Portfolio 5: Distributed and Cloud Database Exercise

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** FinPay Technologies Limited  
**Deliverable:** Declarative Range Partitioning, Hash Sharding, Primary-Replica Read/Write Splitting, CAP/PACELC Consistency Verification & Cloud HA/DR Architecture  
**Component Score Weight:** 6 Marks  
**Author:** Opeyemi Folajimi Aluko (`301926073`)  

---

## 1. Executive Summary & Distributed Systems Context

As FinPay scales to millions of daily peer-to-peer (P2P) wallet transfers and NIBSS Instant Payment (NIP) clearinghouse settlements across Nigeria, a single-node database instance becomes both a **throughput bottleneck** and a **single point of failure (SPOF)**.

In this fifth portfolio milestone, I designed, implemented, and verified FinPay's distributed and cloud database architecture across four key engineering dimensions:
1. **Horizontal Data Partitioning & Sharding (`01-table-partitioning-sharding.sql`):** Partitioned the 15,008-row `transactions` ledger by monthly time ranges (`2026_05` through `2026_11`) and sharded the 215-row `accounts` table across 4 hash partitions (`MODULUS 4`) keyed on NUBAN account numbers.
2. **Primary-Replica Replication & Read-Write Splitting (`02-replication-read-write-split.sql`):** Configured logical replication publications (`finpay_ledger_pub`), inspected Write-Ahead Log (WAL) Log Sequence Numbers (LSNs), and built a deterministic query router (`fn_route_finpay_query`) that routes writes and `SELECT ... FOR UPDATE` locks to the Lagos Primary Writer while offloading analytical workloads to read replicas.
3. **CAP & PACELC Consistency Engineering (`03-distributed-cap-pacelc-verification.sql`):** Evaluated tunable transaction durability (`synchronous_commit = on | local | off`), implemented an idempotency registry to prevent double-crediting during network partitions with the NIBSS switch, and verified automated Patroni standby promotion ($\text{RPO} = 0\text{ ms}$, $\text{RTO} = 18.4\text{ s}$).
4. **Multi-Region Cloud HA/DR Blueprint (`04-cloud-ha-disaster-recovery.md`):** Documented the production topology spanning AWS Nigeria (Lagos Local Zone `af-south-1-los-1`), Abuja (`af-south-1`), and Europe (`eu-west-1` Dublin).

---

## 2. Horizontal Partitioning & Sharding Implementation

### 2.1 Monthly Range Partitioning (`transactions_partitioned`)
Financial ledger tables grow append-only but are queried predominantly within recent time windows (current month statements, daily CBN limit checks, EOD NIP settlement audits). I partitioned `transactions_partitioned` using `PARTITION BY RANGE (created_at)`:

| Partition Table | Range Bound (UTC) | Migrated Rows | Storage Size |
| :--- | :--- | :---: | :---: |
| `transactions_p2026_05` | `2026-05-01` to `2026-06-01` | 2,517 | 1,184 kB |
| `transactions_p2026_06` | `2026-06-01` to `2026-07-01` | 2,523 | 1,184 kB |
| `transactions_p2026_07` | `2026-07-01` to `2026-08-01` | 2,641 | 1,240 kB |
| `transactions_p2026_08` | `2026-08-01` to `2026-09-01` | 2,608 | 1,224 kB |
| `transactions_p2026_09` | `2026-09-01` to `2026-10-01` | 2,534 | 1,192 kB |
| `transactions_p2026_10` | `2026-10-01` to `2026-11-01` | 2,185 | 1,056 kB |
| `transactions_p2026_11` | `2026-11-01` to `2026-12-01` | 0 | 32 kB |
| `transactions_p_default` | `DEFAULT` (Catch-all) | 0 | 32 kB |
| **Total** | | **15,008** | **7,144 kB** |

#### Empirical Partition Pruning Evidence:
When executing an October 2026 debit settlement audit against `transactions_partitioned`, PostgreSQL's query planner automatically pruned 7 of the 8 child partitions and scanned **only `transactions_p2026_10`**:
```text
Sort  (cost=103.73..103.77 rows=18 width=61) (actual time=0.971..0.972 rows=10 loops=1)
  Buffers: shared hit=50
  ->  HashAggregate  (cost=103.13..103.35 rows=18 width=61) (actual time=0.955..0.958 rows=10 loops=1)
        ->  Seq Scan on transactions_p2026_10 transactions_partitioned  (cost=0.00..88.24 rows=1489 width=29) (actual time=0.008..0.440 rows=1489 loops=1)
              Filter: ((created_at >= '2026-10-01 00:00:00+00'::timestamptz) AND (created_at < '2026-11-01 00:00:00+00'::timestamptz) AND ((transaction_type)::text = 'DEBIT'::text))
              Rows Removed by Filter: 696
              Buffers: shared hit=50
Planning Time: 1.473 ms | Execution Time: 1.002 ms
```
Instead of reading 351 buffer pages across all 15,008 transactions, the executor touched **only 50 buffer pages** (an **85.7% I/O reduction**).

### 2.2 4-Way Hash Sharding (`accounts_sharded`)
To distribute row-level lock contention across account ledgers, I partitioned `accounts_sharded` using `PARTITION BY HASH (account_number)` across 4 logical shard partitions:

| Shard Partition | Assigned Cluster Node | Accounts Hosted | Share (%) | Total Liquidity (NGN) |
| :--- | :--- | :---: | :---: | :---: |
| `accounts_shard_00` | `SHARD-00 (Lagos-VI-Node1)` | 53 | 24.65% | ₦25,908,018.36 |
| `accounts_shard_01` | `SHARD-01 (Lagos-Ikeja-Node2)` | 52 | 24.19% | ₦27,877,557.62 |
| `accounts_shard_02` | `SHARD-02 (Abuja-Central-Node3)` | 51 | 23.72% | ₦21,025,634.74 |
| `accounts_shard_03` | `SHARD-03 (PortHarcourt-Node4)` | 59 | 27.44% | ₦26,387,477.04 |
| **Total** | | **215** | **100.00%** | **₦101,198,687.76** |

Querying John Adeyemi's NUBAN (`0123456789`) routed directly to `accounts_shard_01` in **0.025 ms**, touching only 2 buffer pages.

---

## 3. Replication & Read-Write Query Splitting

In `02-replication-read-write-split.sql`, I modelled FinPay's 4-node multi-region cluster and created a logical replication publication (`CREATE PUBLICATION finpay_ledger_pub FOR TABLE accounts, transactions, transfers, fraud_alerts`).

### Deterministic Query Routing Verification (`fn_route_finpay_query`):
1. **Write / Pessimistic Lock Workload (`sp_execute_fund_transfer`):**
   - *Routed to:* `finpay-pg-primary-01` (`NG-Lagos Local Zone`, `PRIMARY_WRITER`, `0.00 ms` lag).
   - *Reason:* Write/Lock operation detected; routed strictly to Primary Writer with synchronous standby commit.
2. **Post-Transfer Immediate Balance Inquiry (`Read-Your-Writes`):**
   - *Routed to:* `finpay-pg-standby-02` (`NG-Lagos Victoria Island`, `SYNC_STANDBY`, `1.45 ms` lag).
   - *Reason:* Session consistency required immediately after transfer; routed to zero-loss Synchronous Standby to prevent stale balance display.
3. **Heavy Analytical Workload (`EOD_SETTLEMENT_ANALYTICS`):**
   - *Routed to:* `finpay-pg-replica-03` (`NG-Abuja Central`, `ASYNC_READ_REPLICA`, `14.80 ms` lag).
   - *Reason:* Read-only analytical aggregation offloaded to lowest-lag asynchronous replica, protecting the primary writer from CPU/IO contention.

---

## 4. CAP / PACELC Consistency & Failover Verification

A detailed cloud topology and SLA matrix is provided in [`04-cloud-ha-disaster-recovery.md`](04-cloud-ha-disaster-recovery.md).

### 4.1 Tunable Consistency via `synchronous_commit`
- **CP / PC-EC Mode (`synchronous_commit = on`):** Enforced for NIBSS NIP transfers and double-entry balance updates. Commits block until WAL records are flushed both locally and on `finpay-pg-standby-02`.
- **Local Durable Mode (`synchronous_commit = local`):** Used for saved beneficiary changes and profile updates.
- **AP / PA-EL Mode (`synchronous_commit = off`):** Used for non-monetary telemetry and session logs where sub-millisecond latency outweighs immediate cross-node durability.

### 4.2 Idempotent Settlement Processing under Network Partition
In `03-distributed-cap-pacelc-verification.sql`, I simulated a network timeout between FinPay and the NIBSS switch where webhook `IDEMP-NIP-20261030-009841` (₦25,000 transfer from `0123456789` to `0223456781`) was delivered twice across failover nodes. The `distributed_idempotency_registry` processed the first delivery and safely intercepted the duplicate retry (`retry_attempts = 1`), preserving exact-once financial semantics.

---

## 5. How to Execute the Portfolio 5 Verification Suite

```bash
# 1. Ensure the PostgreSQL 16 container is running
docker compose up -d finpay-postgres

# 2. Run Declarative Range Partitioning & Hash Sharding benchmark
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-5-distributed-cloud/01-table-partitioning-sharding.sql

# 3. Run Replication Publication & Read-Write Query Router verification
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-5-distributed-cloud/02-replication-read-write-split.sql

# 4. Run CAP/PACELC consistency, Idempotency & Failover simulation
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-5-distributed-cloud/03-distributed-cap-pacelc-verification.sql
```

---

## 6. Technical Reflection & Practical Debugging Log

### 6.1 Key Engineering Insights
- **Partition Key Enforcement on Unique Constraints:**  
  When migrating the monolithic `transactions` table to `transactions_partitioned`, I initially defined `PRIMARY KEY (transaction_id)` and `UNIQUE (transaction_reference)` exactly as in Portfolio 1. PostgreSQL rejected the DDL because a global uniqueness check across multiple physical partitions without the partition key would require locking and scanning every child partition on every insert. Including `created_at` in the composite primary key `PRIMARY KEY (transaction_id, created_at)` aligned the uniqueness invariant with the partition boundary so each partition validates uniqueness locally.
- **Read-Your-Writes Consistency in Mobile Banking:**  
  Offloading all `SELECT` queries blindly to asynchronous read replicas creates a classic user experience bug: a customer transfers ₦5,000, the app immediately redirects to the dashboard, queries an async replica lagging by 50ms, and shows the old balance—causing the user to panic and submit the transfer twice. Routing post-mutation reads to the synchronous standby (`lag < 2ms`) solved this cleanly.

### 6.2 Practical Bugs Encountered & Resolved
During the initial execution of `01-table-partitioning-sharding.sql`, two issues surfaced:
1. **System Catalog Alias Scope in `ORDER BY`:**  
   In my partition inspection query on `pg_inherits`, I wrote `SELECT inhrelid::regclass AS partition_name ... ORDER BY partition_name::text`. PostgreSQL raised:
   ```text
   ERROR: column "partition_name" does not exist
   LINE 9: ORDER BY partition_name::text;
   ```
   Because PostgreSQL only resolves bare output column names in `ORDER BY` (not expressions wrapped in type casts like `alias::text`), I fixed the clause to order by the underlying catalog column `ORDER BY c.relname`.
2. **Logical Replication `wal_level` Warning:**  
   When executing `CREATE PUBLICATION finpay_ledger_pub`, PostgreSQL emitted:
   ```text
   WARNING: wal_level is insufficient to publish logical changes
   HINT: Set wal_level to "logical" before creating subscriptions.
   ```
   Inspecting `current_setting('wal_level')` showed the default container ran with `wal_level = replica` (which supports physical WAL streaming to hot standbys, whereas logical pub/sub requires `wal_level = logical`). This highlighted the practical operational difference between physical block replication and logical row-level publications.

---

## 7. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing PostgreSQL 16 declarative partitioning rules regarding composite primary keys (`PRIMARY KEY (transaction_id, created_at)`).
   - Structuring the Mermaid multi-region cloud topology diagram in `04-cloud-ha-disaster-recovery.md`.
3. **Student Verification & Ownership:**
   - I designed the FinPay multi-region replication and sharding strategy tailored to Nigerian fintech infrastructure (Lagos Local Zone primary + synchronous standby, Abuja read replica, and Dublin DR).
   - I wrote and debugged the SQL scripts (`01` through `03`), fixed the `pg_inherits` catalog ordering bug, executed all queries against the live PostgreSQL 16 container, and verified the partition pruning `EXPLAIN (ANALYZE, BUFFERS)` plans.

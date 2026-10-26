# Portfolio 3: Transactions and Concurrency

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** FinPay Technologies Limited  
**Deliverable:** ACID Guarantees, Stored Procedures, Concurrency Control, Isolation Levels, and Deadlock Resolution  
**Component Score Weight:** 7 Marks  
**Author:** Folajimi  

---

## 1. Executive Summary & Core Banking Context

In financial database systems, correctness and consistency take precedence over all other engineering metrics. A lost update, a dirty read, or a double-spend anomaly directly translates into financial loss and regulatory non-compliance.

In this third portfolio milestone, I implemented and evaluated FinPay's core transaction processing engine. I developed an ACID-compliant stored procedure (`sp_execute_fund_transfer`), verified atomic commits and rollbacks under failure scenarios, demonstrated race-condition mitigation using pessimistic row-level locks (`SELECT ... FOR UPDATE`), evaluated PostgreSQL's MVCC isolation levels, and implemented deterministic resource ordering to mathematically eliminate circular deadlocks.

---

## 2. ACID Implementation Architecture in FinPay

| Property | FinPay Implementation Mechanism | Practical Verification |
| :--- | :--- | :--- |
| **Atomicity** | PL/pgSQL transaction block with explicit exception rollback; sub-transactions via nested `BEGIN ... EXCEPTION` savepoints. | Verified in `02-commit-rollback-tests.sql`: Incomplete transfers rollback 100% of debit and credit mutations. |
| **Consistency** | Database-level invariants: `chk_available_balance_non_negative`, operational status check (`ACTIVE`), and CBN KYC tier ceilings. | Verified in `02-commit-rollback-tests.sql`: Overdraft attempts and transfers from `FROZEN_PND` accounts are rejected. |
| **Isolation** | PostgreSQL Multi-Version Concurrency Control (MVCC) combined with pessimistic row-level locks (`FOR UPDATE`). | Verified in `03-concurrency-control.sql`: Concurrent double-spend attempts are serialized, preventing over-debits. |
| **Durability** | PostgreSQL Write-Ahead Logging (WAL) with fsync flushing to disk before client acknowledgment. | State transitions survive container restarts; immutable audit logs captured on every balance mutation. |

---

## 3. Atomic Stored Procedure: `sp_execute_fund_transfer`

The stored procedure (`01-fund-transfer-procedure.sql`) encapsulates all business rules required for atomic intra-bank and inter-bank transfers:

```text
sp_execute_fund_transfer(
    source_account, destination_account, destination_bank_code,
    destination_bank_name, destination_account_name, amount, narration, channel
)
```

### Execution Flow & Key Invariants:
1. **Input Validation:** Rejects non-positive transfer amounts and identical self-transfers.
2. **Deterministic Locking Order:** Enforces ascending NUBAN order when locking multiple accounts, preventing circular deadlocks.
3. **Operational Status Guard:** Confirms source account is `ACTIVE` (blocking `FROZEN_PND`, `DORMANT`, or `CLOSED` accounts).
4. **Sufficient Balance Check:** Verifies `available_balance >= amount + fee`.
5. **CBN Tier Limit Compliance:** Calculates cumulative debits for the current calendar day plus the requested amount against the customer's KYC ceiling.
6. **Atomic Ledger Posting:** Atomically debits source account, credits destination account (if internal), records matching debit/credit entries in `transactions`, and generates settlement tracking records in `transfers`.

---

## 4. Empirical Verification & Test Evidence

### 4.1 Test 1: Successful Atomic Transfer (COMMIT)
- **Scenario:** John Adeyemi (`0123456789`) sends ₦5,000 to Sarah Okafor (`0223456781`).
- **Result:**
  - John's balance mutated from ₦125,000 $\to$ ₦120,000.
  - Sarah's balance mutated from ₦110,000 $\to$ ₦115,000.
  - Generated matching debit (`FP-TRF-...`) and credit (`FP-CRD-...`) entries with zero discrepancy.

### 4.2 Test 2: Insufficient Funds (Automatic ROLLBACK)
- **Scenario:** Ibrahim Danjuma (`0723456786`, balance ₦8,500) attempts to transfer ₦50,000.
- **Output:**
  ```text
  NOTICE: TRANSACTION ABORTED & ROLLED BACK AS EXPECTED: 
          Transfer rejected: Insufficient funds. Available: 8500.0000 NGN, Required: 50000.0000 NGN.
  ```
- **Post-Test Verification:** Ibrahim's balance remained exactly ₦8,500.0000.

### 4.3 Test 3: Restricted Account (FROZEN_PND ROLLBACK)
- **Scenario:** Olumide Fashola (`0124456789`) attempts transfer from a Post-No-Debit restricted account.
- **Output:**
  ```text
  NOTICE: TRANSACTION ABORTED & ROLLED BACK AS EXPECTED: 
          Transfer rejected: Source account 0124456789 is in FROZEN_PND status (Debits restricted).
  ```

### 4.4 Test 4: Nested Sub-Transaction & Savepoint Rollback
- **Scenario:** Sub-operation 1 transfers ₦1,000 successfully; Sub-operation 2 intentionally triggers a division-by-zero error simulating a gateway crash.
- **Output:**
  ```text
  NOTICE: Sub-operation 1 completed successfully.
  NOTICE: Sub-operation 2 failed (division_by_zero)! Sub-transaction rolled back cleanly to savepoint.
  NOTICE: Outer transaction finished. Leg 1 transfer preserved.
  ```

---

## 5. Concurrency Control: Race Conditions & Deadlock Prevention

### 5.1 The Double-Spending Anomaly
In `03-concurrency-control.sql`, I demonstrated a multi-channel race condition where David Bello (balance ₦230,000) simultaneously issues two large transfers:
- Transfer 1: ₦150,000 via Mobile App
- Transfer 2: ₦100,000 via POS Terminal
- Cumulative Requested: ₦250,000 (Exceeds available balance by ₦20,000).

Without concurrency control, both transactions would read ₦230,000, pass balance validation, and over-debit the account.

**Pessimistic Locking Resolution (`SELECT ... FOR UPDATE`):**
- Transfer 1 acquires an exclusive row-level lock on David's account row.
- Transfer 2 is suspended in PostgreSQL's lock wait queue.
- Transfer 1 completes and commits, reducing balance to ₦80,000.
- Transfer 2 unblocks, re-reads the balance under lock, evaluates `80,000 < 100,000`, and raises an exception:
  ```text
  NOTICE: Transfer 1 Result: SUCCESS (New Balance: 80000.0000 NGN)
  NOTICE: SUCCESS: Transfer 2 rejected due to locked serialized re-check: 
          Transfer rejected: Insufficient funds. Available: 80000.0000 NGN, Required: 100000.0000 NGN.
  ```

### 5.2 Deadlock Prevention via Global Lock Ordering
A classic deadlock occurs in bilateral transfers:
- Transaction 1: Transfers from Account A $\to$ Account B (holds Lock A, waits on Lock B).
- Transaction 2: Transfers from Account B $\to$ Account A (holds Lock B, waits on Lock A).

After `deadlock_timeout` (1000ms), PostgreSQL aborts one transaction with `SQLSTATE 40P01`.

**FinPay Mathematical Resolution:**
In `sp_execute_fund_transfer`, I eliminated Dijkstra's *Circular Wait* condition by enforcing deterministic locking order based on account numbers:
```sql
IF p_source_account_number < p_destination_account_number THEN
    -- Lock source first, then destination
    PERFORM FROM accounts WHERE account_number = p_source_account_number FOR UPDATE;
    PERFORM FROM accounts WHERE account_number = p_destination_account_number FOR UPDATE;
ELSE
    -- Lock destination first, then source
    PERFORM FROM accounts WHERE account_number = p_destination_account_number FOR UPDATE;
    PERFORM FROM accounts WHERE account_number = p_source_account_number FOR UPDATE;
END IF;
```
Because all concurrent sessions acquire locks in the exact same global order, circular dependency cycles are eliminated.

---

## 6. PostgreSQL Isolation Levels Analysis

| Isolation Level | Behavior in FinPay | Anomaly Protection |
| :--- | :--- | :--- |
| **READ COMMITTED** *(Default)* | Each statement sees a new snapshot of committed data. Interleaved updates are visible between statements. | Protects against dirty reads via MVCC. Suitable for fast analytical queries. |
| **REPEATABLE READ** | The entire transaction operates on a frozen snapshot taken at transaction start. | Protects against non-repeatable reads and phantom reads. Aborts on concurrent write conflicts (`40001`). |
| **SERIALIZABLE** | Uses Serializable Snapshot Isolation (SSI) tracking SIREAD locks to prevent write skew. | Full serial execution guarantee. Higher abort rate under write contention. |

In FinPay, I chose **`READ COMMITTED` paired with explicit pessimistic row locks (`SELECT FOR UPDATE`)** for money transfers. This provides absolute mathematical correctness while avoiding the high transaction abort-and-retry overhead inherent in `SERIALIZABLE` under heavy payment contention.

---

## 7. How to Execute the Portfolio 3 Test Suite

```bash
# 1. Compile the stored procedure
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-3-transactions-concurrency/01-fund-transfer-procedure.sql

# 2. Run atomic COMMIT and ROLLBACK tests
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-3-transactions-concurrency/02-commit-rollback-tests.sql

# 3. Run concurrency control and double-spending tests
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-3-transactions-concurrency/03-concurrency-control.sql

# 4. Run isolation levels analysis
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-3-transactions-concurrency/04-isolation-levels.sql

# 5. Run deadlock prevention verification
docker compose exec -T finpay-postgres psql -U finpay_admin -d finpay_db < portfolio-3-transactions-concurrency/05-deadlock-handling.sql
```

---

## 8. Technical Reflection & Lessons Learned

### 8.1 Key Engineering Insights
- **Isolation vs Explicit Locking:** Early in my design, I considered setting `default_transaction_isolation = 'serializable'`. However, in a fintech environment processing thousands of concurrent webhook events, SSI transactions frequently abort with `40001` serialization failures, shifting the burden of exponential backoff retries onto the application layer. Using `READ COMMITTED` with deterministic row-level `FOR UPDATE` locks resolved concurrency conflicts at the storage engine level with zero retry overhead.
- **Double-Entry Discipline:** Maintaining explicit, immutable debit and credit ledger rows (`transactions`) alongside real-time balance mutation (`accounts`) is critical for auditability and reconciliations.

### 8.2 Practical Debugging Experience
When implementing `sp_execute_fund_transfer`, I encountered a PL/pgSQL compilation issue:
```text
ERROR: query has no destination for result data
HINT: If you want to discard the results of a SELECT, use PERFORM instead.
```
**Investigation:** Inside PL/pgSQL, a plain `SELECT ... FOR UPDATE` cannot be executed without an `INTO` target or `PERFORM` keyword.  
**Resolution:** I refactored the query to `SELECT account_id, available_balance INTO ... FROM accounts ... FOR UPDATE;` which captured the lock and stored the current balances for subsequent atomic arithmetic.

---

## 9. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Troubleshooting the PL/pgSQL `SELECT ... FOR UPDATE` target syntax requirement (`PERFORM` vs `INTO`).
   - Verifying the correct nested PL/pgSQL sub-block structure for savepoint exception handling.
3. **Student Verification & Ownership:**
   - I designed the fund transfer business logic, regulatory checks, and double-entry ledger flow.
   - I formulated the deterministic NUBAN lock ordering strategy to eliminate circular deadlocks.
   - I tested and verified all positive and negative test cases directly inside the active PostgreSQL 16 container.

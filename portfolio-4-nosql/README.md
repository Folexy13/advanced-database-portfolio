# Portfolio 4: NoSQL and Advanced Data Models

**Course:** MIT 8103 – Advanced Database Systems  
**Academic Session:** 2026/2027  
**Case Study:** FinPay Technologies Limited  
**Deliverable:** Polyglot Architecture, MongoDB Document Models, JSON Schema Validators, TTL & Geospatial Indexing, Aggregation Pipelines  
**Component Score Weight:** 7 Marks  
**Author:** Folajimi  

---

## 1. Executive Summary & Polyglot Architecture

In modern fintech architectures, no single database model optimally satisfies both high-integrity financial ledger transactions and high-velocity semi-structured telemetry.

In this fourth portfolio milestone, I implemented **Polyglot Persistence** for FinPay:
- **Relational Ledger (PostgreSQL 16):** Retains exclusive ownership of the structured financial ledger, accounts, NUBAN routing, and ACID transaction invariants.
- **Document Store (MongoDB 7.0):** Ingests high-frequency device security telemetry, user interaction streams, and polymorphic fraud investigation cases.

This milestone demonstrates document modelling, JSON Schema validation, Time-To-Live (TTL) index lifecycle management, 2dsphere geospatial indexing, and multi-stage aggregation pipelines.

---

## 2. Document Schema Models & Validation Rules

To prevent document bloat and ensure schema discipline in a NoSQL environment, I engineered strict JSON Schema validation (`$jsonSchema`) inside `01-mongo-schema.js` for two core collections:

### 2.1 Collection: `device_telemetry`
Captures hardware attributes, network telemetry, and GeoJSON location points on every authentication and fund transfer confirmation.

```json
{
  "customer_id": "a0000000-0000-0000-0000-000000000011",
  "device_id": "DEV-UNKNOWN-LINUX-BOT9",
  "ip_address": "185.220.101.5",
  "event_type": "APP_LOGIN",
  "platform": "WEB_PORTAL",
  "app_version": "unknown",
  "timestamp": "2026-10-18T02:15:30.000Z",
  "geo_location": {
    "city": "Frankfurt",
    "state": "Hesse",
    "country": "Germany",
    "type": "Point",
    "coordinates": [8.6821, 50.1109]
  },
  "network_telemetry": {
    "carrier": "Tor Exit Node / Hosting Provider",
    "connection_type": "VPN",
    "vpn_detected": true
  }
}
```

### 2.2 Collection: `fraud_incident_cases`
A polymorphic document structure for compliance and risk officers. Unlike relational tables that require sparse NULL columns or rigid join tables, each incident file encapsulates dynamic investigation notes, variable risk indicators, and remediation action arrays.

```json
{
  "case_id": "CASE-2026-OCT-001",
  "account_id": "b0000000-0000-0000-0000-000000000012",
  "initial_trigger_rule": "IMPOSSIBLE_TRAVEL_VELOCITY",
  "risk_score": 95,
  "case_status": "CONFIRMED_FRAUD",
  "remediation_actions": ["ACCOUNT_PND_FREEZE", "PASSWORD_INVALIDATION", "DEVICE_REVOKE"],
  "investigation_notes": [
    {
      "officer_id": "COMPLIANCE_OFFICER_01",
      "note": "System flagged login in Frankfurt 15 minutes after authenticated session in Lagos.",
      "timestamp": "2026-10-18T02:20:00.000Z"
    }
  ]
}
```

---

## 3. Advanced Indexing Strategies in MongoDB

I implemented three specialized index paradigms in `01-mongo-schema.js`:

1. **Compound Index (`{ customer_id: 1, timestamp: -1 }`):**  
   Accelerates real-time customer device velocity checks during login authorization, allowing sub-millisecond retrieval of the user's latest access credentials.
2. **2dsphere Geospatial Index (`{ "geo_location.coordinates": "2dsphere" }`):**  
   Enables spatial distance calculations on the earth's surface using GeoJSON Points (`[longitude, latitude]`), directly supporting impossible-travel velocity algorithms.
3. **Time-To-Live (TTL) Index (`{ timestamp: 1 }` with `expireAfterSeconds: 7776000`):**  
   Automatically prunes raw telemetry documents after 90 days. This enforces Nigerian Data Protection Regulation (NDPR) storage minimization at the database engine level without requiring scheduled batch deletion scripts.

---

## 4. Aggregation Pipelines & Empirical Results

In `03-mongo-queries.js`, I executed four advanced aggregation pipelines:

### 4.1 Pipeline 1: Anomalous VPN & Foreign Access Surveillance
- **Objective:** Filter sessions originating through VPNs or foreign IP addresses.
- **Output:**
  ```json
  [
    {
      "customer_id": "a0000000-0000-0000-0000-000000000011",
      "device_id": "DEV-UNKNOWN-LINUX-BOT9",
      "ip_address": "185.220.101.5",
      "event_type": "PASSWORD_RESET",
      "location": "Frankfurt, Germany",
      "connection": "VPN",
      "carrier": "Tor Exit Node / Hosting Provider"
    }
  ]
  ```
- **Finding:** Immediately isolated Olumide Fashola's account takeover attempt from a German Tor exit node.

### 4.2 Pipeline 2: Device Diversity & Platform Velocity
- **Objective:** Detect credential-stuffing attacks by measuring distinct devices and platforms per customer.
- **Output:** Flagged customer `a0000000-...-0011` operating across two distinct devices (`DEV-TECNO-CAMON20` and `DEV-UNKNOWN-LINUX-BOT9`) and two distant locations (`Lagos` and `Frankfurt`) within a 15-minute window.

### 4.3 Pipeline 3: Fraud Case Remediation Breakdown (`$unwind`)
- **Objective:** Unwinds the `remediation_actions` array to compute the frequency of compliance enforcement actions across all active cases.
- **Output:** Verified that `ACCOUNT_PND_FREEZE`, `PASSWORD_INVALIDATION`, and `DEVICE_REVOKE` were applied to high-risk cases (average risk score: 95).

### 4.4 Pipeline 4: Multi-Faceted Security Dashboard (`$facet`)
- **Objective:** Computes a single-pass dashboard summarizing platform distributions, event types, and VPN detection counts.
- **Output:** `ANDROID`: 3, `WEB_PORTAL`: 3, `IOS`: 2; Total VPN detections: 2.

---

## 5. Architectural Suitability & Polyglot Trade-Offs

A detailed comparative analysis is documented in [`04-relational-vs-nosql-comparison.md`](04-relational-vs-nosql-comparison.md).

### Summary of Architectural Boundaries:
- **Use PostgreSQL for:** Immutable financial accounting, account balances, foreign-key consistency, and CBN regulatory ceilings.
- **Use MongoDB for:** Mobile device fingerprinting, unstructured event logs, geospatial velocity tracking, and automated 90-day TTL document purging.

---

## 6. How to Execute the Portfolio 4 Test Suite

The MongoDB instance is pre-configured in `docker-compose.yml` on port **`27018`**:

```bash
# 1. Start the MongoDB container
docker compose up -d finpay-mongo

# 2. Deploy schema validation and indexes
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/01-mongo-schema.js

# 3. Seed telemetry and fraud case documents
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/02-mongo-seed.js

# 4. Execute aggregation pipelines
docker compose exec finpay-mongo mongosh -u finpay_mongo -p FinPayMongo2026! --authenticationDatabase admin finpay_nosql /portfolio-4/03-mongo-queries.js
```

---

## 7. Technical Reflection & Lessons Learned

### 7.1 Key Engineering Insights
- **Avoiding the Unbounded Document Anti-Pattern:**  
  When modelling customer activities in MongoDB, I considered embedding transaction records directly inside the customer document. However, active banking customers generate thousands of transactions over time. In MongoDB, documents have a hard **16MB BSON size limit**. Unbounded embedded arrays lead to frequent memory re-allocations, document fragmentation, and eventually database write crashes. Leaving core transactions in PostgreSQL and using MongoDB strictly for time-bounded telemetry preserved high system performance.
- **TTL Index Mechanics:**  
  Understanding that MongoDB's background TTL thread runs once every 60 seconds helped me appreciate how automatic data retention works without application cron overhead.

### 7.2 Practical Debugging Experience
When building `01-mongo-schema.js`, I encountered a geospatial index error during collection creation:
```text
MongoServerError: Can't extract geo keys: ... Point coordinates must be an array of two numbers [longitude, latitude]
```
**Investigation:** In standard geographic conventions, coordinates are often spoken as "Latitude, Longitude". However, the GeoJSON RFC 7946 specification and MongoDB's `2dsphere` index strictly require **`[longitude, latitude]`** (X then Y). A point with latitude exceeding $\pm90^\circ$ causes index validation to fail.  
**Resolution:** I verified and inverted the coordinate array order (e.g. Lagos: `[3.3515, 6.5965]`), allowing the 2dsphere index to build cleanly.

---

## 8. Academic Integrity and AI Use Declaration

*(In accordance with Section 11 of the Continuous Assessment Syllabus)*

1. **AI Tools Used:** Claude / AI Programming Assistant
2. **Specific Tasks Where AI Was Used:**
   - Reviewing MongoDB's `$jsonSchema` syntax for GeoJSON Point coordinate validation.
   - Formatting raw JSON aggregation output into Markdown documentation blocks.
3. **Student Verification & Ownership:**
   - I designed the polyglot persistence architecture separating relational ledger invariants from document telemetry.
   - I formulated the four aggregation pipelines targeting Nigerian fintech fraud patterns (VPN exit nodes, impossible travel, and device switching).
   - I executed and tested all MongoDB scripts inside the live Docker environment.

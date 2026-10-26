// MIT 8103: Advanced Database Systems
// Continuous Assessment: Portfolio 4 - NoSQL and Advanced Data Models
// Case Study: FinPay Technologies Ltd
// File: 01-mongo-schema.js
// Description: MongoDB schema design, collection creation with JSON Schema validation,
//              TTL index expiration, and geospatial index definitions.
// Author: Folajimi

const dbName = 'finpay_nosql';
const dbInstance = db.getSiblingDB(dbName);

print('Configuring FinPay NoSQL Document Collections on ' + dbName + '...');

// 1. Drop existing collections to ensure idempotent execution
dbInstance.device_telemetry.drop();
dbInstance.audit_events_stream.drop();
dbInstance.fraud_incident_cases.drop();

// ============================================================================
// COLLECTION 1: device_telemetry
// Purpose: Captures high-frequency mobile and web device telemetry during user logins
//          and transfer confirmations. Uses strict types for core attributes
//          while permitting extensible nested metadata.
// ============================================================================
dbInstance.createCollection('device_telemetry', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'device_id', 'ip_address', 'event_type', 'timestamp', 'geo_location'],
            properties: {
                customer_id: {
                    bsonType: 'string',
                    description: 'UUID string of the customer in PostgreSQL ledger'
                },
                device_id: {
                    bsonType: 'string',
                    description: 'Unique hardware fingerprint or mobile device identifier'
                },
                ip_address: {
                    bsonType: 'string',
                    description: 'Client IPv4 or IPv6 address'
                },
                event_type: {
                    enum: ['APP_LOGIN', 'BIOMETRIC_AUTH', 'TRANSFER_CONFIRM', 'PASSWORD_RESET', 'CARD_TOKENIZE'],
                    description: 'Categorized security event trigger'
                },
                platform: {
                    enum: ['ANDROID', 'IOS', 'WEB_PORTAL', 'POS_AGENT'],
                    description: 'Client client operating environment'
                },
                app_version: {
                    bsonType: 'string'
                },
                timestamp: {
                    bsonType: 'date',
                    description: 'UTC timestamp of the telemetry event'
                },
                geo_location: {
                    bsonType: 'object',
                    required: ['city', 'country', 'type', 'coordinates'],
                    properties: {
                        city: { bsonType: 'string' },
                        state: { bsonType: 'string' },
                        country: { bsonType: 'string' },
                        type: { enum: ['Point'] },
                        coordinates: {
                            bsonType: 'array',
                            minItems: 2,
                            maxItems: 2,
                            items: { bsonType: 'double' },
                            description: '[longitude, latitude] array format for GeoJSON'
                        }
                    }
                },
                network_telemetry: {
                    bsonType: 'object',
                    properties: {
                        carrier: { bsonType: 'string' },
                        connection_type: { enum: ['WIFI', '4G', '5G', 'CELLULAR', 'VPN'] },
                        vpn_detected: { bsonType: 'bool' }
                    }
                }
            }
        }
    }
});

print('Collection device_telemetry created with JSON Schema validation.');

// ============================================================================
// INDEXES: device_telemetry
// ============================================================================
// A. Compound index for querying a specific customer's login velocity
dbInstance.device_telemetry.createIndex(
    { customer_id: 1, timestamp: -1 },
    { name: 'idx_customer_timestamp_desc' }
);

// B. 2dsphere index for geospatial proximity & impossible travel detection
dbInstance.device_telemetry.createIndex(
    { 'geo_location.coordinates': '2dsphere' },
    { name: 'idx_telemetry_geospatial' }
);

// C. Time-To-Live (TTL) index: Automatically expires raw telemetry after 90 days
//    to comply with Nigerian Data Protection Regulation (NDPR) storage minimization.
dbInstance.device_telemetry.createIndex(
    { timestamp: 1 },
    { expireAfterSeconds: 7776000, name: 'idx_ttl_90_days' }
);

print('Indexes created for device_telemetry (Compound, 2dsphere, TTL).');

// ============================================================================
// COLLECTION 2: fraud_incident_cases
// Purpose: Polymorphic case files for compliance investigations. Accommodates
//          dynamic risk factor arrays, investigator notes, and evidence blobs.
// ============================================================================
dbInstance.createCollection('fraud_incident_cases', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['case_id', 'account_id', 'initial_trigger_rule', 'risk_score', 'case_status', 'created_at'],
            properties: {
                case_id: { bsonType: 'string' },
                account_id: { bsonType: 'string' },
                initial_trigger_rule: { bsonType: 'string' },
                risk_score: { bsonType: 'int', minimum: 0, maximum: 100 },
                case_status: { enum: ['OPEN', 'UNDER_INVESTIGATION', 'CONFIRMED_FRAUD', 'CLEARED_FALSE_POSITIVE'] },
                investigation_notes: {
                    bsonType: 'array',
                    items: {
                        bsonType: 'object',
                        required: ['officer_id', 'note', 'timestamp'],
                        properties: {
                            officer_id: { bsonType: 'string' },
                            note: { bsonType: 'string' },
                            timestamp: { bsonType: 'date' }
                        }
                    }
                },
                remediation_actions: {
                    bsonType: 'array',
                    items: { bsonType: 'string' }
                },
                created_at: { bsonType: 'date' },
                updated_at: { bsonType: 'date' }
            }
        }
    }
});

// Indexes for fraud_incident_cases
dbInstance.fraud_incident_cases.createIndex(
    { case_status: 1, risk_score: -1 },
    { name: 'idx_status_risk_score' }
);

dbInstance.fraud_incident_cases.createIndex(
    { account_id: 1 },
    { name: 'idx_case_account_id' }
);

print('Collection fraud_incident_cases created with polymorphic validation & indexes.');
print('FinPay MongoDB Schema setup complete.');

// MongoDB Schema Setup for FinPay NoSQL Telemetry Store
// MIT 8103 Advanced Database Systems - Portfolio 4

const dbName = 'finpay_nosql';
const dbInstance = db.getSiblingDB(dbName);

print('Configuring FinPay collections on ' + dbName);

// Drop old collections to ensure clean setup
dbInstance.device_telemetry.drop();
dbInstance.audit_events_stream.drop();
dbInstance.fraud_incident_cases.drop();

// 1. device_telemetry collection with JSON schema validation
dbInstance.createCollection('device_telemetry', {
    validator: {
        $jsonSchema: {
            bsonType: 'object',
            required: ['customer_id', 'device_id', 'ip_address', 'event_type', 'timestamp', 'geo_location'],
            properties: {
                customer_id: {
                    bsonType: 'string',
                    description: 'Customer UUID string matching PostgreSQL ledger'
                },
                device_id: {
                    bsonType: 'string',
                    description: 'Hardware fingerprint or mobile device identifier'
                },
                ip_address: {
                    bsonType: 'string'
                },
                event_type: {
                    enum: ['APP_LOGIN', 'BIOMETRIC_AUTH', 'TRANSFER_CONFIRM', 'PASSWORD_RESET', 'CARD_TOKENIZE']
                },
                platform: {
                    enum: ['ANDROID', 'IOS', 'WEB_PORTAL', 'POS_AGENT']
                },
                app_version: {
                    bsonType: 'string'
                },
                timestamp: {
                    bsonType: 'date'
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
                            description: '[longitude, latitude] GeoJSON format'
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

// Indexes for device_telemetry
dbInstance.device_telemetry.createIndex(
    { customer_id: 1, timestamp: -1 },
    { name: 'idx_customer_timestamp_desc' }
);

dbInstance.device_telemetry.createIndex(
    { 'geo_location.coordinates': '2dsphere' },
    { name: 'idx_telemetry_geospatial' }
);

// TTL index to automatically prune raw telemetry after 90 days
dbInstance.device_telemetry.createIndex(
    { timestamp: 1 },
    { expireAfterSeconds: 7776000, name: 'idx_ttl_90_days' }
);

// 2. fraud_incident_cases collection
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

dbInstance.fraud_incident_cases.createIndex(
    { case_status: 1, risk_score: -1 },
    { name: 'idx_status_risk_score' }
);

dbInstance.fraud_incident_cases.createIndex(
    { account_id: 1 },
    { name: 'idx_case_account_id' }
);

print('Collections and indexes created successfully.');

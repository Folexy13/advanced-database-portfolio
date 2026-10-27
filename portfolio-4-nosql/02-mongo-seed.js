// Telemetry and incident seed data for FinPay MongoDB
const dbInstance = db.getSiblingDB('finpay_nosql');

print('Seeding telemetry events...');

// 1. device_telemetry records
const telemetryEvents = [
    // Customer 1: John Adeyemi - Normal Mobile App Usage in Lagos
    {
        customer_id: 'a0000000-0000-0000-0000-000000000001',
        device_id: 'DEV-APPLE-IPHONE15-A109B',
        ip_address: '197.210.64.15',
        event_type: 'APP_LOGIN',
        platform: 'IOS',
        app_version: 'v4.2.1-build204',
        timestamp: new Date('2026-10-15T08:15:20Z'),
        geo_location: {
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.3515, 6.5965] // Longitude, Latitude (Ikeja, Lagos)
        },
        network_telemetry: {
            carrier: 'MTN Nigeria',
            connection_type: '5G',
            vpn_detected: false
        }
    },
    {
        customer_id: 'a0000000-0000-0000-0000-000000000001',
        device_id: 'DEV-APPLE-IPHONE15-A109B',
        ip_address: '197.210.64.15',
        event_type: 'TRANSFER_CONFIRM',
        platform: 'IOS',
        app_version: 'v4.2.1-build204',
        timestamp: new Date('2026-10-15T08:18:45Z'),
        geo_location: {
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.3515, 6.5965]
        },
        network_telemetry: {
            carrier: 'MTN Nigeria',
            connection_type: '5G',
            vpn_detected: false
        }
    },

    // Customer 2: Sarah Okafor - Normal Activity in Abuja
    {
        customer_id: 'a0000000-0000-0000-0000-000000000002',
        device_id: 'DEV-SAMSUNG-S24-B908C',
        ip_address: '105.112.98.22',
        event_type: 'APP_LOGIN',
        platform: 'ANDROID',
        app_version: 'v4.2.0-build199',
        timestamp: new Date('2026-10-16T10:30:00Z'),
        geo_location: {
            city: 'Abuja',
            state: 'Federal Capital Territory',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [7.4913, 9.0820] // Maitama, Abuja
        },
        network_telemetry: {
            carrier: 'Airtel Nigeria',
            connection_type: '4G',
            vpn_detected: false
        }
    },
    {
        customer_id: 'a0000000-0000-0000-0000-000000000002',
        device_id: 'DEV-SAMSUNG-S24-B908C',
        ip_address: '105.112.98.22',
        event_type: 'BIOMETRIC_AUTH',
        platform: 'ANDROID',
        app_version: 'v4.2.0-build199',
        timestamp: new Date('2026-10-16T10:31:12Z'),
        geo_location: {
            city: 'Abuja',
            state: 'Federal Capital Territory',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [7.4913, 9.0820]
        },
        network_telemetry: {
            carrier: 'Airtel Nigeria',
            connection_type: '4G',
            vpn_detected: false
        }
    },

    // Customer 3: David Bello - Web Portal in Port Harcourt
    {
        customer_id: 'a0000000-0000-0000-0000-000000000003',
        device_id: 'DEV-CHROME-MACBOOK-C441D',
        ip_address: '102.89.44.110',
        event_type: 'APP_LOGIN',
        platform: 'WEB_PORTAL',
        app_version: 'web-v2.6.0',
        timestamp: new Date('2026-10-17T14:00:00Z'),
        geo_location: {
            city: 'Port Harcourt',
            state: 'Rivers State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [7.0179, 4.8156] // Port Harcourt
        },
        network_telemetry: {
            carrier: 'Starlink Nigeria',
            connection_type: 'WIFI',
            vpn_detected: false
        }
    },

    // Customer 11: Olumide Fashola - ANOMALOUS IMPOSSIBLE TRAVEL ATTACK
    // Event A: Legitimate login attempt from Lagos
    {
        customer_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'DEV-TECNO-CAMON20-E552K',
        ip_address: '197.210.45.88',
        event_type: 'APP_LOGIN',
        platform: 'ANDROID',
        app_version: 'v4.1.9-build180',
        timestamp: new Date('2026-10-18T02:00:00Z'),
        geo_location: {
            city: 'Lagos',
            state: 'Lagos State',
            country: 'Nigeria',
            type: 'Point',
            coordinates: [3.3792, 6.5244]
        },
        network_telemetry: {
            carrier: 'MTN Nigeria',
            connection_type: '4G',
            vpn_detected: false
        }
    },
    // Event B: Suspicious login 15 minutes later from Frankfurt, Germany (Impossible speed > 20,000 km/h)
    {
        customer_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'DEV-UNKNOWN-LINUX-BOT9',
        ip_address: '185.220.101.5',
        event_type: 'APP_LOGIN',
        platform: 'WEB_PORTAL',
        app_version: 'unknown',
        timestamp: new Date('2026-10-18T02:15:30Z'),
        geo_location: {
            city: 'Frankfurt',
            state: 'Hesse',
            country: 'Germany',
            type: 'Point',
            coordinates: [8.6821, 50.1109] // Frankfurt, Germany
        },
        network_telemetry: {
            carrier: 'Tor Exit Node / Hosting Provider',
            connection_type: 'VPN',
            vpn_detected: true
        }
    },
    // Event C: Password reset attempt from the suspicious German Tor node
    {
        customer_id: 'a0000000-0000-0000-0000-000000000011',
        device_id: 'DEV-UNKNOWN-LINUX-BOT9',
        ip_address: '185.220.101.5',
        event_type: 'PASSWORD_RESET',
        platform: 'WEB_PORTAL',
        app_version: 'unknown',
        timestamp: new Date('2026-10-18T02:16:40Z'),
        geo_location: {
            city: 'Frankfurt',
            state: 'Hesse',
            country: 'Germany',
            type: 'Point',
            coordinates: [8.6821, 50.1109]
        },
        network_telemetry: {
            carrier: 'Tor Exit Node / Hosting Provider',
            connection_type: 'VPN',
            vpn_detected: true
        }
    }
];

dbInstance.device_telemetry.insertMany(telemetryEvents);
print('Inserted ' + telemetryEvents.length + ' device telemetry records.');

// 2. fraud_incident_cases records
const fraudCases = [
    {
        case_id: 'CASE-2026-OCT-001',
        account_id: 'b0000000-0000-0000-0000-000000000012', // Olumide Fashola's account
        initial_trigger_rule: 'IMPOSSIBLE_TRAVEL_VELOCITY',
        risk_score: 95,
        case_status: 'CONFIRMED_FRAUD',
        remediation_actions: ['ACCOUNT_PND_FREEZE', 'PASSWORD_INVALIDATION', 'DEVICE_REVOKE'],
        investigation_notes: [
            {
                officer_id: 'COMPLIANCE_OFFICER_01',
                note: 'System flagged login in Frankfurt 15 minutes after authenticated session in Lagos. VPN exit node confirmed.',
                timestamp: new Date('2026-10-18T02:20:00Z')
            },
            {
                officer_id: 'LEGAL_ADMIN_04',
                note: 'Contacted customer via registered mobile number; customer confirmed they did not initiate Frankfurt web session.',
                timestamp: new Date('2026-10-18T08:45:00Z')
            },
            {
                officer_id: 'COMPLIANCE_OFFICER_01',
                note: 'Enforced PostgreSQL FROZEN_PND status on account 0124456789. Audit trail captured.',
                timestamp: new Date('2026-10-18T09:00:00Z')
            }
        ],
        counterparty_risk_graph: {
            flagged_ips: ['185.220.101.5'],
            threat_actor_classification: 'CREDENTIAL_STUFFING_BOTNET',
            associated_external_banks: []
        },
        created_at: new Date('2026-10-18T02:17:00Z'),
        updated_at: new Date('2026-10-18T09:00:00Z')
    },
    {
        case_id: 'CASE-2026-OCT-002',
        account_id: 'b0000000-0000-0000-0000-000000000005', // Amina Yusuf's basic wallet
        initial_trigger_rule: 'DAILY_LIMIT_EXCEEDED',
        risk_score: 72,
        case_status: 'CLEARED_FALSE_POSITIVE',
        remediation_actions: ['KYC_UPGRADE_OFFER_SMS'],
        investigation_notes: [
            {
                officer_id: 'SUPPORT_LEAD_02',
                note: 'Customer attempted 45,000 NGN transfer on Tier 1 account with 20,000 single transfer cap. Transaction failed as expected.',
                timestamp: new Date('2026-10-19T11:00:00Z')
            },
            {
                officer_id: 'SUPPORT_LEAD_02',
                note: 'Customer advised to submit NIN on mobile app to upgrade to Tier 2 (daily limit 200,000 NGN).',
                timestamp: new Date('2026-10-19T11:30:00Z')
            }
        ],
        created_at: new Date('2026-10-19T10:45:00Z'),
        updated_at: new Date('2026-10-19T11:30:00Z')
    }
];

dbInstance.fraud_incident_cases.insertMany(fraudCases);
print('Inserted ' + fraudCases.length + ' polymorphic fraud incident cases.');
print('FinPay MongoDB Seed Data complete.');

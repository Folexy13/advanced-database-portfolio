// MIT 8103: Advanced Database Systems
// Continuous Assessment: Portfolio 4 - NoSQL and Advanced Data Models
// Case Study: FinPay Technologies Ltd
// File: 03-mongo-queries.js
// Description: Advanced MongoDB aggregation pipelines for fraud detection,
//              device velocity, and compliance audit reporting.
// Author: Folajimi

const dbName = 'finpay_nosql';
const dbInstance = db.getSiblingDB(dbName);

print('======================================================================');
print('AGGREGATION PIPELINE 1: SUSPICIOUS VPN & ANOMALOUS ACCESS SURVEILLANCE');
print('Business Purpose: Identifies all customer sessions flagged with VPN usage');
print('                  or unauthorized foreign login locations.');
print('======================================================================');

const vpnAlertPipeline = [
    {
        $match: {
            $or: [
                { 'network_telemetry.vpn_detected': true },
                { 'geo_location.country': { $ne: 'Nigeria' } }
            ]
        }
    },
    {
        $project: {
            _id: 0,
            customer_id: 1,
            device_id: 1,
            ip_address: 1,
            event_type: 1,
            location: {
                $concat: ['$geo_location.city', ', ', '$geo_location.country']
            },
            connection: '$network_telemetry.connection_type',
            carrier: '$network_telemetry.carrier',
            timestamp: 1
        }
    },
    { $sort: { timestamp: -1 } }
];

const vpnAlerts = dbInstance.device_telemetry.aggregate(vpnAlertPipeline).toArray();
printjson(vpnAlerts);

print('======================================================================');
print('AGGREGATION PIPELINE 2: CUSTOMER DEVICE DIVERSITY & PLATFORM VELOCITY');
print('Business Purpose: Detects credential stuffing by measuring distinct devices');
print('                  and platforms utilized per customer.');
print('======================================================================');

const deviceVelocityPipeline = [
    {
        $group: {
            _id: '$customer_id',
            total_events: { $sum: 1 },
            distinct_devices: { $addToSet: '$device_id' },
            distinct_platforms: { $addToSet: '$platform' },
            distinct_cities: { $addToSet: '$geo_location.city' },
            latest_activity: { $max: '$timestamp' }
        }
    },
    {
        $project: {
            _id: 0,
            customer_id: '$_id',
            total_events: 1,
            device_count: { $size: '$distinct_devices' },
            devices_used: '$distinct_devices',
            platforms_used: '$distinct_platforms',
            locations: '$distinct_cities',
            latest_activity: 1
        }
    },
    { $sort: { device_count: -1, total_events: -1 } }
];

const velocityReport = dbInstance.device_telemetry.aggregate(deviceVelocityPipeline).toArray();
printjson(velocityReport);

print('======================================================================');
print('AGGREGATION PIPELINE 3: FRAUD CASE REMEDIATION BREAKDOWN ($unwind)');
print('Business Purpose: Aggregates confirmed vs pending fraud cases and counts');
print('                  remediation actions enforced across incident files.');
print('======================================================================');

const remediationPipeline = [
    { $unwind: '$remediation_actions' },
    {
        $group: {
            _id: '$remediation_actions',
            action_count: { $sum: 1 },
            avg_case_risk: { $avg: '$risk_score' },
            associated_cases: { $addToSet: '$case_id' }
        }
    },
    {
        $project: {
            _id: 0,
            remediation_action: '$_id',
            frequency: '$action_count',
            avg_risk_score: { $round: ['$avg_case_risk', 1] },
            cases: '$associated_cases'
        }
    },
    { $sort: { frequency: -1 } }
];

const remediationSummary = dbInstance.fraud_incident_cases.aggregate(remediationPipeline).toArray();
printjson(remediationSummary);

print('======================================================================');
print('AGGREGATION PIPELINE 4: MULTI-FACETED SECURITY AUDIT DASHBOARD ($facet)');
print('Business Purpose: Single-pass pipeline computing platform distributions,');
print('                  top event types, and critical fraud case summaries.');
print('======================================================================');

const dashboardPipeline = [
    {
        $facet: {
            platform_distribution: [
                { $group: { _id: '$platform', count: { $sum: 1 } } },
                { $sort: { count: -1 } }
            ],
            event_type_summary: [
                { $group: { _id: '$event_type', count: { $sum: 1 } } },
                { $sort: { count: -1 } }
            ],
            vpn_usage_count: [
                { $match: { 'network_telemetry.vpn_detected': true } },
                { $count: 'total_vpn_detected' }
            ]
        }
    }
];

const dashboardResult = dbInstance.device_telemetry.aggregate(dashboardPipeline).toArray();
printjson(dashboardResult);

// FinPay MongoDB Analytics & Aggregation Queries
// MIT 8103 Advanced Database Systems - Portfolio 4

const dbInstance = db.getSiblingDB('finpay_nosql');

// 1. Detect suspicious logins (VPN usage or logins outside Nigeria)
print('--- Suspicious VPN & Foreign Access Queries ---');
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

// 2. Measure distinct devices and platforms per customer (credential stuffing detection)
print('--- Customer Device Diversity & Platform Velocity ---');
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

// 3. Count remediation actions across incident files using $unwind
print('--- Fraud Case Remediation Breakdown ---');
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

// 4. Single-pass security dashboard summary using $facet
print('--- Multi-Faceted Security Dashboard Summary ---');
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

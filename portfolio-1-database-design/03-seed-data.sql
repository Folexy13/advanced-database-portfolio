-- ============================================================================
-- MIT 8103: Advanced Database Systems
-- Continuous Assessment: Portfolio 1 - Database Design and Modelling
-- Case Study: FinPay Technologies Ltd
-- File: 03-seed-data.sql
-- Description: Realistic baseline dataset reflecting the Nigerian fintech
--              ecosystem (Customers, KYC tiers, Accounts, Transfers, Audit).
-- ============================================================================

-- ============================================================================
-- 1. SEED: kyc_tiers (CBN Regulatory Standards)
-- ============================================================================
INSERT INTO kyc_tiers (tier_level, tier_name, daily_transaction_limit, single_transaction_limit, max_balance_limit, description)
VALUES 
(1, 'Tier 1 - Basic Wallet', 50000.00, 20000.00, 300000.00, 'Requires phone number and basic personal info. No BVN required.'),
(2, 'Tier 2 - Verified Individual', 200000.00, 50000.00, 500000.00, 'Requires verified National Identity Number (NIN) and residential address.'),
(3, 'Tier 3 - Premium Account', 5000000.00, 1000000.00, NULL, 'Fully verified account requiring BVN, NIN, proof of address, and utility bill. No balance cap.');

-- ============================================================================
-- 2. SEED: customers
-- ============================================================================
INSERT INTO customers (customer_id, first_name, last_name, email, phone_number, bvn_hash, nin_hash, kyc_tier, account_status)
VALUES 
('a0000000-0000-0000-0000-000000000001', 'John', 'Adeyemi', 'john.adeyemi@finpay.ng', '+2348011234567', 
 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', 
 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000002', 'Sarah', 'Okafor', 'sarah.okafor@finpay.ng', '+2348022345678', 
 '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a', 
 '3e23e8160039594a33894f6564e1b1348bbd7a0088d42c4acb73eeaed59c009d', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000003', 'David', 'Bello', 'david.bello@finpay.ng', '+2348033456789', 
 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d', 
 '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000004', 'Amina', 'Yusuf', 'amina.yusuf@finpay.ng', '+2348044567890', 
 NULL, NULL, 1, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000005', 'Emeka', 'Nwosu', 'emeka.nwosu@finpay.ng', '+2348055678901', 
 'fcba950aca43224aad2221e3fb904e20197d20b62b79e3bc778d0def7f664377', 
 '70c7283c153cad20f3153c5f318e517a32371687c42399778ec304214bbdd73d', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000006', 'Folake', 'Balogun', 'folake.balogun@finpay.ng', '+2348066789012', 
 '2f741529ef8f2f01f80ca024b439c7fd69e6b3687353f86e33057e96b349254b', 
 '2e7d2c03a9507ae265ecf5b5356885a53393a2029d24139499ddf66f09b9c73b', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000007', 'Ibrahim', 'Danjuma', 'ibrahim.danjuma@finpay.ng', '+2348077890123', 
 NULL, NULL, 1, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000008', 'Chidinma', 'Eze', 'chidinma.eze@finpay.ng', '+2348088901234', 
 '18ac3e7343f016890c510e93f935261169d9e3f565436429830faf0934f4f8e4', 
 '9b71d224bd62f3785d96d46ad3ea3d73319bfbc2890caadae2dff72519673ca7', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000009', 'Babatunde', 'Adeleke', 'babatunde.adeleke@finpay.ng', '+2348099012345', 
 '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b', 
 'd4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35', 3, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000010', 'Halima', 'Garba', 'halima.garba@finpay.ng', '+2348019876543', 
 '4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce', 
 '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a', 2, 'ACTIVE'),

('a0000000-0000-0000-0000-000000000011', 'Olumide', 'Fashola', 'olumide.fashola@finpay.ng', '+2348028765432', 
 NULL, NULL, 1, 'SUSPENDED'),

('a0000000-0000-0000-0000-000000000012', 'Ngozi', 'Okonjo', 'ngozi.okonjo@finpay.ng', '+2348037654321', 
 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d', 
 '2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae', 3, 'ACTIVE');

-- ============================================================================
-- 3. SEED: accounts (10-digit NUBAN Format)
-- ============================================================================
INSERT INTO accounts (account_id, customer_id, account_number, account_type, currency, available_balance, ledger_balance, account_status)
VALUES 
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', '0123456789', 'SAVINGS', 'NGN', 125000.0000, 125000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', '0123456790', 'CURRENT', 'NGN', 450000.0000, 450000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000002', '0223456781', 'SAVINGS', 'NGN', 110000.0000, 110000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000003', '0323456782', 'CURRENT', 'NGN', 230000.0000, 230000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000004', '0423456783', 'SAVINGS', 'NGN', 15000.0000, 15000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000005', '0523456784', 'SAVINGS', 'NGN', 75000.0000, 75000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000006', '0623456785', 'CURRENT', 'NGN', 620000.0000, 620000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000007', '0723456786', 'SAVINGS', 'NGN', 8500.0000, 8500.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000009', 'a0000000-0000-0000-0000-000000000008', '0823456787', 'SAVINGS', 'NGN', 110000.0000, 110000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000010', 'a0000000-0000-0000-0000-000000000009', '0923456788', 'CURRENT', 'NGN', 1250000.0000, 1250000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000011', 'a0000000-0000-0000-0000-000000000010', '0113456789', 'SAVINGS', 'NGN', 45000.0000, 45000.0000, 'ACTIVE'),
('b0000000-0000-0000-0000-000000000012', 'a0000000-0000-0000-0000-000000000011', '0124456789', 'SAVINGS', 'NGN', 12000.0000, 12000.0000, 'FROZEN_PND'),
('b0000000-0000-0000-0000-000000000013', 'a0000000-0000-0000-0000-000000000012', '0123556789', 'MERCHANT_WALLET', 'NGN', 5800000.0000, 5800000.0000, 'ACTIVE');

-- ============================================================================
-- 4. SEED: beneficiaries (Saved Payees)
-- ============================================================================
INSERT INTO beneficiaries (customer_id, beneficiary_account_number, bank_code, bank_name, account_name, nickname)
VALUES 
('a0000000-0000-0000-0000-000000000001', '0223456781', '000000', 'FinPay Internal', 'Sarah Okafor', 'Sarah Sister'),
('a0000000-0000-0000-0000-000000000001', '2045678901', '000013', 'Guaranty Trust Bank (GTBank)', 'Tunde Bakare', 'Landlord Rent'),
('a0000000-0000-0000-0000-000000000002', '0323456782', '000000', 'FinPay Internal', 'David Bello', 'David Colleague'),
('a0000000-0000-0000-0000-000000000003', '0123456789', '000000', 'FinPay Internal', 'John Adeyemi', 'John Partner'),
('a0000000-0000-0000-0000-000000000006', '0123556789', '000000', 'FinPay Internal', 'Ngozi Okonjo', 'Mama Put Groceries');

-- ============================================================================
-- 5. SEED: transactions (Coherent Double-Entry Ledger)
-- Scenario 1: Initial Deposit for John Adeyemi (₦150,000.00)
-- Scenario 2: P2P Intra-bank Transfer: John Adeyemi sends ₦25,000.00 to Sarah Okafor
--             - Debit John (b0000000-...-0001): -₦25,000 (balance after ₦125,000)
--             - Credit Sarah (b0000000-...-0003): +₦25,000 (balance after ₦110,000)
-- Scenario 3: Inter-bank NIP Transfer from David Bello to GTBank (₦50,000.00 + ₦10.75 fee)
-- Scenario 4: Bill Payment (Electricity Disco token) by Folake Balogun (₦15,000.00 + ₦100 fee)
-- ============================================================================
INSERT INTO transactions (transaction_id, transaction_reference, account_id, transaction_type, category, amount, fee, balance_after, status, narration, created_at)
VALUES 
-- John Adeyemi Initial Opening Deposit
('c0000000-0000-0000-0000-000000000001', 'FP-DEP-20261001-0001', 'b0000000-0000-0000-0000-000000000001', 
 'CREDIT', 'DEPOSIT', 150000.0000, 0.0000, 150000.0000, 'SUCCESS', 'Inbound NIP Deposit from Access Bank', 
 '2026-10-01 09:30:00+01'),

-- Sarah Okafor Initial Opening Balance
('c0000000-0000-0000-0000-000000000002', 'FP-DEP-20261001-0002', 'b0000000-0000-0000-0000-000000000003', 
 'CREDIT', 'DEPOSIT', 85000.0000, 0.0000, 85000.0000, 'SUCCESS', 'Initial Wallet Funding via Debit Card', 
 '2026-10-01 10:15:00+01'),

-- P2P Transfer Leg 1: Debit John Adeyemi (b0000000-...-0001)
('c0000000-0000-0000-0000-000000000003', 'FP-TRF-20261002-0001', 'b0000000-0000-0000-0000-000000000001', 
 'DEBIT', 'INTRA_TRANSFER', 25000.0000, 0.0000, 125000.0000, 'SUCCESS', 'FinPay Transfer to Sarah Okafor', 
 '2026-10-02 14:20:00+01'),

-- P2P Transfer Leg 2: Credit Sarah Okafor (b0000000-...-0003)
('c0000000-0000-0000-0000-000000000004', 'FP-TRF-20261002-0002', 'b0000000-0000-0000-0000-000000000003', 
 'CREDIT', 'INTRA_TRANSFER', 25000.0000, 0.0000, 110000.0000, 'SUCCESS', 'FinPay Transfer from John Adeyemi', 
 '2026-10-02 14:20:01+01'),

-- Inter-bank Outward NIP Transfer from David Bello
('c0000000-0000-0000-0000-000000000005', 'FP-NIP-20261003-0001', 'b0000000-0000-0000-0000-000000000004', 
 'DEBIT', 'INTER_TRANSFER_NIP', 50000.0000, 10.7500, 230000.0000, 'SUCCESS', 'NIP Transfer to Tunde Adeleke / Zenith Bank', 
 '2026-10-03 11:45:00+01'),

-- Utility Bill Payment by Folake Balogun
('c0000000-0000-0000-0000-000000000006', 'FP-BIL-20261004-0001', 'b0000000-0000-0000-0000-000000000007', 
 'DEBIT', 'BILL_PAYMENT', 15000.0000, 100.0000, 620000.0000, 'SUCCESS', 'IKEDC Prepaid Electricity Token purchase', 
 '2026-10-04 16:05:00+01'),

-- Airtime Purchase by Amina Yusuf
('c0000000-0000-0000-0000-000000000007', 'FP-AIR-20261005-0001', 'b0000000-0000-0000-0000-000000000005', 
 'DEBIT', 'AIRTIME_DATA', 2000.0000, 0.0000, 15000.0000, 'SUCCESS', 'MTN VTU Airtime Recharge +2348044567890', 
 '2026-10-05 18:10:00+01'),

-- Failed Transfer Example (for Portfolio 3 rollback & testing reference)
('c0000000-0000-0000-0000-000000000008', 'FP-TRF-20261006-0099', 'b0000000-0000-0000-0000-000000000005', 
 'DEBIT', 'INTER_TRANSFER_NIP', 45000.0000, 10.7500, 15000.0000, 'FAILED', 'Failed Transfer - Switch Timeout NIBSS 91', 
 '2026-10-06 20:00:00+01');

-- ============================================================================
-- 6. SEED: transfers (Settlement Specifics)
-- ============================================================================
INSERT INTO transfers (transfer_id, transaction_id, source_account_id, destination_bank_code, destination_bank_name, destination_account_number, destination_account_name, nip_session_id, channel, transfer_status, created_at)
VALUES 
('d0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 
 '000000', 'FinPay Internal', '0223456781', 'Sarah Okafor', NULL, 'MOBILE_APP', 'COMPLETED', '2026-10-02 14:20:00+01'),

('d0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000004', 
 '000015', 'Zenith Bank Plc', '2019876543', 'Tunde Adeleke', '999015261003114500000012345678', 'MOBILE_APP', 'COMPLETED', '2026-10-03 11:45:00+01'),

('d0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000008', 'b0000000-0000-0000-0000-000000000005', 
 '000014', 'Access Bank Plc', '0029384756', 'Kalu Kalu', '999014261006200000000098765432', 'WEB', 'FAILED', '2026-10-06 20:00:00+01');

-- ============================================================================
-- 7. SEED: fraud_alerts (Risk Surveillance Baseline)
-- ============================================================================
INSERT INTO fraud_alerts (alert_id, account_id, transaction_id, rule_code, risk_score, severity, status, review_notes, created_at)
VALUES 
('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000008', 
 'DAILY_LIMIT_EXCEEDED', 75, 'HIGH', 'FLAGGED', 
 'Customer on Tier 1 attempted single transfer of 45,000 NGN exceeding single transfer ceiling (20,000 NGN).', 
 '2026-10-06 20:00:05+01'),

('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000012', NULL, 
 'OFF_PEAK_VELOCITY', 88, 'CRITICAL', 'UNDER_INVESTIGATION', 
 'Multiple repeated authentication and high velocity queries on restricted PND account from foreign IP.', 
 '2026-10-07 03:15:22+01');

-- ============================================================================
-- 8. SEED: audit_logs (Initial Snapshot)
-- ============================================================================
INSERT INTO audit_logs (table_name, record_id, action, old_state, new_state, changed_by, client_ip)
VALUES 
('customers', 'a0000000-0000-0000-0000-000000000011', 'UPDATE', 
 '{"account_status": "ACTIVE"}', 
 '{"account_status": "SUSPENDED", "reason": "Suspected KYC discrepancy on NIN validation"}', 
 'COMPLIANCE_OFFICER_01', '197.210.64.12'),

('accounts', 'b0000000-0000-0000-0000-000000000012', 'UPDATE', 
 '{"account_status": "ACTIVE"}', 
 '{"account_status": "FROZEN_PND", "reason": "Court Order Post-No-Debit enforcement"}', 
 'LEGAL_ADMIN_04', '197.210.64.15');

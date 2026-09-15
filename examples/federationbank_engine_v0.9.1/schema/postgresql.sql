-- FederationBank IOM Offshore banking engine v0.7 reference schema.
-- Core state and monetary DML are committed through ooRexx DB Skeleton
-- transactions.  Never issue individual customer/account/posting INSERTs
-- outside the FederationBank Engine authority boundary.

CREATE TABLE IF NOT EXISTS federationbank_customers (
    customer_id VARCHAR(128) PRIMARY KEY,
    legal_name TEXT NOT NULL,
    date_of_birth VARCHAR(32) NOT NULL,
    postcode VARCHAR(64) NOT NULL,
    address_country VARCHAR(64) NOT NULL,
    segment VARCHAR(64) NOT NULL,
    domicile VARCHAR(64) NOT NULL,
    residence VARCHAR(64) NOT NULL,
    risk_tier VARCHAR(64) NOT NULL,
    created_at VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS federationbank_accounts (
    account_id VARCHAR(128) PRIMARY KEY,
    customer_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    product_code VARCHAR(128) NOT NULL,
    booking_jurisdiction VARCHAR(64) NOT NULL,
    regulatory_profile_id VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL,
    opened_at VARCHAR(64) NOT NULL
);
CREATE INDEX IF NOT EXISTS federationbank_accounts_customer_idx
    ON federationbank_accounts(customer_id, currency, status);

-- Account Engine-owned beneficiary master state.  Payments may consume
-- projections but does not own or directly mutate these rows.
CREATE TABLE IF NOT EXISTS federationbank_beneficiaries (
    customer_id VARCHAR(128) NOT NULL REFERENCES federationbank_customers(customer_id),
    beneficiary_id VARCHAR(128) NOT NULL,
    owner_account_id VARCHAR(128) NOT NULL REFERENCES federationbank_accounts(account_id),
    display_name TEXT NOT NULL,
    account_reference VARCHAR(256) NOT NULL,
    bank_code VARCHAR(128) NOT NULL DEFAULT '',
    country VARCHAR(64) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(32) NOT NULL CHECK (status IN ('ACTIVE','SUSPENDED')),
    version BIGINT NOT NULL CHECK (version > 0),
    updated_at VARCHAR(64) NOT NULL,
    PRIMARY KEY (customer_id, beneficiary_id)
);
CREATE INDEX IF NOT EXISTS federationbank_beneficiaries_owner_idx
    ON federationbank_beneficiaries(owner_account_id, status);

CREATE TABLE IF NOT EXISTS federationbank_beneficiary_events (
    event_id VARCHAR(128) PRIMARY KEY,
    customer_id VARCHAR(128) NOT NULL,
    beneficiary_id VARCHAR(128) NOT NULL,
    owner_account_id VARCHAR(128) NOT NULL,
    operation VARCHAR(64) NOT NULL CHECK (operation IN ('ADD_BENEFICIARY','AMEND_BENEFICIARY','SUSPEND_BENEFICIARY')),
    beneficiary_version BIGINT NOT NULL,
    status VARCHAR(32) NOT NULL,
    display_name TEXT NOT NULL,
    account_reference VARCHAR(256) NOT NULL,
    bank_code VARCHAR(128) NOT NULL DEFAULT '',
    country VARCHAR(64) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    security_policy_id VARCHAR(128) NOT NULL,
    security_policy_version VARCHAR(64) NOT NULL,
    security_disposition VARCHAR(32) NOT NULL,
    corporate_policy_id VARCHAR(128) NOT NULL,
    corporate_policy_version VARCHAR(64) NOT NULL,
    corporate_policy_rule_id VARCHAR(128) NOT NULL,
    legal_profile_id VARCHAR(128) NOT NULL,
    legal_generation_id VARCHAR(128) NOT NULL,
    legal_generation_version VARCHAR(64) NOT NULL,
    event_at VARCHAR(64) NOT NULL,
    FOREIGN KEY (customer_id, beneficiary_id) REFERENCES federationbank_beneficiaries(customer_id, beneficiary_id)
);
CREATE INDEX IF NOT EXISTS federationbank_beneficiary_events_history_idx
    ON federationbank_beneficiary_events(customer_id, beneficiary_id, beneficiary_version);

CREATE TABLE IF NOT EXISTS federationbank_transactions (
    transaction_id VARCHAR(128) PRIMARY KEY,
    transaction_kind VARCHAR(64) NOT NULL DEFAULT 'TRANSFER',
    currency VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL DEFAULT '',
    posted_at VARCHAR(64) NOT NULL,
    debit_account_id VARCHAR(128) NOT NULL,
    credit_account_id VARCHAR(128) NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    target_amount_minor BIGINT NOT NULL DEFAULT 0 CHECK (target_amount_minor >= 0),
    fee_amount_minor BIGINT NOT NULL DEFAULT 0 CHECK (fee_amount_minor >= 0),
    fee_account_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_quote_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_rate_numerator BIGINT NOT NULL DEFAULT 0,
    fx_rate_denominator BIGINT NOT NULL DEFAULT 0,
    state VARCHAR(24) NOT NULL CHECK (state = 'COMMITTED')
);

CREATE TABLE IF NOT EXISTS federationbank_ledger_postings (
    posting_id VARCHAR(160) PRIMARY KEY,
    transaction_id VARCHAR(128) NOT NULL REFERENCES federationbank_transactions(transaction_id),
    account_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor <> 0),
    posted_at VARCHAR(64) NOT NULL,
    side VARCHAR(8) NOT NULL CHECK (side IN ('DEBIT','CREDIT')),
    posting_role VARCHAR(64) NOT NULL DEFAULT 'TRANSFER' CHECK (posting_role IN ('TRANSFER','TRANSFER_DEBIT','TRANSFER_CREDIT','FEE_DEBIT','FEE_CREDIT','FX_SOURCE_DEBIT','FX_SOURCE_POSITION_CREDIT','FX_TARGET_POSITION_DEBIT','FX_TARGET_CREDIT','ATM_OFFLINE_WITHDRAWAL_DEBIT','ATM_WITHDRAWAL_DEBIT','ATM_CASH_SETTLEMENT_CREDIT','ATM_CASH_SETTLEMENT_DEBIT','ATM_DEPOSIT_CREDIT'))
);
CREATE INDEX IF NOT EXISTS federationbank_postings_account_idx
    ON federationbank_ledger_postings(account_id, currency, posted_at);
CREATE INDEX IF NOT EXISTS federationbank_postings_transaction_idx
    ON federationbank_ledger_postings(transaction_id);

CREATE TABLE IF NOT EXISTS federationbank_transaction_decisions (
    transaction_id VARCHAR(128) PRIMARY KEY REFERENCES federationbank_transactions(transaction_id),
    security_policy_id VARCHAR(128) NOT NULL,
    security_policy_version VARCHAR(64) NOT NULL,
    security_disposition VARCHAR(32) NOT NULL,
    corporate_policy_id VARCHAR(128) NOT NULL,
    corporate_policy_version VARCHAR(64) NOT NULL,
    corporate_policy_rule_id VARCHAR(128) NOT NULL,
    fee_policy_id VARCHAR(128) NOT NULL DEFAULT '',
    fee_policy_version VARCHAR(64) NOT NULL DEFAULT '',
    fee_policy_rule_id VARCHAR(128) NOT NULL DEFAULT '',
    fee_amount_minor BIGINT NOT NULL DEFAULT 0,
    fee_income_account_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_policy_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_policy_version VARCHAR(64) NOT NULL DEFAULT '',
    fx_policy_rule_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_quote_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_quote_provider_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_markup_basis_points BIGINT NOT NULL DEFAULT 0,
    fx_rate_numerator BIGINT NOT NULL DEFAULT 0,
    fx_rate_denominator BIGINT NOT NULL DEFAULT 0,
    legal_profile_id VARCHAR(128) NOT NULL,
    legal_generation_id VARCHAR(128) NOT NULL,
    legal_generation_version VARCHAR(64) NOT NULL,
    regulatory_profile_id VARCHAR(128) NOT NULL,
    target_legal_profile_id VARCHAR(128) NOT NULL DEFAULT '',
    target_legal_generation_id VARCHAR(128) NOT NULL DEFAULT '',
    target_legal_generation_version VARCHAR(64) NOT NULL DEFAULT '',
    target_regulatory_profile_id VARCHAR(128) NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS federationbank_atm_settlement_evidence (
    transaction_id VARCHAR(128) PRIMARY KEY REFERENCES federationbank_transactions(transaction_id),
    debit_authority VARCHAR(64) NOT NULL CHECK (debit_authority = 'SETTLEMENT_MUST_POST'),
    terminal_id VARCHAR(128) NOT NULL,
    atm_network_id VARCHAR(128) NOT NULL,
    offline_authority_id VARCHAR(128) NOT NULL,
    ruleset_id VARCHAR(128) NOT NULL,
    rules_version VARCHAR(64) NOT NULL,
    physical_transaction_id VARCHAR(160) NOT NULL,
    terminal_sequence BIGINT NOT NULL,
    dispensed_minor BIGINT NOT NULL CHECK (dispensed_minor > 0),
    recorded_at VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS federationbank_atm_physical_evidence (
    transaction_id VARCHAR(128) PRIMARY KEY REFERENCES federationbank_transactions(transaction_id),
    operation VARCHAR(32) NOT NULL CHECK (operation IN ('WITHDRAW_COMMIT','DEPOSIT_COMMIT')),
    terminal_id VARCHAR(128) NOT NULL,
    atm_network_id VARCHAR(128) NOT NULL,
    ruleset_id VARCHAR(128) NOT NULL,
    rules_version VARCHAR(64) NOT NULL,
    physical_transaction_id VARCHAR(160) NOT NULL,
    terminal_sequence BIGINT NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    authorization_id VARCHAR(160) NOT NULL DEFAULT '',
    hold_id VARCHAR(160) NOT NULL DEFAULT '',
    evidence_state VARCHAR(32) NOT NULL,
    recorded_at VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS federationbank_account_opening_decisions (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    command_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    account_id VARCHAR(128) NOT NULL,
    security_policy_id VARCHAR(128) NOT NULL,
    security_policy_version VARCHAR(64) NOT NULL,
    security_disposition VARCHAR(32) NOT NULL,
    corporate_policy_id VARCHAR(128) NOT NULL,
    corporate_policy_version VARCHAR(64) NOT NULL,
    corporate_policy_rule_id VARCHAR(128) NOT NULL,
    legal_profile_id VARCHAR(128) NOT NULL,
    legal_generation_id VARCHAR(128) NOT NULL,
    legal_generation_version VARCHAR(64) NOT NULL,
    regulatory_profile_id VARCHAR(128) NOT NULL,
    address_verification_reference TEXT NOT NULL,
    address_contract_generation VARCHAR(128) NOT NULL,
    address_mapping_generation VARCHAR(128) NOT NULL,
    credit_bureau_reference VARCHAR(256) NOT NULL,
    credit_status VARCHAR(32) NOT NULL,
    credit_score INTEGER NULL,
    outcome VARCHAR(32) NOT NULL CHECK (outcome IN ('ACCEPTED','REFERRED','REJECTED'))
);

-- Durable idempotent result identity.  An accepted state change writes this
-- row in the SAME DB transaction as the customer/account or ledger mutation.

-- Ledger Engine-owned funds reservations.  A hold does not post to the
-- double-entry journal; it reduces available balance while active.
CREATE TABLE IF NOT EXISTS federationbank_holds (
    hold_id VARCHAR(128) PRIMARY KEY,
    account_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    status VARCHAR(24) NOT NULL CHECK (status IN ('ACTIVE','RELEASED')),
    version BIGINT NOT NULL CHECK (version > 0),
    placed_at VARCHAR(64) NOT NULL,
    released_at VARCHAR(64) NULL
);
CREATE INDEX IF NOT EXISTS federationbank_holds_account_idx
    ON federationbank_holds(account_id, status, currency);

CREATE TABLE IF NOT EXISTS federationbank_hold_events (
    event_id VARCHAR(256) PRIMARY KEY,
    hold_id VARCHAR(128) NOT NULL REFERENCES federationbank_holds(hold_id),
    account_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    operation VARCHAR(32) NOT NULL CHECK (operation IN ('PLACE_HOLD','RELEASE_HOLD','CONSUME_HOLD')),
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL CHECK (amount_minor > 0),
    hold_version BIGINT NOT NULL CHECK (hold_version > 0),
    status VARCHAR(24) NOT NULL CHECK (status IN ('ACTIVE','RELEASED')),
    security_policy_id VARCHAR(128) NOT NULL,
    security_policy_version VARCHAR(64) NOT NULL,
    security_disposition VARCHAR(32) NOT NULL,
    corporate_policy_id VARCHAR(128) NOT NULL,
    corporate_policy_version VARCHAR(64) NOT NULL,
    corporate_policy_rule_id VARCHAR(128) NOT NULL,
    legal_profile_id VARCHAR(128) NOT NULL,
    legal_generation_id VARCHAR(128) NOT NULL,
    legal_generation_version VARCHAR(64) NOT NULL,
    event_at VARCHAR(64) NOT NULL
);
CREATE INDEX IF NOT EXISTS federationbank_hold_events_history_idx
    ON federationbank_hold_events(hold_id, hold_version);

CREATE TABLE IF NOT EXISTS federationbank_credit_intelligence_evidence (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    request_id VARCHAR(128) NOT NULL,
    correlation_token VARCHAR(128) NOT NULL,
    bureau_product_id VARCHAR(256) NOT NULL,
    bureau_reference VARCHAR(512) NOT NULL,
    generation_timestamp VARCHAR(64) NOT NULL,
    methodology_version VARCHAR(128) NOT NULL,
    overall_disposition VARCHAR(128) NOT NULL,
    scaled_value VARCHAR(64) NULL,
    scale_direction VARCHAR(128) NOT NULL,
    score_band_label VARCHAR(128) NOT NULL,
    suppression_flags_payload TEXT NOT NULL,
    reason_code_tree_payload TEXT NOT NULL,
    next_permitted_refresh_not_before VARCHAR(64) NOT NULL,
    raw_product_payload TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS federationbank_command_receipts (
    idempotency_key VARCHAR(128) PRIMARY KEY,
    command_id VARCHAR(128) NOT NULL,
    operation VARCHAR(64) NOT NULL,
    outcome_code VARCHAR(32) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    account_id VARCHAR(128) NOT NULL DEFAULT '',
    transaction_id VARCHAR(128) NOT NULL DEFAULT '',
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL DEFAULT 0,
    regulatory_profile_id VARCHAR(128) NOT NULL,
    security_policy_id VARCHAR(128) NOT NULL,
    security_policy_version VARCHAR(64) NOT NULL,
    security_disposition VARCHAR(32) NOT NULL,
    corporate_policy_id VARCHAR(128) NOT NULL,
    corporate_policy_version VARCHAR(64) NOT NULL,
    corporate_policy_rule_id VARCHAR(128) NOT NULL,
    legal_profile_id VARCHAR(128) NOT NULL,
    legal_generation_id VARCHAR(128) NOT NULL,
    legal_generation_version VARCHAR(64) NOT NULL,
    address_verification_reference TEXT NOT NULL DEFAULT '',
    credit_bureau_reference VARCHAR(256) NOT NULL DEFAULT '',
    credit_status VARCHAR(32) NOT NULL DEFAULT '',
    credit_score INTEGER NULL,
    created_at VARCHAR(64) NOT NULL,
    result_payload TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS federationbank_receipts_command_idx
    ON federationbank_command_receipts(command_id);

-- FederationBank IOM Offshore banking engine v0.7 reference schema.
-- All tables use InnoDB so one Engine command can atomically commit every
-- affected row through the ooRexx DB Skeleton transaction boundary.

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
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_accounts (
    account_id VARCHAR(128) PRIMARY KEY,
    customer_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    product_code VARCHAR(128) NOT NULL,
    booking_jurisdiction VARCHAR(64) NOT NULL,
    regulatory_profile_id VARCHAR(128) NOT NULL,
    status VARCHAR(32) NOT NULL,
    opened_at VARCHAR(64) NOT NULL,
    INDEX federationbank_accounts_customer_idx (customer_id, currency, status)
) ENGINE=InnoDB;

-- Account Engine-owned beneficiary master state.  Payments may consume
-- projections but does not own or directly mutate these rows.
CREATE TABLE IF NOT EXISTS federationbank_beneficiaries (
    customer_id VARCHAR(128) NOT NULL,
    beneficiary_id VARCHAR(128) NOT NULL,
    owner_account_id VARCHAR(128) NOT NULL,
    display_name TEXT NOT NULL,
    account_reference VARCHAR(256) NOT NULL,
    bank_code VARCHAR(128) NOT NULL DEFAULT '',
    country VARCHAR(64) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(32) NOT NULL,
    version BIGINT NOT NULL,
    updated_at VARCHAR(64) NOT NULL,
    PRIMARY KEY (customer_id, beneficiary_id),
    CONSTRAINT federationbank_beneficiary_customer_fk FOREIGN KEY (customer_id) REFERENCES federationbank_customers(customer_id),
    CONSTRAINT federationbank_beneficiary_owner_fk FOREIGN KEY (owner_account_id) REFERENCES federationbank_accounts(account_id),
    CHECK (status IN ('ACTIVE','SUSPENDED')),
    CHECK (version > 0),
    INDEX federationbank_beneficiaries_owner_idx (owner_account_id, status)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_beneficiary_events (
    event_id VARCHAR(128) PRIMARY KEY,
    customer_id VARCHAR(128) NOT NULL,
    beneficiary_id VARCHAR(128) NOT NULL,
    owner_account_id VARCHAR(128) NOT NULL,
    operation VARCHAR(64) NOT NULL,
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
    CONSTRAINT federationbank_beneficiary_event_master_fk FOREIGN KEY (customer_id, beneficiary_id)
      REFERENCES federationbank_beneficiaries(customer_id, beneficiary_id),
    CHECK (operation IN ('ADD_BENEFICIARY','AMEND_BENEFICIARY','SUSPEND_BENEFICIARY')),
    INDEX federationbank_beneficiary_events_history_idx (customer_id, beneficiary_id, beneficiary_version)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_transactions (
    transaction_id VARCHAR(128) PRIMARY KEY,
    transaction_kind VARCHAR(64) NOT NULL DEFAULT 'TRANSFER',
    currency VARCHAR(3) NOT NULL,
    target_currency VARCHAR(3) NOT NULL DEFAULT '',
    posted_at VARCHAR(64) NOT NULL,
    debit_account_id VARCHAR(128) NOT NULL,
    credit_account_id VARCHAR(128) NOT NULL,
    amount_minor BIGINT NOT NULL,
    target_amount_minor BIGINT NOT NULL DEFAULT 0,
    fee_amount_minor BIGINT NOT NULL DEFAULT 0,
    fee_account_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_quote_id VARCHAR(128) NOT NULL DEFAULT '',
    fx_rate_numerator BIGINT NOT NULL DEFAULT 0,
    fx_rate_denominator BIGINT NOT NULL DEFAULT 0,
    state VARCHAR(24) NOT NULL,
    CHECK (amount_minor > 0),
    CHECK (target_amount_minor >= 0),
    CHECK (fee_amount_minor >= 0),
    CHECK (state = 'COMMITTED')
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_ledger_postings (
    posting_id VARCHAR(160) PRIMARY KEY,
    transaction_id VARCHAR(128) NOT NULL,
    account_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL,
    posted_at VARCHAR(64) NOT NULL,
    side VARCHAR(8) NOT NULL,
    posting_role VARCHAR(64) NOT NULL DEFAULT 'TRANSFER',
    CONSTRAINT federationbank_postings_tx_fk FOREIGN KEY (transaction_id)
      REFERENCES federationbank_transactions(transaction_id),
    CHECK (amount_minor <> 0),
    CHECK (side IN ('DEBIT','CREDIT')),
    CHECK (posting_role IN ('TRANSFER','TRANSFER_DEBIT','TRANSFER_CREDIT','FEE_DEBIT','FEE_CREDIT','FX_SOURCE_DEBIT','FX_SOURCE_POSITION_CREDIT','FX_TARGET_POSITION_DEBIT','FX_TARGET_CREDIT','ATM_OFFLINE_WITHDRAWAL_DEBIT','ATM_WITHDRAWAL_DEBIT','ATM_CASH_SETTLEMENT_CREDIT','ATM_CASH_SETTLEMENT_DEBIT','ATM_DEPOSIT_CREDIT')),
    INDEX federationbank_postings_account_idx (account_id, currency, posted_at),
    INDEX federationbank_postings_transaction_idx (transaction_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_transaction_decisions (
    transaction_id VARCHAR(128) PRIMARY KEY,
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
    target_regulatory_profile_id VARCHAR(128) NOT NULL DEFAULT '',
    CONSTRAINT federationbank_decision_tx_fk FOREIGN KEY (transaction_id)
      REFERENCES federationbank_transactions(transaction_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_atm_settlement_evidence (
    transaction_id VARCHAR(128) PRIMARY KEY,
    debit_authority VARCHAR(64) NOT NULL,
    terminal_id VARCHAR(128) NOT NULL,
    atm_network_id VARCHAR(128) NOT NULL,
    offline_authority_id VARCHAR(128) NOT NULL,
    ruleset_id VARCHAR(128) NOT NULL,
    rules_version VARCHAR(64) NOT NULL,
    physical_transaction_id VARCHAR(160) NOT NULL,
    terminal_sequence BIGINT NOT NULL,
    dispensed_minor BIGINT NOT NULL,
    recorded_at VARCHAR(64) NOT NULL,
    CONSTRAINT federationbank_atm_evidence_tx_fk FOREIGN KEY (transaction_id)
      REFERENCES federationbank_transactions(transaction_id),
    CHECK (debit_authority = 'SETTLEMENT_MUST_POST'),
    CHECK (dispensed_minor > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_atm_physical_evidence (
    transaction_id VARCHAR(128) PRIMARY KEY,
    operation VARCHAR(32) NOT NULL,
    terminal_id VARCHAR(128) NOT NULL,
    atm_network_id VARCHAR(128) NOT NULL,
    ruleset_id VARCHAR(128) NOT NULL,
    rules_version VARCHAR(64) NOT NULL,
    physical_transaction_id VARCHAR(160) NOT NULL,
    terminal_sequence BIGINT NOT NULL,
    amount_minor BIGINT NOT NULL,
    authorization_id VARCHAR(160) NOT NULL DEFAULT '',
    hold_id VARCHAR(160) NOT NULL DEFAULT '',
    evidence_state VARCHAR(32) NOT NULL,
    recorded_at VARCHAR(64) NOT NULL,
    CONSTRAINT federationbank_atm_physical_tx_fk FOREIGN KEY (transaction_id)
      REFERENCES federationbank_transactions(transaction_id),
    CHECK (operation IN ('WITHDRAW_COMMIT','DEPOSIT_COMMIT')),
    CHECK (amount_minor > 0)
) ENGINE=InnoDB;

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
    outcome VARCHAR(32) NOT NULL,
    CHECK (outcome IN ('ACCEPTED','REFERRED','REJECTED'))
) ENGINE=InnoDB;


-- Ledger Engine-owned funds reservations.  Holds affect available balance,
-- not book balance, and therefore are not double-entry postings.
CREATE TABLE IF NOT EXISTS federationbank_holds (
    hold_id VARCHAR(128) PRIMARY KEY,
    account_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL,
    status VARCHAR(24) NOT NULL,
    version BIGINT NOT NULL,
    placed_at VARCHAR(64) NOT NULL,
    released_at VARCHAR(64) NULL,
    CHECK (amount_minor > 0),
    CHECK (status IN ('ACTIVE','RELEASED')),
    CHECK (version > 0),
    INDEX federationbank_holds_account_idx (account_id, status, currency)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS federationbank_hold_events (
    event_id VARCHAR(256) PRIMARY KEY,
    hold_id VARCHAR(128) NOT NULL,
    account_id VARCHAR(128) NOT NULL,
    customer_id VARCHAR(128) NOT NULL,
    operation VARCHAR(32) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    amount_minor BIGINT NOT NULL,
    hold_version BIGINT NOT NULL,
    status VARCHAR(24) NOT NULL,
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
    CONSTRAINT federationbank_hold_event_hold_fk FOREIGN KEY (hold_id)
      REFERENCES federationbank_holds(hold_id),
    CHECK (operation IN ('PLACE_HOLD','RELEASE_HOLD','CONSUME_HOLD')),
    CHECK (amount_minor > 0),
    CHECK (hold_version > 0),
    CHECK (status IN ('ACTIVE','RELEASED')),
    INDEX federationbank_hold_events_history_idx (hold_id, hold_version)
) ENGINE=InnoDB;

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
) ENGINE=InnoDB;

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
    address_verification_reference TEXT NOT NULL,
    credit_bureau_reference VARCHAR(256) NOT NULL DEFAULT '',
    credit_status VARCHAR(32) NOT NULL DEFAULT '',
    credit_score INTEGER NULL,
    created_at VARCHAR(64) NOT NULL,
    result_payload LONGTEXT NOT NULL,
    INDEX federationbank_receipts_command_idx (command_id)
) ENGINE=InnoDB;

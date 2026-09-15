package com.federationbank.atm.bank;

/**
 * Public, non-secret compatibility constants for the FederationBank v0.8 ATM demo gateway.
 *
 * The key is the X.509 SubjectPublicKeyInfo Ed25519 verification key shipped by the bank's
 * v0.8 fixture.  It is safe to distribute because it is a public verification key.  A real
 * deployment should provision its own bank rule-verification key through configuration.
 */
public final class FederationBankV08Profile {
    public static final String ENGINE_VERSION = "0.8";
    public static final String PROTOCOL_VERSION = "0.1";
    public static final String REQUEST_SCHEMA = "federationbank.atm.request/0.1";
    public static final String RESPONSE_SCHEMA = "federationbank.atm.response/0.1";
    public static final String RULES_SCHEMA = "federationbank.atm.rules/0.1";
    public static final String DEMO_RULESET_ID = "FB-ATM-IOM-DEMO";
    public static final long DEMO_RULES_VERSION = 1L;
    public static final String DEMO_RULE_KEY_ID = "FB-ATM-RULE-KEY-1";
    public static final String DEMO_RULE_PUBLIC_KEY_SPKI_BASE64 =
            "MCowBQYDK2VwAyEA7ndT6feJnfYbd0LC1yXNu1R3QGwUJsCa/+kuZKUp0MU=";

    private FederationBankV08Profile() {}
}

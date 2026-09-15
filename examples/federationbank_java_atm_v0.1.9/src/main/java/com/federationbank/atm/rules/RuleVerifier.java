package com.federationbank.atm.rules;

import com.federationbank.atm.protocol.Json;

import java.nio.charset.StandardCharsets;
import java.security.PublicKey;
import java.security.Signature;
import java.util.Base64;
import java.util.Map;

/** Verifies bank-signed ATM policy documents. Invalid rules are never partially applied. */
public final class RuleVerifier {
    private final PublicKey bankPublicKey;

    public RuleVerifier(PublicKey bankPublicKey) { this.bankPublicKey = bankPublicKey; }

    public boolean verify(Map<String, Object> rules, String signatureBase64, String algorithm) {
        try {
            if (!"Ed25519".equalsIgnoreCase(algorithm)) return false;
            Signature sig = Signature.getInstance("Ed25519");
            sig.initVerify(bankPublicKey);
            sig.update(Json.canonical(rules).getBytes(StandardCharsets.UTF_8));
            return sig.verify(Base64.getDecoder().decode(signatureBase64));
        } catch (Exception e) {
            return false;
        }
    }
}

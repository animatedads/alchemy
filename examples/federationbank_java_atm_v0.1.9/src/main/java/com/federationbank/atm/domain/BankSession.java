package com.federationbank.atm.domain;

import java.time.Instant;

public record BankSession(String sessionId, String customerId, String customerDisplayName, Instant expiresAt) {
    public boolean expired() { return expiresAt != null && !Instant.now().isBefore(expiresAt); }
}

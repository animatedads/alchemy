package com.federationbank.atm.domain;

import java.time.Instant;

public record Balance(String accountId, String currency, long bookBalanceMinor, long heldMinor,
                      long availableBalanceMinor, Instant asOf, boolean stale) {}

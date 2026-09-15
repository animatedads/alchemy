package com.federationbank.atm.brokerage;

import java.time.Instant;

/**
 * Narrow read-only projection supplied by the brokerage authority for ATM display.
 *
 * <p>This is deliberately not a bank account balance and deliberately does not
 * expose the brokerage's internal trade/position object model.</p>
 */
public record MerchantPositionSummary(
        String relationshipId,
        String currency,
        Instant valuationTime,
        long netMarketValueMinor,
        long unrealisedPnlMinor,
        long realisedPnlMinor,
        long collateralMinor,
        long marginRequiredMinor,
        long availableMarginMinor,
        int positionCount,
        String valuationStatus,
        String sourceAuthority) {

    public MerchantPositionSummary {
        relationshipId = requireText(relationshipId, "relationshipId");
        currency = requireText(currency, "currency").toUpperCase();
        if (currency.length() != 3) throw new IllegalArgumentException("currency must be a three-letter code");
        if (valuationTime == null) throw new IllegalArgumentException("valuationTime is required");
        if (collateralMinor < 0) throw new IllegalArgumentException("collateralMinor cannot be negative");
        if (marginRequiredMinor < 0) throw new IllegalArgumentException("marginRequiredMinor cannot be negative");
        if (availableMarginMinor < 0) throw new IllegalArgumentException("availableMarginMinor cannot be negative");
        if (positionCount < 0) throw new IllegalArgumentException("positionCount cannot be negative");
        valuationStatus = requireText(valuationStatus, "valuationStatus").toUpperCase();
        sourceAuthority = requireText(sourceAuthority, "sourceAuthority");
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(field + " is required");
        return value;
    }
}

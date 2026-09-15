package com.federationbank.atm.brokerage;

import com.federationbank.atm.domain.BankSession;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Read-only cross-perimeter brokerage client used by the ATM.
 *
 * <p>The ATM supplies authenticated retail-bank customer/session context but no
 * brokerage account identifier.  Brokerage owns customer-to-relationship linkage
 * and returns only the purpose-built summary projection.</p>
 */
public final class BrokerageService implements AutoCloseable {
    static final String REQUEST_SCHEMA = "federationbank.brokerage.atm.request/0.1";
    static final String RESPONSE_SCHEMA = "federationbank.brokerage.atm.response/0.1";
    static final String OPERATION = "GET_MERCHANT_POSITION_SUMMARY";

    private final String terminalId;
    private final BrokerageNetwork network;

    public BrokerageService(String terminalId, BrokerageNetwork network) {
        this.terminalId = terminalId;
        this.network = network;
    }

    public boolean configured() { return network != null; }
    public boolean isOnline() { return network != null && network.isOnline(); }

    public Optional<MerchantPositionSummary> currentMerchantPosition(BankSession session)
            throws BrokerageNetworkException {
        if (network == null) throw new BrokerageNetworkException("brokerage service is not configured");
        if (session == null || session.expired()) throw new BrokerageNetworkException("bank customer session is not active");

        String commandId = "BRKPOS-" + UUID.randomUUID();
        BrokerageRequest request = new BrokerageRequest(
                REQUEST_SCHEMA,
                commandId,
                OPERATION,
                terminalId,
                session.sessionId(),
                session.customerId(),
                Instant.now().truncatedTo(ChronoUnit.MILLIS));

        BrokerageResponse response = network.exchange(request);
        validateEnvelope(request, response);
        if (!response.ok()) {
            if (response.code().equals("NO_LINKED_BROKERAGE_ACCOUNT")) return Optional.empty();
            throw new BrokerageNetworkException(response.code() + ": " + response.detail());
        }

        try {
            Map<String,Object> d = response.data();
            MerchantPositionSummary summary = new MerchantPositionSummary(
                    requiredString(d, "relationshipId"),
                    requiredString(d, "currency"),
                    Instant.parse(requiredString(d, "valuationTime")),
                    number(d, "netMarketValueMinor"),
                    number(d, "unrealisedPnlMinor"),
                    number(d, "realisedPnlMinor"),
                    number(d, "collateralMinor"),
                    number(d, "marginRequiredMinor"),
                    number(d, "availableMarginMinor"),
                    Math.toIntExact(number(d, "positionCount")),
                    requiredString(d, "valuationStatus"),
                    requiredString(d, "sourceAuthority"));
            return Optional.of(summary);
        } catch (RuntimeException e) {
            throw new BrokerageNetworkException("invalid brokerage position summary: " + e.getMessage(), e);
        }
    }

    private void validateEnvelope(BrokerageRequest request, BrokerageResponse response)
            throws BrokerageNetworkException {
        if (!request.commandId().equals(response.commandId()))
            throw new BrokerageNetworkException("brokerage response correlation mismatch");
        if (!RESPONSE_SCHEMA.equals(response.schema()))
            throw new BrokerageNetworkException("unsupported brokerage response schema: " + response.schema());
        if (!OPERATION.equals(response.operation()))
            throw new BrokerageNetworkException("brokerage response operation mismatch");
        if (!terminalId.equals(response.terminalId()))
            throw new BrokerageNetworkException("brokerage response terminal mismatch");
    }

    private static String requiredString(Map<String,Object> m, String key) {
        Object raw = m.get(key);
        String value = raw == null ? "" : String.valueOf(raw);
        if (value.isBlank()) throw new IllegalArgumentException("missing " + key);
        return value;
    }

    private static long number(Map<String,Object> m, String key) {
        Object raw = m.get(key);
        if (raw instanceof Number n) return n.longValue();
        if (raw == null) throw new IllegalArgumentException("missing " + key);
        return Long.parseLong(String.valueOf(raw));
    }

    @Override public void close() { if (network != null) network.close(); }
}

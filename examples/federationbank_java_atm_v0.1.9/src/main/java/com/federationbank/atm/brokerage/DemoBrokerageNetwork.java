package com.federationbank.atm.brokerage;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Stand-alone demo brokerage authority.
 *
 * <p>It deliberately owns its own retail-customer linkage and returns only the
 * narrow ATM summary.  The underlying position/trade model is not exposed to
 * the ATM.</p>
 */
public final class DemoBrokerageNetwork implements BrokerageNetwork {
    private volatile boolean online = true;

    public void setOnline(boolean online) { this.online = online; }
    @Override public boolean isOnline() { return online; }

    @Override public BrokerageResponse exchange(BrokerageRequest request) throws BrokerageNetworkException {
        if (!online) throw new BrokerageNetworkException("demo brokerage network is offline");
        if (!BrokerageService.REQUEST_SCHEMA.equals(request.schema()))
            return response(request, false, "SCHEMA_UNSUPPORTED", request.schema(), Map.of());
        if (!BrokerageService.OPERATION.equals(request.operation()))
            return response(request, false, "OPERATION_UNSUPPORTED", request.operation(), Map.of());

        /* CUST-002 happens to have a separate retail brokerage relationship.
         * The ATM did not supply BRK-RET-0002 and cannot choose a different one. */
        if (!"CUST-002".equals(request.customerId()))
            return response(request, false, "NO_LINKED_BROKERAGE_ACCOUNT", "No linked retail brokerage account", Map.of());

        Map<String,Object> data = new LinkedHashMap<>();
        data.put("relationshipId", "BRK-RET-0002");
        data.put("currency", "AUD");
        data.put("valuationTime", Instant.now().truncatedTo(ChronoUnit.MILLIS).toString());
        data.put("netMarketValueMinor", 7_244_000L);       // AUD 72,440.00
        data.put("unrealisedPnlMinor", 321_500L);         // +AUD 3,215.00
        data.put("realisedPnlMinor", 84_000L);            // +AUD 840.00
        data.put("collateralMinor", 950_000L);            // AUD 9,500.00
        data.put("marginRequiredMinor", 538_000L);        // AUD 5,380.00
        data.put("availableMarginMinor", 412_000L);       // AUD 4,120.00
        data.put("positionCount", 2L);
        data.put("valuationStatus", "CURRENT");
        data.put("sourceAuthority", "FEDERATION_BROKERAGE_POSITION_AUTHORITY");
        return response(request, true, "MERCHANT_POSITION_CURRENT", "Current brokerage derivatives position summary", data);
    }

    private static BrokerageResponse response(BrokerageRequest request, boolean ok, String code,
                                               String detail, Map<String,Object> data) {
        return new BrokerageResponse(
                BrokerageService.RESPONSE_SCHEMA,
                request.commandId(), request.operation(), request.terminalId(), ok, code, detail,
                Instant.now().truncatedTo(ChronoUnit.MILLIS), data);
    }
}

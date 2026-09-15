package com.federationbank.atm.protocol;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.Map;

public record BankRequest(
        String schema,
        String commandId,
        String idempotencyKey,
        String operation,
        String terminalId,
        long terminalSequence,
        String sessionId,
        Instant requestedAt,
        String rulesetId,
        long rulesVersion,
        Map<String, Object> data) {

    public BankRequest {
        data = data == null ? Map.of() : Map.copyOf(data);
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("schema", schema);
        m.put("commandId", commandId);
        m.put("idempotencyKey", idempotencyKey);
        m.put("operation", operation);
        m.put("terminalId", terminalId);
        m.put("terminalSequence", terminalSequence);
        m.put("sessionId", sessionId == null ? "" : sessionId);
        /* FederationBank's ooRexx DateTime ISO parser accepts fractional seconds
         * through microsecond precision.  Milliseconds are ample for ATM request
         * ordering; terminalSequence/idempotencyKey provide the durable identity. */
        m.put("requestedAt", requestedAt.truncatedTo(ChronoUnit.MILLIS).toString());
        m.put("rulesetId", rulesetId == null ? "" : rulesetId);
        m.put("rulesVersion", rulesVersion);
        m.put("data", data);
        return m;
    }

    public String toJson() { return Json.stringify(toMap()); }
}

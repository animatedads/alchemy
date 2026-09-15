package com.federationbank.atm.journal;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

public record JournalEvent(Instant at, String transactionId, String kind, String state,
                           String commandId, String idempotencyKey, Map<String, Object> data) {
    public JournalEvent { data = data == null ? Map.of() : Map.copyOf(data); }
    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("schema", "federationbank.atm.journal-event/0.1");
        m.put("at", at.toString()); m.put("transactionId", transactionId); m.put("kind", kind); m.put("state", state);
        m.put("commandId", commandId == null ? "" : commandId);
        m.put("idempotencyKey", idempotencyKey == null ? "" : idempotencyKey);
        m.put("data", data);
        return m;
    }
}

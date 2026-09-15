package com.federationbank.atm.brokerage;

import com.federationbank.atm.protocol.Json;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

/** Separate brokerage wire envelope. It deliberately does not reuse the bank ATM command schema. */
public record BrokerageRequest(
        String schema,
        String commandId,
        String operation,
        String terminalId,
        String bankSessionId,
        String customerId,
        Instant requestedAt) {
    public String toJson() {
        Map<String,Object> m=new LinkedHashMap<>();
        m.put("schema",schema); m.put("commandId",commandId); m.put("operation",operation);
        m.put("terminalId",terminalId); m.put("bankSessionId",bankSessionId); m.put("customerId",customerId);
        m.put("requestedAt",requestedAt.toString());
        return Json.stringify(m);
    }
}

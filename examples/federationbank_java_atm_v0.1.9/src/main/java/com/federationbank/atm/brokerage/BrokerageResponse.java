package com.federationbank.atm.brokerage;

import com.federationbank.atm.protocol.Json;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

public record BrokerageResponse(
        String schema,
        String commandId,
        String operation,
        String terminalId,
        boolean ok,
        String code,
        String detail,
        Instant brokerageTime,
        Map<String,Object> data) {
    @SuppressWarnings("unchecked")
    public static BrokerageResponse fromJson(String json) {
        Object raw=Json.parse(json);
        if (!(raw instanceof Map<?,?> x)) throw new IllegalArgumentException("brokerage response must be a JSON object");
        Map<String,Object> m=(Map<String,Object>)x;
        Object d=m.get("data");
        Map<String,Object> data=d instanceof Map<?,?> dm ? (Map<String,Object>)dm : Map.of();
        return new BrokerageResponse(s(m,"schema"),s(m,"commandId"),s(m,"operation"),s(m,"terminalId"),
                Boolean.TRUE.equals(m.get("ok")),s(m,"code"),s(m,"detail"),Instant.parse(s(m,"brokerageTime")),data);
    }
    public String toJson() {
        Map<String,Object> m=new LinkedHashMap<>();
        m.put("schema",schema); m.put("commandId",commandId); m.put("operation",operation); m.put("terminalId",terminalId);
        m.put("ok",ok); m.put("code",code); m.put("detail",detail); m.put("brokerageTime",brokerageTime.toString()); m.put("data",data);
        return Json.stringify(m);
    }
    private static String s(Map<String,Object> m,String k){return String.valueOf(m.getOrDefault(k,""));}
}

package com.federationbank.atm.protocol;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

public record BankResponse(
        String schema,
        String commandId,
        String operation,
        String terminalId,
        boolean ok,
        String code,
        String detail,
        Instant bankTime,
        Map<String, Object> data) {

    public BankResponse {
        data = data == null ? Map.of() : Map.copyOf(data);
    }

    public static BankResponse success(BankRequest req, String code, String detail, Map<String, Object> data) {
        return new BankResponse("federationbank.atm.response/0.1", req.commandId(), req.operation(), req.terminalId(),
                true, code, detail == null ? "" : detail, Instant.now(), data);
    }

    public static BankResponse failure(BankRequest req, String code, String detail) {
        return new BankResponse("federationbank.atm.response/0.1", req.commandId(), req.operation(), req.terminalId(),
                false, code, detail == null ? "" : detail, Instant.now(), Map.of());
    }

    @SuppressWarnings("unchecked")
    public static BankResponse fromJson(String json) {
        Map<String, Object> m = Json.parseObject(json);
        Object data = m.get("data");
        return new BankResponse(
                s(m, "schema"), s(m, "commandId"), s(m, "operation"), s(m, "terminalId"),
                b(m, "ok"), s(m, "code"), s(m, "detail"), Instant.parse(s(m, "bankTime")),
                data instanceof Map<?, ?> ? (Map<String, Object>) data : Map.of());
    }

    public Map<String, Object> toMap() {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("schema", schema); m.put("commandId", commandId); m.put("operation", operation);
        m.put("terminalId", terminalId); m.put("ok", ok); m.put("code", code); m.put("detail", detail);
        m.put("bankTime", bankTime.toString()); m.put("data", data);
        return m;
    }

    public String toJson() { return Json.stringify(toMap()); }

    private static String s(Map<String, Object> m, String key) { return String.valueOf(m.getOrDefault(key, "")); }
    private static boolean b(Map<String, Object> m, String key) {
        Object v = m.get(key); return v instanceof Boolean x ? x : Boolean.parseBoolean(String.valueOf(v));
    }
}

package com.federationbank.atm.domain;

import java.time.Instant;
import java.util.Map;

public record AtmRules(
        String rulesetId,
        long version,
        Instant issuedAt,
        Instant validFrom,
        Instant validUntil,
        boolean onlineBalance,
        boolean onlineWithdrawal,
        boolean onlineDeposit,
        String offlineBalanceMode,
        String offlineWithdrawalMode,
        String offlineDepositMode,
        long maxWithdrawalMinor,
        long maxDepositMinor,
        long sessionTimeoutSeconds,
        Map<String, Object> raw) {

    public boolean currentlyValid() {
        Instant now = Instant.now();
        return !now.isBefore(validFrom) && now.isBefore(validUntil);
    }

    @SuppressWarnings("unchecked")
    public static AtmRules fromMap(Map<String, Object> m) {
        Map<String, Object> online = (Map<String, Object>) m.getOrDefault("online", Map.of());
        Map<String, Object> offline = (Map<String, Object>) m.getOrDefault("offline", Map.of());
        Map<String, Object> limits = (Map<String, Object>) m.getOrDefault("limits", Map.of());
        return new AtmRules(
                s(m, "rulesetId"), n(m, "version"), Instant.parse(s(m, "issuedAt")),
                Instant.parse(s(m, "validFrom")), Instant.parse(s(m, "validUntil")),
                b(online, "balance"), b(online, "withdrawal"), b(online, "deposit"),
                s(offline, "balanceMode"), s(offline, "withdrawalMode"), s(offline, "depositMode"),
                n(limits, "maxWithdrawalMinor"), n(limits, "maxDepositMinor"), n(limits, "sessionTimeoutSeconds"),
                Map.copyOf(m));
    }

    private static String s(Map<String, Object> m, String k) { return String.valueOf(m.getOrDefault(k, "")); }
    private static boolean b(Map<String, Object> m, String k) {
        Object v = m.get(k); return v instanceof Boolean x ? x : Boolean.parseBoolean(String.valueOf(v));
    }
    private static long n(Map<String, Object> m, String k) {
        Object v = m.get(k); return v instanceof Number x ? x.longValue() : Long.parseLong(String.valueOf(v));
    }
}

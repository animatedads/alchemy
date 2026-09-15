package com.federationbank.atm.bank;

import com.federationbank.atm.protocol.BankRequest;
import com.federationbank.atm.protocol.BankResponse;
import com.federationbank.atm.protocol.Json;

import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.security.Signature;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Queue;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-process bank-network simulator. It is deliberately behind the same BankNetwork
 * boundary as real JMS, so console/application code cannot special-case fake banking.
 */
public final class DemoBankNetwork implements BankNetwork {
    private final KeyPair ruleKeyPair;
    private final Map<String, Customer> customersByCard = new LinkedHashMap<>();
    private final Map<String, Account> accounts = new LinkedHashMap<>();
    private final Map<String, String> sessions = new ConcurrentHashMap<>();
    private final Map<String, Hold> holds = new ConcurrentHashMap<>();
    private final Map<String, BankResponse> idempotent = new ConcurrentHashMap<>();
    private final Map<String, OfflineAuthority> offlineAuthorities = new ConcurrentHashMap<>();
    private final Map<String, Long> committedWithdrawals = new ConcurrentHashMap<>();
    private final Map<String, Long> committedDeposits = new ConcurrentHashMap<>();
    private final Queue<BankResponse> ruleUpdates = new ArrayDeque<>();
    private volatile boolean online = true;
    private volatile Map<String, Object> currentRules;

    public DemoBankNetwork() {
        try {
            KeyPairGenerator gen = KeyPairGenerator.getInstance("Ed25519");
            ruleKeyPair = gen.generateKeyPair();
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
        Customer one = new Customer("4111111111111111", "1234", "CUST-001", "Existing Customer");
        Customer two = new Customer("5555555555554444", "4321", "CUST-002", "Existing Australian Customer");
        customersByCard.put(one.cardId, one);
        customersByCard.put(two.cardId, two);
        accounts.put("GBP-001", new Account("GBP-001", "CUST-001", "Current Account", "OFFSHORE_CURRENT", "GBP", 125_000));
        accounts.put("GBP-002", new Account("GBP-002", "CUST-001", "Savings Account", "OFFSHORE_SAVER", "GBP", 250_000));
        accounts.put("AUD-001", new Account("AUD-001", "CUST-002", "Current Account", "OFFSHORE_CURRENT", "AUD", 410_000));
        currentRules = makeRules(1, "BANK_ISSUED_AUTHORITY", "CAPTURE_AND_QUEUE");
    }

    public PublicKey rulesPublicKey() { return ruleKeyPair.getPublic(); }
    public void setOnline(boolean online) { this.online = online; }
    @Override public boolean isOnline() { return online; }

    public synchronized void publishRules(String offlineWithdrawalMode, String offlineDepositMode) {
        long next = ((Number) currentRules.get("version")).longValue() + 1;
        currentRules = makeRules(next, offlineWithdrawalMode, offlineDepositMode);
        ruleUpdates.offer(signedRulesResponse(null, "RULES_UPDATE"));
    }

    public long accountBookBalance(String accountId) { return accounts.get(accountId).bookMinor; }
    public long accountHeldMinor(String accountId) {
        return holds.values().stream().filter(h -> h.accountId.equals(accountId) && h.active).mapToLong(h -> h.amountMinor).sum();
    }
    public long accountAvailableBalance(String accountId) { return accountBookBalance(accountId) - accountHeldMinor(accountId); }
    public long committedWithdrawalCount() { return committedWithdrawals.size(); }
    public long committedDepositCount() { return committedDeposits.size(); }

    @Override
    public synchronized BankResponse exchange(BankRequest req) throws BankNetworkException {
        if (!online) throw new BankNetworkException("demo bank network is offline");
        if (req.idempotencyKey() != null && !req.idempotencyKey().isBlank()) {
            BankResponse previous = idempotent.get(req.idempotencyKey());
            if (previous != null) return previous;
        }
        BankResponse response = switch (req.operation()) {
            case "TERMINAL_SIGN_ON" -> ok(req, "TERMINAL_ACCEPTED", Map.of(
                    "protocolVersion", "0.1", "terminalStatus", "ACTIVE"));
            case "GET_RULES" -> signedRulesResponse(req, "RULES_CURRENT");
            case "LOGON" -> logon(req);
            case "LOGOFF" -> logoff(req);
            case "LIST_ACCOUNTS" -> listAccounts(req);
            case "GET_BALANCE" -> balance(req);
            case "GET_OFFLINE_ALLOWANCE" -> getOfflineAllowance(req);
            case "RELEASE_OFFLINE_ALLOWANCE" -> releaseOfflineAllowance(req);
            case "WITHDRAW_AUTHORISE" -> withdrawAuthorise(req);
            case "WITHDRAW_COMMIT" -> withdrawCommit(req);
            case "WITHDRAW_CANCEL" -> withdrawCancel(req);
            case "WITHDRAW_EXCEPTION" -> ok(req, "WITHDRAW_EXCEPTION_RECORDED", Map.of());
            case "DEPOSIT_COMMIT" -> depositCommit(req);
            case "GET_TRANSACTION_STATUS" -> transactionStatus(req);
            case "OFFLINE_WITHDRAWAL_ADVICE" -> offlineWithdrawalAdvice(req);
            default -> fail(req, "OPERATION_UNSUPPORTED", req.operation());
        };
        if (req.idempotencyKey() != null && !req.idempotencyKey().isBlank()
                && isStateChanging(req.operation())) idempotent.put(req.idempotencyKey(), response);
        return response;
    }

    @Override
    public synchronized BankResponse pollRuleUpdate(long timeoutMillis) {
        return ruleUpdates.poll();
    }

    private static boolean isStateChanging(String op) {
        return op.equals("GET_OFFLINE_ALLOWANCE") || op.equals("RELEASE_OFFLINE_ALLOWANCE") || op.equals("OFFLINE_WITHDRAWAL_ADVICE") || op.equals("WITHDRAW_AUTHORISE") || op.equals("WITHDRAW_COMMIT") || op.equals("WITHDRAW_CANCEL")
                || op.equals("DEPOSIT_COMMIT") || op.equals("LOGOFF");
    }

    private BankResponse logon(BankRequest req) {
        String card = s(req.data(), "cardId");
        String pin = s(req.data(), "credential");
        Customer c = customersByCard.get(card);
        if (c == null || !c.pin.equals(pin)) return fail(req, "AUTHENTICATION_FAILED", "card/PIN not accepted");
        String session = "SESSION-" + UUID.randomUUID();
        sessions.put(session, c.customerId);
        return ok(req, "LOGON_ACCEPTED", Map.of(
                "sessionId", session,
                "customerId", c.customerId,
                "customerDisplayName", c.name,
                "sessionExpiresAt", Instant.now().plus(10, ChronoUnit.MINUTES).toString()));
    }

    private BankResponse logoff(BankRequest req) {
        sessions.remove(req.sessionId());
        return ok(req, "LOGOFF_ACCEPTED", Map.of());
    }

    private BankResponse listAccounts(BankRequest req) {
        String customer = sessionCustomer(req);
        if (customer == null) return fail(req, "SESSION_INVALID", "logon required");
        List<Map<String, Object>> list = new ArrayList<>();
        for (Account a : accounts.values()) if (a.customerId.equals(customer)) list.add(Map.of(
                "accountId", a.id, "displayName", a.displayName, "productCode", a.productCode,
                "currency", a.currency, "status", "OPEN"));
        return ok(req, "ACCOUNTS_RETURNED", Map.of("accounts", list));
    }

    private BankResponse balance(BankRequest req) {
        Account a = ownedAccount(req, s(req.data(), "accountId"));
        if (a == null) return fail(req, "ACCOUNT_NOT_FOUND_OR_NOT_OWNED", "account unavailable");
        long held = holds.values().stream().filter(h -> h.accountId.equals(a.id) && h.active).mapToLong(h -> h.amountMinor).sum();
        return ok(req, "BALANCE_RETURNED", Map.of(
                "accountId", a.id, "currency", a.currency, "bookBalanceMinor", a.bookMinor,
                "heldMinor", held, "availableBalanceMinor", a.bookMinor - held, "asOf", Instant.now().toString()));
    }

    private BankResponse getOfflineAllowance(BankRequest req) {
        Account a = ownedAccount(req, s(req.data(), "accountId"));
        if (a == null) return fail(req, "ACCOUNT_NOT_FOUND_OR_NOT_OWNED", "account unavailable");
        long amount = n(req.data(), "amountMinor");
        String mode = s(req.data(), "authorityMode");
        if (!mode.equals("RESERVED_ALLOWANCE") && !mode.equals("DELEGATED_STAND_IN")) return fail(req,"OFFLINE_AUTHORITY_MODE_INVALID",mode);
        String holdId = "";
        if (mode.equals("RESERVED_ALLOWANCE")) {
            long held = holds.values().stream().filter(h -> h.accountId.equals(a.id) && h.active).mapToLong(h -> h.amountMinor).sum();
            if (a.bookMinor - held < amount) return fail(req,"INSUFFICIENT_AVAILABLE_FUNDS","available funds too low");
            holdId = "ATM-OFFLINE-HOLD-" + req.idempotencyKey();
            holds.putIfAbsent(holdId,new Hold(holdId,"OFFAUTH-"+req.idempotencyKey(),a.id,amount));
        }
        String id="OFFAUTH-"+req.idempotencyKey();
        OfflineAuthority oa=new OfflineAuthority(id,mode,req.terminalId(),sessionCustomer(req),a.id,a.currency,amount,holdId,req.rulesetId(),req.rulesVersion(),Instant.now().plus(10,ChronoUnit.MINUTES));
        offlineAuthorities.putIfAbsent(id,oa);
        Map<String,Object> d=new LinkedHashMap<>();
        d.put("schema","federationbank.atm.offline-authority/0.9"); d.put("offlineAuthorityId",id); d.put("authorityMode",mode);
        d.put("terminalId",req.terminalId()); d.put("customerId",oa.customerId); d.put("accountId",a.id); d.put("currency",a.currency);
        d.put("maxAmountMinor",amount); d.put("holdId",holdId); d.put("rulesetId",req.rulesetId()); d.put("rulesVersion",req.rulesVersion());
        d.put("issuedAt",Instant.now().toString()); d.put("expiresAt",oa.expiresAt.toString()); d.put("status","ACTIVE"); d.put("singleUse","true");
        return ok(req,mode.equals("RESERVED_ALLOWANCE")?"OFFLINE_RESERVED_ALLOWANCE_ISSUED":"OFFLINE_STANDIN_AUTHORITY_ISSUED",d);
    }

    private BankResponse releaseOfflineAllowance(BankRequest req) {
        String customer = sessionCustomer(req);
        if (customer == null) return fail(req,"SESSION_INVALID","logon required");
        OfflineAuthority oa=offlineAuthorities.get(s(req.data(),"offlineAuthorityId"));
        if (oa==null) return fail(req,"ATM_OFFLINE_AUTHORITY_UNKNOWN","");
        if (!oa.terminalId.equals(req.terminalId()) || !oa.customerId.equals(customer))
            return fail(req,"ATM_OFFLINE_AUTHORITY_RELEASE_BINDING_MISMATCH","");
        if (oa.consumed) return fail(req,"ATM_OFFLINE_AUTHORITY_ALREADY_CONSUMED",oa.id);
        if (oa.released) {
            if (req.idempotencyKey().equals(oa.releaseIdempotencyKey))
                return ok(req,"OFFLINE_ALLOWANCE_RELEASED",Map.of("offlineAuthorityId",oa.id,"holdId",oa.holdId,"authorityMode",oa.mode));
            return fail(req,"ATM_OFFLINE_AUTHORITY_ALREADY_RELEASED",oa.id);
        }
        if (oa.mode.equals("RESERVED_ALLOWANCE")) {
            Hold h=holds.get(oa.holdId);
            if (h!=null && h.active) h.active=false;
        }
        oa.released=true;
        oa.releaseIdempotencyKey=req.idempotencyKey();
        return ok(req,"OFFLINE_ALLOWANCE_RELEASED",Map.of("offlineAuthorityId",oa.id,"holdId",oa.holdId,"authorityMode",oa.mode));
    }

    private BankResponse offlineWithdrawalAdvice(BankRequest req) {
        OfflineAuthority oa=offlineAuthorities.get(s(req.data(),"offlineAuthorityId"));
        if (oa==null) return fail(req,"ATM_OFFLINE_AUTHORITY_UNKNOWN","");
        long amount=n(req.data(),"amountMinor");
        long dispensed = req.data().containsKey("dispensedMinor") ? n(req.data(),"dispensedMinor") : amount;
        String physicalTransactionId = s(req.data(),"physicalTransactionId");
        if (dispensed != amount) return fail(req,"ATM_OFFLINE_DISPENSE_AMOUNT_MISMATCH","amountMinor must equal physical dispensedMinor");
        if (oa.released) return fail(req,"ATM_OFFLINE_AUTHORITY_RELEASED",oa.id);
        if (oa.consumed) {
            if (req.idempotencyKey().equals(oa.settlementIdempotencyKey) && physicalTransactionId.equals(oa.physicalTransactionId))
                return ok(req,"OFFLINE_WITHDRAWAL_SETTLED",Map.of("bankTransactionId","ATM-OW-"+req.idempotencyKey(),"offlineAuthorityId",oa.id,"amountMinor",oa.consumedMinor));
            return fail(req,"ATM_OFFLINE_AUTHORITY_ALREADY_CONSUMED",oa.id);
        }
        if (!oa.terminalId.equals(req.terminalId()) || !oa.customerId.equals(sessionCustomer(req)) || !oa.accountId.equals(s(req.data(),"accountId"))
                || !oa.currency.equals(s(req.data(),"currency")) || amount<=0 || amount>oa.maxAmount || Instant.now().isAfter(oa.expiresAt))
            return fail(req,"ATM_OFFLINE_AUTHORITY_INVALID","binding/amount/expiry mismatch");
        Account a=accounts.get(oa.accountId);
        long reservedMinor = 0L;
        if (oa.mode.equals("RESERVED_ALLOWANCE")) {
            Hold h=holds.get(oa.holdId);
            if(h==null||!h.active) return fail(req,"HOLD_NOT_ACTIVE",oa.holdId);
            if(amount>h.amountMinor) return fail(req,"ATM_HOLD_MISMATCH",oa.holdId);
            reservedMinor=h.amountMinor;
            h.active=false;
        }
        a.bookMinor-=amount;
        oa.consumed=true;
        oa.settlementIdempotencyKey=req.idempotencyKey();
        oa.physicalTransactionId=physicalTransactionId;
        oa.consumedMinor=amount;
        committedWithdrawals.put(req.idempotencyKey(),amount);
        Map<String,Object> out=new LinkedHashMap<>();
        out.put("bankTransactionId","ATM-OW-"+req.idempotencyKey()); out.put("offlineAuthorityId",oa.id); out.put("amountMinor",amount);
        if (oa.mode.equals("RESERVED_ALLOWANCE")) { out.put("reservedMinor",reservedMinor); out.put("unusedReservedMinor",reservedMinor-amount); }
        return ok(req,"OFFLINE_WITHDRAWAL_SETTLED",out);
    }

    private BankResponse withdrawAuthorise(BankRequest req) {
        Account a = ownedAccount(req, s(req.data(), "accountId"));
        if (a == null) return fail(req, "ACCOUNT_NOT_FOUND_OR_NOT_OWNED", "account unavailable");
        long amount = n(req.data(), "amountMinor");
        long max = ((Number)((Map<?, ?>)currentRules.get("limits")).get("maxWithdrawalMinor")).longValue();
        if (amount <= 0 || amount > max) return fail(req, "WITHDRAW_AMOUNT_NOT_ALLOWED", "amount outside bank rules");
        long held = holds.values().stream().filter(h -> h.accountId.equals(a.id) && h.active).mapToLong(h -> h.amountMinor).sum();
        if (a.bookMinor - held < amount) return fail(req, "INSUFFICIENT_AVAILABLE_FUNDS", "available funds too low");
        String auth = "WDAUTH-" + req.idempotencyKey();
        String hold = "ATM-HOLD-" + req.idempotencyKey();
        holds.putIfAbsent(hold, new Hold(hold, auth, a.id, amount));
        return ok(req, "WITHDRAW_AUTHORISED", Map.of(
                "authorizationId", auth, "holdId", hold, "amountMinor", amount,
                "currency", a.currency, "expiresAt", Instant.now().plus(3, ChronoUnit.MINUTES).toString()));
    }

    private BankResponse withdrawCommit(BankRequest req) {
        String authId = s(req.data(), "authorizationId");
        String holdId = s(req.data(), "holdId");
        Hold h = holds.get(holdId);
        if (h == null || !h.authorizationId.equals(authId)) return fail(req, "WITHDRAW_AUTHORIZATION_INVALID", "hold/auth mismatch");
        if (!h.active && !committedWithdrawals.containsKey(req.idempotencyKey())) return fail(req, "HOLD_NOT_ACTIVE", holdId);
        if (!committedWithdrawals.containsKey(req.idempotencyKey())) {
            Account a = accounts.get(h.accountId);
            a.bookMinor -= h.amountMinor;
            h.active = false;
            committedWithdrawals.put(req.idempotencyKey(), h.amountMinor);
        }
        return ok(req, "WITHDRAW_COMMITTED", Map.of(
                "bankTransactionId", "ATM-WD-" + req.idempotencyKey(), "amountMinor", h.amountMinor,
                "accountId", h.accountId, "bookBalanceMinor", accounts.get(h.accountId).bookMinor));
    }

    private BankResponse withdrawCancel(BankRequest req) {
        String holdId = s(req.data(), "holdId");
        Hold h = holds.get(holdId);
        if (h == null) return fail(req, "HOLD_NOT_FOUND", holdId);
        h.active = false;
        return ok(req, "WITHDRAW_CANCELLED", Map.of("holdId", holdId));
    }

    private BankResponse depositCommit(BankRequest req) {
        Account a = ownedAccount(req, s(req.data(), "accountId"));
        if (a == null) return fail(req, "ACCOUNT_NOT_FOUND_OR_NOT_OWNED", "account unavailable");
        long amount = n(req.data(), "amountMinor");
        long max = ((Number)((Map<?, ?>)currentRules.get("limits")).get("maxDepositMinor")).longValue();
        if (amount <= 0 || amount > max) return fail(req, "DEPOSIT_AMOUNT_NOT_ALLOWED", "amount outside bank rules");
        if (!committedDeposits.containsKey(req.idempotencyKey())) {
            a.bookMinor += amount;
            committedDeposits.put(req.idempotencyKey(), amount);
        }
        return ok(req, "DEPOSIT_COMMITTED", Map.of(
                "bankTransactionId", "ATM-DEP-" + req.idempotencyKey(), "amountMinor", amount,
                "accountId", a.id, "bookBalanceMinor", a.bookMinor));
    }

    private BankResponse transactionStatus(BankRequest req) {
        String key = s(req.data(), "idempotencyKey");
        if (committedWithdrawals.containsKey(key)) return ok(req, "TRANSACTION_COMMITTED", Map.of("kind", "WITHDRAWAL"));
        if (committedDeposits.containsKey(key)) return ok(req, "TRANSACTION_COMMITTED", Map.of("kind", "DEPOSIT"));
        return ok(req, "TRANSACTION_UNKNOWN", Map.of());
    }

    private Account ownedAccount(BankRequest req, String id) {
        String customer = sessionCustomer(req);
        Account a = accounts.get(id);
        return customer != null && a != null && a.customerId.equals(customer) ? a : null;
    }

    private String sessionCustomer(BankRequest req) { return sessions.get(req.sessionId()); }

    private BankResponse signedRulesResponse(BankRequest req, String code) {
        try {
            Signature sig = Signature.getInstance("Ed25519");
            sig.initSign(ruleKeyPair.getPrivate());
            sig.update(Json.canonical(currentRules).getBytes(StandardCharsets.UTF_8));
            Map<String, Object> data = new LinkedHashMap<>();
            data.put("rules", currentRules);
            data.put("signatureAlgorithm", "Ed25519");
            data.put("keyId", "FB-DEMO-RULE-KEY-1");
            data.put("signature", Base64.getEncoder().encodeToString(sig.sign()));
            if (req == null) {
                return new BankResponse("federationbank.atm.response/0.1", "RULE-UPDATE-" + System.nanoTime(),
                        "RULES_UPDATE", "*", true, code, "bank-published rule update", Instant.now(), data);
            }
            return BankResponse.success(req, code, "current signed ATM rules", data);
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private Map<String, Object> makeRules(long version, String offlineWithdrawalMode, String offlineDepositMode) {
        Instant now = Instant.now();
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("schema", "federationbank.atm.rules/0.1");
        m.put("rulesetId", "FB-ATM-IOM-DEMO");
        m.put("version", version);
        m.put("issuedAt", now.toString());
        m.put("validFrom", now.minus(1, ChronoUnit.MINUTES).toString());
        m.put("validUntil", now.plus(24, ChronoUnit.HOURS).toString());
        m.put("target", Map.of("terminalId", "*", "region", "IOM"));
        m.put("online", Map.of("balance", true, "withdrawal", true, "deposit", true));
        m.put("offline", Map.of("balanceMode", "CACHED_MARKED_STALE", "withdrawalMode", offlineWithdrawalMode,
                "depositMode", offlineDepositMode));
        m.put("limits", Map.of("maxWithdrawalMinor", 50_000L, "maxDepositMinor", 100_000L,
                "sessionTimeoutSeconds", 600L));
        return m;
    }

    private static BankResponse ok(BankRequest req, String code, Map<String, Object> data) {
        return BankResponse.success(req, code, "", data);
    }
    private static BankResponse fail(BankRequest req, String code, String detail) {
        return BankResponse.failure(req, code, detail);
    }
    private static String s(Map<String, Object> m, String key) { return String.valueOf(m.getOrDefault(key, "")); }
    private static long n(Map<String, Object> m, String key) {
        Object v = m.get(key); return v instanceof Number x ? x.longValue() : Long.parseLong(String.valueOf(v));
    }

    private record Customer(String cardId, String pin, String customerId, String name) {}
    private static final class OfflineAuthority {
        final String id,mode,terminalId,customerId,accountId,currency,holdId,rulesetId; final long maxAmount,rulesVersion; final Instant expiresAt; boolean consumed, released;
        String settlementIdempotencyKey="", physicalTransactionId="", releaseIdempotencyKey=""; long consumedMinor;
        OfflineAuthority(String id,String mode,String terminalId,String customerId,String accountId,String currency,long maxAmount,String holdId,String rulesetId,long rulesVersion,Instant expiresAt) {
            this.id=id; this.mode=mode; this.terminalId=terminalId; this.customerId=customerId; this.accountId=accountId; this.currency=currency; this.maxAmount=maxAmount; this.holdId=holdId; this.rulesetId=rulesetId; this.rulesVersion=rulesVersion; this.expiresAt=expiresAt;
        }
    }
    private static final class Account {
        final String id, customerId, displayName, productCode, currency;
        long bookMinor;
        Account(String id, String customerId, String displayName, String productCode, String currency, long bookMinor) {
            this.id = id; this.customerId = customerId; this.displayName = displayName;
            this.productCode = productCode; this.currency = currency; this.bookMinor = bookMinor;
        }
    }
    private static final class Hold {
        final String id, authorizationId, accountId; final long amountMinor; boolean active = true;
        Hold(String id, String authorizationId, String accountId, long amountMinor) {
            this.id = id; this.authorizationId = authorizationId; this.accountId = accountId; this.amountMinor = amountMinor;
        }
    }
}

package com.federationbank.atm;

import com.federationbank.atm.bank.BankNetwork;
import com.federationbank.atm.bank.BankNetworkException;
import com.federationbank.atm.cash.CashDispenser;
import com.federationbank.atm.cash.DepositAcceptor;
import com.federationbank.atm.cash.DepositResult;
import com.federationbank.atm.cash.DispenseResult;
import com.federationbank.atm.domain.AccountSummary;
import com.federationbank.atm.domain.AtmRules;
import com.federationbank.atm.domain.Balance;
import com.federationbank.atm.domain.BankSession;
import com.federationbank.atm.domain.TransactionOutcome;
import com.federationbank.atm.journal.JournalEvent;
import com.federationbank.atm.journal.TerminalSequence;
import com.federationbank.atm.journal.TransactionJournal;
import com.federationbank.atm.protocol.BankRequest;
import com.federationbank.atm.protocol.BankResponse;
import com.federationbank.atm.rules.RuleStore;
import com.federationbank.atm.rules.RuleVerifier;

import java.io.IOException;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/** ATM application service: customer intent + physical cash fact + bank monetary truth remain separate. */
public final class AtmService implements AutoCloseable {
    private static final String REQUEST_SCHEMA = "federationbank.atm.request/0.1";

    private final String terminalId;
    private final BankNetwork network;
    private final RuleVerifier ruleVerifier;
    private final RuleStore ruleStore;
    private final TransactionJournal journal;
    private final TerminalSequence sequence;
    private final CashDispenser dispenser;
    private final DepositAcceptor acceptor;
    private final Map<String, Balance> balanceCache = new LinkedHashMap<>();
    private final ScheduledExecutorService rulePoller;
    private volatile AtmRules rules;
    private volatile String terminalStatus = "BOOTING";
    private volatile String lastRuleError = "";

    public AtmService(String terminalId, BankNetwork network, RuleVerifier ruleVerifier, RuleStore ruleStore,
                      TransactionJournal journal, TerminalSequence sequence,
                      CashDispenser dispenser, DepositAcceptor acceptor) {
        this.terminalId = terminalId;
        this.network = network;
        this.ruleVerifier = ruleVerifier;
        this.ruleStore = ruleStore;
        this.journal = journal;
        this.sequence = sequence;
        this.dispenser = dispenser;
        this.acceptor = acceptor;
        this.rulePoller = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "fb-atm-rule-poller"); t.setDaemon(true); return t;
        });
    }

    public void start() throws IOException, BankNetworkException {
        loadCachedRules();
        Map<String, Object> caps = new LinkedHashMap<>();
        caps.put("softwareVersion", "0.1.9");
        caps.put("protocolVersion", "0.1");
        caps.put("supportedOperations", List.of("LOGON", "LIST_ACCOUNTS", "GET_BALANCE", "WITHDRAWAL", "DEPOSIT",
                "GET_OFFLINE_ALLOWANCE", "RELEASE_OFFLINE_ALLOWANCE", "OFFLINE_WITHDRAWAL_ADVICE"));
        BankResponse signOn = sendNew("TERMINAL_SIGN_ON", null, caps);
        if (!signOn.ok()) throw new BankNetworkException("terminal sign-on rejected: " + signOn.code() + " " + signOn.detail());
        terminalStatus = String.valueOf(signOn.data().getOrDefault("terminalStatus", "ACTIVE"));
        refreshRules();
        recoverPendingTransactions();
        rulePoller.scheduleWithFixedDelay(this::pollRulesQuietly, 5, 5, TimeUnit.SECONDS);
    }

    public BankSession logon(String cardId, char[] credential) throws IOException, BankNetworkException {
        String secret = new String(credential);
        try {
            BankResponse r = sendNew("LOGON", null, Map.of("cardId", cardId, "credentialType", "DEMO_PIN", "credential", secret));
            if (!r.ok()) throw new BankOperationException(r.code(), r.detail());
            return new BankSession(s(r.data(), "sessionId"), s(r.data(), "customerId"), s(r.data(), "customerDisplayName"),
                    Instant.parse(s(r.data(), "sessionExpiresAt")));
        } finally {
            java.util.Arrays.fill(credential, '\0');
        }
    }

    public void logoff(BankSession session) {
        if (session == null) return;
        /*
         * A physical-cash fact outranks a cosmetic server-side LOGOFF.  FederationBank v0.8
         * accepts expired sessions for deposit/cancel recovery but (correctly for ordinary
         * sessions, awkwardly for physical recovery) rejects sessions already marked LOGGED_OFF.
         * Try recovery first, and if a session-bound physical fact is still pending, let the
         * bank session expire naturally instead of making the evidence unreplayable.
         */
        try { recoverPendingTransactions(); } catch (IOException ignored) {}
        try { releaseUnusedOfflineAllowances(session); } catch (Exception ignored) {}
        try { recoverPendingTransactions(); } catch (IOException ignored) {}
        try {
            if (hasSessionBoundRecoveryPending(session.sessionId())) return;
            sendNew("LOGOFF", session, Map.of());
        } catch (Exception ignored) {}
    }

    @SuppressWarnings("unchecked")
    public List<AccountSummary> listAccounts(BankSession session) throws IOException, BankNetworkException {
        requireSession(session);
        BankResponse r = sendNew("LIST_ACCOUNTS", session, Map.of());
        ensureOk(r);
        List<AccountSummary> out = new ArrayList<>();
        Object raw = r.data().get("accounts");
        if (raw instanceof List<?> list) for (Object item : list) if (item instanceof Map<?, ?> m0) {
            Map<String, Object> m = (Map<String, Object>) m0;
            out.add(new AccountSummary(s(m,"accountId"), s(m,"displayName"), s(m,"productCode"), s(m,"currency"), s(m,"status")));
        }
        return out;
    }

    public Balance balance(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        requireSession(session);
        AtmRules active = requireValidRules();
        if (!active.onlineBalance() && network.isOnline()) throw new BankOperationException("BALANCE_DISABLED_BY_RULE", "bank rules disabled balance enquiries");
        try {
            BankResponse r = sendNew("GET_BALANCE", session, Map.of("accountId", account.accountId()));
            ensureOk(r);
            Balance b = new Balance(s(r.data(),"accountId"), s(r.data(),"currency"), n(r.data(),"bookBalanceMinor"),
                    n(r.data(),"heldMinor"), n(r.data(),"availableBalanceMinor"), Instant.parse(s(r.data(),"asOf")), false);
            synchronized (balanceCache) { balanceCache.put(account.accountId(), b); }
            return b;
        } catch (BankNetworkException e) {
            if ("CACHED_MARKED_STALE".equals(active.offlineBalanceMode())) {
                synchronized (balanceCache) {
                    Balance b = balanceCache.get(account.accountId());
                    if (b != null) return new Balance(b.accountId(), b.currency(), b.bookBalanceMinor(), b.heldMinor(),
                            b.availableBalanceMinor(), b.asOf(), true);
                }
            }
            throw e;
        }
    }

    public TransactionOutcome withdraw(BankSession session, AccountSummary account, long amountMinor)
            throws IOException, BankNetworkException {
        requireSession(session);
        AtmRules active = requireValidRules();
        if (amountMinor <= 0 || amountMinor > active.maxWithdrawalMinor())
            return TransactionOutcome.failed("WITHDRAW_AMOUNT_NOT_ALLOWED", "amount outside current bank rule", "");
        if (!network.isOnline()) return withdrawOffline(session, account, amountMinor, active);
        if (!active.onlineWithdrawal()) return TransactionOutcome.failed("WITHDRAWAL_DISABLED_BY_RULE", "bank rules disabled withdrawals", "");

        Identity authIdentity = newIdentity("WDA");
        String tx = "WD-" + authIdentity.idempotencyKey();
        Map<String, Object> authData = new LinkedHashMap<>();
        authData.put("accountId", account.accountId()); authData.put("currency", account.currency()); authData.put("amountMinor", amountMinor);
        BankResponse auth = sendFixed("WITHDRAW_AUTHORISE", session, authData, authIdentity);
        if (!auth.ok()) return TransactionOutcome.failed(auth.code(), auth.detail(), tx);

        String authorizationId = s(auth.data(), "authorizationId");
        String holdId = s(auth.data(), "holdId");
        Identity commitId = newIdentity("WDM"); // allocated before dispensing so restart cannot reuse the auth identity
        Map<String, Object> physicalContext = new LinkedHashMap<>();
        physicalContext.put("sessionId", session.sessionId()); physicalContext.put("customerId", session.customerId());
        physicalContext.put("accountId", account.accountId()); physicalContext.put("currency", account.currency());
        physicalContext.put("amountMinor", amountMinor); physicalContext.put("authorizationId", authorizationId); physicalContext.put("holdId", holdId);
        physicalContext.put("commitCommandId", commitId.commandId());
        physicalContext.put("commitIdempotencyKey", commitId.idempotencyKey());
        physicalContext.put("commitTerminalSequence", commitId.sequence());
        append(tx, "WITHDRAWAL", "AUTHORISED", authIdentity, physicalContext);
        append(tx, "WITHDRAWAL", "DISPENSE_STARTED", authIdentity, physicalContext); // durable before irreversible device action

        DispenseResult dispense = dispenser.dispense(account.currency(), amountMinor);
        Map<String, Object> resultData = new LinkedHashMap<>(physicalContext);
        resultData.put("physicalTransactionId", dispense.physicalTransactionId());
        resultData.put("dispensedMinor", dispense.dispensedMinor());
        if (dispense.status() == DispenseResult.Status.FAILURE) {
            append(tx, "WITHDRAWAL", "DISPENSE_FAILED", authIdentity, resultData);
            Identity cancelId = newIdentity("WDC");
            Map<String, Object> cancelData = Map.of("authorizationId", authorizationId, "holdId", holdId,
                    "physicalTransactionId", dispense.physicalTransactionId());
            try {
                BankResponse cancelled = sendFixed("WITHDRAW_CANCEL", session, cancelData, cancelId);
                append(tx, "WITHDRAWAL", cancelled.ok() ? "CANCELLED" : "CANCEL_FAILED", cancelId, resultData);
            } catch (BankNetworkException e) {
                append(tx, "WITHDRAWAL", "CANCELLATION_PENDING", cancelId, merge(resultData, Map.of("cancelData", cancelData)));
            }
            return TransactionOutcome.failed("DISPENSE_FAILED", dispense.detail(), tx);
        }
        if (dispense.status() == DispenseResult.Status.PARTIAL) {
            append(tx, "WITHDRAWAL", "RECONCILIATION_REQUIRED", authIdentity, resultData);
            try { sendNew("WITHDRAW_EXCEPTION", session, resultData); } catch (Exception ignored) {}
            return new TransactionOutcome(false, "PARTIAL_DISPENSE", dispense.detail(), tx, dispense.dispensedMinor(), false);
        }

        append(tx, "WITHDRAWAL", "DISPENSED", authIdentity, resultData);
        Map<String, Object> commitData = new LinkedHashMap<>(resultData);
        append(tx, "WITHDRAWAL", "COMMIT_REQUESTED", commitId, commitData);
        try {
            BankResponse committed = sendFixed("WITHDRAW_COMMIT", session, commitData, commitId);
            if (!committed.ok()) {
                append(tx, "WITHDRAWAL", "RECONCILIATION_REQUIRED", commitId, merge(commitData, Map.of("bankCode", committed.code())));
                return new TransactionOutcome(false, committed.code(), committed.detail(), tx, amountMinor, false);
            }
            append(tx, "WITHDRAWAL", "COMMITTED", commitId, merge(commitData, Map.of("bankTransactionId", s(committed.data(),"bankTransactionId"))));
            return new TransactionOutcome(true, committed.code(), "Cash dispensed and bank confirmed", tx, amountMinor, true);
        } catch (BankNetworkException e) {
            append(tx, "WITHDRAWAL", "COMMIT_PENDING", commitId, commitData);
            return new TransactionOutcome(true, "CASH_DISPENSED_CONFIRMATION_PENDING",
                    "Cash was dispensed. Bank confirmation will be retried; do not repeat the dispense.", tx, amountMinor, false);
        }
    }


    /** Acquire and durably retain a FederationBank v0.9 single-use offline cash authority. */
    public TransactionOutcome requestOfflineAllowance(BankSession session, AccountSummary account, long amountMinor, String authorityMode)
            throws IOException, BankNetworkException {
        requireSession(session);
        AtmRules active = requireValidRules();
        if (!network.isOnline()) return TransactionOutcome.failed("OFFLINE_AUTHORITY_ONLINE_REQUIRED", "bank connection required to issue authority", "");
        if (amountMinor <= 0 || amountMinor > active.maxWithdrawalMinor())
            return TransactionOutcome.failed("OFFLINE_AUTHORITY_AMOUNT_INVALID", "amount outside current bank rule", "");
        String mode = authorityMode == null ? "RESERVED_ALLOWANCE" : authorityMode;
        if (!mode.equals("RESERVED_ALLOWANCE") && !mode.equals("DELEGATED_STAND_IN"))
            return TransactionOutcome.failed("OFFLINE_AUTHORITY_MODE_INVALID", mode, "");
        if (!offlineModePermits(active.offlineWithdrawalMode(), mode))
            return TransactionOutcome.failed("OFFLINE_AUTHORITY_DISABLED_BY_RULE",
                    "current signed rules do not permit " + mode, "");
        Identity id = newIdentity("OFA");
        BankResponse r = sendFixed("GET_OFFLINE_ALLOWANCE", session, Map.of(
                "accountId", account.accountId(), "currency", account.currency(), "amountMinor", amountMinor, "authorityMode", mode), id);
        if (!r.ok()) return TransactionOutcome.failed(r.code(), r.detail(), "OA-" + id.idempotencyKey());
        Map<String,Object> d = new LinkedHashMap<>(r.data());
        if (!terminalId.equals(s(d,"terminalId")) || !session.customerId().equals(s(d,"customerId"))
                || !account.accountId().equals(s(d,"accountId")) || !account.currency().equals(s(d,"currency"))
                || amountMinor > n(d,"maxAmountMinor",0L) || !active.rulesetId().equals(s(d,"rulesetId"))
                || active.version() != n(d,"rulesVersion",-1L))
            return TransactionOutcome.failed("OFFLINE_AUTHORITY_BINDING_INVALID", "bank authority did not match terminal/session/account/rules", "");
        d.put("sessionId", session.sessionId());
        append("OA-" + s(d,"offlineAuthorityId"), "OFFLINE_AUTHORITY", "ACTIVE", id, d);
        return new TransactionOutcome(true, r.code(), "Offline cash authority stored", "OA-" + s(d,"offlineAuthorityId"), amountMinor, true);
    }

    /**
     * Return unused bank-issued offline authorities before ending a customer session.
     * Only locally ACTIVE authorities are eligible: claimed, consumed or quarantined
     * physical-cash states are deliberately never turned back into availability.
     */
    public int releaseUnusedOfflineAllowances(BankSession session) throws IOException {
        if (session == null || session.expired() || !network.isOnline()) return 0;
        int released = 0;
        for (JournalEvent e : journal.latestByTransaction().values()) {
            if (!e.kind().equals("OFFLINE_AUTHORITY") || !e.state().equals("ACTIVE")) continue;
            if (!session.customerId().equals(s(e.data(), "customerId"))) continue;
            if (!terminalId.equals(s(e.data(), "terminalId"))) continue;
            if (releaseOfflineAuthority(session, e)) released++;
        }
        return released;
    }

    private boolean releaseOfflineAuthority(BankSession session, JournalEvent authority) throws IOException {
        String authorityId = s(authority.data(), "offlineAuthorityId");
        if (authorityId.isBlank()) return false;
        Identity id = newIdentity("OFR");
        Map<String,Object> data = new LinkedHashMap<>(authority.data());
        data.put("sessionId", session.sessionId());
        data.put("customerId", session.customerId());
        data.put("offlineAuthorityId", authorityId);
        data.put("releaseCommandId", id.commandId());
        data.put("releaseIdempotencyKey", id.idempotencyKey());
        data.put("releaseTerminalSequence", id.sequence());
        data.put("releaseRequestedAt", Instant.now().toString());
        append(authority.transactionId(), "OFFLINE_AUTHORITY", "RELEASE_PENDING", id, data);
        try {
            BankResponse r = sendFixed("RELEASE_OFFLINE_ALLOWANCE", session, data, id);
            if (r.ok()) {
                append(authority.transactionId(), "OFFLINE_AUTHORITY", "RELEASED", id,
                        merge(data, Map.of("releaseCode", r.code(), "releasedAt", Instant.now().toString())));
                return true;
            }
            if (r.code().equals("OPERATION_UNSUPPORTED") || r.code().equals("ATM_OPERATION_UNSUPPORTED")) {
                /* Backward-compatible with FederationBank v0.9 before the release candidate:
                 * the bank still owns an ACTIVE authority/hold, so restore the local ACTIVE
                 * state rather than pretending cancellation occurred. */
                append(authority.transactionId(), "OFFLINE_AUTHORITY", "ACTIVE", id,
                        merge(authority.data(), Map.of("releaseUnsupportedCode", r.code(), "releaseUnsupportedAt", Instant.now().toString())));
                return false;
            }
            append(authority.transactionId(), "OFFLINE_AUTHORITY", "RELEASE_RECONCILIATION_REQUIRED", id,
                    merge(data, Map.of("releaseCode", r.code())));
        } catch (BankNetworkException e) {
            /* RELEASE_PENDING is already durable.  Recovery reuses this exact identity. */
        }
        return false;
    }

    private TransactionOutcome withdrawOffline(BankSession session, AccountSummary account, long amountMinor, AtmRules active) throws IOException {
        if ("DENY".equals(active.offlineWithdrawalMode()))
            return TransactionOutcome.failed("OFFLINE_WITHDRAWAL_DISABLED_BY_RULE", "current signed rules deny offline cash", "");
        JournalEvent auth = null;
        for (JournalEvent e : journal.latestByTransaction().values()) {
            if (!e.kind().equals("OFFLINE_AUTHORITY") || !e.state().equals("ACTIVE")) continue;
            Map<String,Object> d=e.data();
            try {
                if (!terminalId.equals(s(d,"terminalId")) || !session.customerId().equals(s(d,"customerId"))) continue;
                if (!account.accountId().equals(s(d,"accountId")) || !account.currency().equals(s(d,"currency"))) continue;
                if (!active.rulesetId().equals(s(d,"rulesetId")) || active.version()!=n(d,"rulesVersion",-1L)) continue;
                if (!offlineModePermits(active.offlineWithdrawalMode(), s(d,"authorityMode"))) continue;
                if (amountMinor > n(d,"maxAmountMinor",0L)) continue;
                if (!"ACTIVE".equals(s(d,"status"))) continue;
                Instant expiry=Instant.parse(s(d,"expiresAt")); if (!Instant.now().isBefore(expiry)) continue;
                auth=e; break;
            } catch (Exception ignored) {}
        }
        if (auth == null) return TransactionOutcome.failed("OFFLINE_ALLOWANCE_REQUIRED", "no valid bank-issued offline authority is present", "");

        String authorityId = s(auth.data(),"offlineAuthorityId");
        String tx="OW-"+authorityId;
        Identity adviceId=newIdentity("OWA");
        Map<String,Object> ctx=new LinkedHashMap<>(auth.data());
        ctx.put("amountMinor", amountMinor); ctx.put("requestedAmountMinor", amountMinor); ctx.put("dispensedMinor", 0L);
        ctx.put("adviceCommandId", adviceId.commandId()); ctx.put("adviceIdempotencyKey", adviceId.idempotencyKey()); ctx.put("adviceTerminalSequence", adviceId.sequence());
        ctx.put("dispenseStartedAt", Instant.now().toString());

        /*
         * Claim the bank-issued authority before the irreversible device call.  The
         * authority and physical transaction are separate journal identities, so a
         * power loss after the dispenser starts must never leave the authority ACTIVE.
         */
        Map<String,Object> claimed = new LinkedHashMap<>(auth.data());
        claimed.put("localClaimTransactionId", tx);
        claimed.put("localClaimCommandId", adviceId.commandId());
        claimed.put("localClaimTerminalSequence", adviceId.sequence());
        claimed.put("localClaimedAt", Instant.now().toString());
        append(auth.transactionId(),"OFFLINE_AUTHORITY","CLAIMED_LOCALLY",adviceId,claimed);
        append(tx,"OFFLINE_WITHDRAWAL","DISPENSE_STARTED",adviceId,ctx);

        DispenseResult disp=dispenser.dispense(account.currency(),amountMinor);
        ctx.put("physicalTransactionId",disp.physicalTransactionId());
        ctx.put("dispensedMinor",disp.dispensedMinor());
        ctx.put("dispenseStatus",disp.status().name());

        if (disp.dispensedMinor() <= 0L) {
            append(tx,"OFFLINE_WITHDRAWAL","DISPENSE_FAILED",adviceId,ctx);
            Map<String,Object> released = new LinkedHashMap<>(auth.data());
            released.put("lastLocalClaimTransactionId", tx);
            released.put("lastDispenseStatus", disp.status().name());
            released.put("lastPhysicalTransactionId", disp.physicalTransactionId());
            released.put("localClaimReleasedAt", Instant.now().toString());
            append(auth.transactionId(),"OFFLINE_AUTHORITY","ACTIVE",adviceId,released);
            return TransactionOutcome.failed("OFFLINE_DISPENSE_FAILED",disp.detail(),tx);
        }

        /* Some cash physically left.  From this point the authority is single-use even
         * if the dispenser reports PARTIAL/FAILURE.  Advice carries the actual cash
         * amount, not the originally requested amount. */
        ctx.put("amountMinor", disp.dispensedMinor());
        ctx.put("dispensedAt", Instant.now().toString());
        append(tx,"OFFLINE_WITHDRAWAL","ADVICE_PENDING",adviceId,ctx);
        Map<String,Object> consumed = new LinkedHashMap<>(auth.data());
        consumed.put("localClaimTransactionId", tx);
        consumed.put("physicalTransactionId", disp.physicalTransactionId());
        consumed.put("dispensedMinor", disp.dispensedMinor());
        consumed.put("dispensedAt", s(ctx,"dispensedAt"));
        append(auth.transactionId(),"OFFLINE_AUTHORITY","CONSUMED_LOCALLY",adviceId,consumed);

        if (disp.status()!=DispenseResult.Status.SUCCESS || disp.dispensedMinor()!=amountMinor) {
            return new TransactionOutcome(true,"OFFLINE_PARTIAL_CASH_DISPENSED_SETTLEMENT_PENDING",
                    disp.detail()+"; actual cash is locked to this authority and requires bank reconciliation.",
                    tx,disp.dispensedMinor(),false);
        }
        return new TransactionOutcome(true,"OFFLINE_CASH_DISPENSED_SETTLEMENT_PENDING",
                "Cash dispensed under bank-issued authority; settlement will be uploaded on reconnection.",tx,disp.dispensedMinor(),false);
    }

    public TransactionOutcome deposit(BankSession session, AccountSummary account, long amountMinor)
            throws IOException, BankNetworkException {
        requireSession(session);
        AtmRules active = requireValidRules();
        if (amountMinor <= 0 || amountMinor > active.maxDepositMinor())
            return TransactionOutcome.failed("DEPOSIT_AMOUNT_NOT_ALLOWED", "amount outside current bank rule", "");
        if (network.isOnline() && !active.onlineDeposit()) return TransactionOutcome.failed("DEPOSIT_DISABLED_BY_RULE", "bank rules disabled deposits", "");
        if (!network.isOnline() && !"CAPTURE_AND_QUEUE".equals(active.offlineDepositMode()))
            return TransactionOutcome.failed("OFFLINE_DEPOSIT_DENIED", "bank rules do not permit offline cash capture", "");

        Identity txId = newIdentity("DEP");
        Identity commitId = newIdentity("DPM"); // allocated before cash acceptance for crash-safe recovery
        String tx = "DEP-" + txId.idempotencyKey();
        Map<String, Object> acceptContext = new LinkedHashMap<>();
        acceptContext.put("accountId", account.accountId()); acceptContext.put("currency", account.currency()); acceptContext.put("amountMinor", amountMinor);
        acceptContext.put("sessionId", session.sessionId()); acceptContext.put("customerId", session.customerId());
        acceptContext.put("commitCommandId", commitId.commandId()); acceptContext.put("commitIdempotencyKey", commitId.idempotencyKey());
        acceptContext.put("commitTerminalSequence", commitId.sequence());
        append(tx, "DEPOSIT", "ACCEPT_STARTED", txId, acceptContext);
        DepositResult physical = acceptor.accept(account.currency(), amountMinor);
        if (!physical.accepted()) {
            append(tx, "DEPOSIT", "CASH_REJECTED", txId, Map.of("physicalTransactionId", physical.physicalTransactionId()));
            return TransactionOutcome.failed("CASH_REJECTED", physical.detail(), tx);
        }
        Map<String, Object> commitData = new LinkedHashMap<>(acceptContext);
        commitData.put("amountMinor", physical.acceptedMinor()); commitData.put("physicalTransactionId", physical.physicalTransactionId());
        append(tx, "DEPOSIT", "CASH_ACCEPTED", txId, commitData); // cash is now physically inside the terminal
        append(tx, "DEPOSIT", "COMMIT_REQUESTED", commitId, commitData);
        try {
            BankResponse committed = sendFixed("DEPOSIT_COMMIT", session, commitData, commitId);
            if (!committed.ok()) {
                append(tx, "DEPOSIT", "RECONCILIATION_REQUIRED", commitId, merge(commitData, Map.of("bankCode", committed.code())));
                return new TransactionOutcome(false, committed.code(), committed.detail(), tx, amountMinor, false);
            }
            append(tx, "DEPOSIT", "COMMITTED", commitId, merge(commitData, Map.of("bankTransactionId", s(committed.data(),"bankTransactionId"))));
            return new TransactionOutcome(true, committed.code(), "Deposit received and bank confirmed", tx, amountMinor, true);
        } catch (BankNetworkException e) {
            append(tx, "DEPOSIT", "PENDING_UPLOAD", commitId, commitData);
            return new TransactionOutcome(true, "DEPOSIT_RECEIVED_CONFIRMATION_PENDING",
                    "Cash received by terminal; bank confirmation is pending.", tx, amountMinor, false);
        }
    }

    public synchronized void refreshRules() throws IOException, BankNetworkException {
        BankResponse r = sendNew("GET_RULES", null, Map.of("lastAcceptedVersion", rules == null ? 0L : rules.version()));
        if (!r.ok()) throw new BankOperationException(r.code(), r.detail());
        applyRulesResponse(r);
    }

    @SuppressWarnings("unchecked")
    private synchronized void applyRulesResponse(BankResponse r) throws IOException {
        Object raw = r.data().get("rules");
        if (!(raw instanceof Map<?, ?> m0)) throw new IOException("bank rules payload missing");
        Map<String, Object> map = (Map<String, Object>) m0;
        String signature = s(r.data(), "signature");
        String algorithm = s(r.data(), "signatureAlgorithm");
        String keyId = s(r.data(), "keyId");
        if (!ruleVerifier.verify(map, signature, algorithm)) {
            lastRuleError = "signature verification failed";
            throw new IOException("bank rules signature verification failed");
        }
        AtmRules candidate = AtmRules.fromMap(map);
        if (!targetAllows(map, terminalId)) throw new IOException("bank rules do not target this terminal");
        if (!candidate.currentlyValid()) throw new IOException("bank rules are not currently valid");
        if (rules != null && candidate.version() < rules.version()) throw new IOException("bank rules downgrade refused");
        ruleStore.save(candidate, signature, algorithm, keyId);
        rules = candidate;
        lastRuleError = "";
    }

    private void loadCachedRules() throws IOException {
        Optional<RuleStore.SignedRules> loaded = ruleStore.load();
        if (loaded.isEmpty()) return;
        RuleStore.SignedRules s = loaded.get();
        if (s.rules().currentlyValid() && ruleVerifier.verify(s.rules().raw(), s.signature(), s.algorithm())
                && targetAllows(s.rules().raw(), terminalId)) rules = s.rules();
    }

    private void pollRulesQuietly() {
        try {
            BankResponse update = network.pollRuleUpdate(100);
            if (update != null && update.ok()) applyRulesResponse(update);
        } catch (Exception e) {
            lastRuleError = e.getMessage() == null ? e.getClass().getSimpleName() : e.getMessage();
        }
    }

    /** Safe restart rule: never repeat a physical dispense merely because its bank reply is uncertain. */
    public void recoverPendingTransactions() throws IOException {
        Map<String, JournalEvent> latest = journal.latestByTransaction();
        for (JournalEvent e : latest.values()) {
            try {
                if (e.kind().equals("OFFLINE_AUTHORITY") && e.state().equals("CLAIMED_LOCALLY")) {
                    recoverClaimedOfflineAuthority(e, latest);
                } else if (e.kind().equals("OFFLINE_AUTHORITY") && (e.state().equals("RELEASE_PENDING")
                        || e.state().equals("RELEASE_RECONCILIATION_REQUIRED"))) {
                    Identity id = releaseIdentityFrom(e);
                    BankSession session = recoverySession(e.data());
                    BankResponse r = sendFixed("RELEASE_OFFLINE_ALLOWANCE", session, e.data(), id);
                    if (r.ok()) append(e.transactionId(), "OFFLINE_AUTHORITY", "RELEASED", id,
                            merge(e.data(), Map.of("releaseCode", r.code(), "releasedAt", Instant.now().toString())));
                    else if (r.code().equals("OPERATION_UNSUPPORTED") || r.code().equals("ATM_OPERATION_UNSUPPORTED"))
                        append(e.transactionId(), "OFFLINE_AUTHORITY", "ACTIVE", id,
                                merge(e.data(), Map.of("releaseUnsupportedCode", r.code(), "releaseUnsupportedAt", Instant.now().toString())));
                    else append(e.transactionId(), "OFFLINE_AUTHORITY", "RELEASE_RECONCILIATION_REQUIRED", id,
                                merge(e.data(), Map.of("releaseCode", r.code())));
                } else if (e.kind().equals("WITHDRAWAL") && (e.state().equals("COMMIT_PENDING") || e.state().equals("COMMIT_REQUESTED") || e.state().equals("DISPENSED"))) {
                    Identity id = identityFrom(e, "WDM");
                    BankSession session = recoverySession(e.data());
                    BankResponse r = sendFixed("WITHDRAW_COMMIT", session, e.data(), id);
                    append(e.transactionId(), "WITHDRAWAL", r.ok() ? "COMMITTED" : "RECONCILIATION_REQUIRED", id,
                            merge(e.data(), Map.of("recoveryCode", r.code())));
                } else if (e.kind().equals("WITHDRAWAL") && e.state().equals("CANCELLATION_PENDING")) {
                    Identity id = identityFrom(e, "WDC");
                    BankSession session = recoverySession(e.data());
                    BankResponse r = sendFixed("WITHDRAW_CANCEL", session, e.data(), id);
                    append(e.transactionId(), "WITHDRAWAL", r.ok() ? "CANCELLED" : "RECONCILIATION_REQUIRED", id,
                            merge(e.data(), Map.of("recoveryCode", r.code())));
                } else if (e.kind().equals("OFFLINE_WITHDRAWAL") && e.state().equals("ADVICE_PENDING")) {
                    Identity id = new Identity(s(e.data(),"adviceCommandId"), s(e.data(),"adviceIdempotencyKey"), n(e.data(),"adviceTerminalSequence",0L));
                    BankSession session = recoverySession(e.data());
                    BankResponse r = sendFixed("OFFLINE_WITHDRAWAL_ADVICE", session, e.data(), id);
                    append(e.transactionId(), "OFFLINE_WITHDRAWAL", r.ok() ? "SETTLED" : "RECONCILIATION_REQUIRED", id,
                            merge(e.data(), Map.of("recoveryCode", r.code())));
                } else if (e.kind().equals("OFFLINE_WITHDRAWAL") && e.state().equals("DISPENSE_STARTED")) {
                    Identity id = new Identity(s(e.data(),"adviceCommandId"), s(e.data(),"adviceIdempotencyKey"), n(e.data(),"adviceTerminalSequence",0L));
                    append(e.transactionId(), "OFFLINE_WITHDRAWAL", "RECONCILIATION_REQUIRED", id,
                            merge(e.data(), Map.of("reason", "restart occurred after offline dispense start; physical outcome unknown")));
                    quarantineOfflineAuthority(e.data(), id, "physical outcome unknown after restart");
                } else if (e.kind().equals("DEPOSIT") && (e.state().equals("PENDING_UPLOAD") || e.state().equals("COMMIT_REQUESTED") || e.state().equals("CASH_ACCEPTED"))) {
                    Identity id = identityFrom(e, "DPM");
                    BankSession session = recoverySession(e.data());
                    BankResponse r = sendFixed("DEPOSIT_COMMIT", session, e.data(), id);
                    append(e.transactionId(), "DEPOSIT", r.ok() ? "COMMITTED" : "RECONCILIATION_REQUIRED", id,
                            merge(e.data(), Map.of("recoveryCode", r.code())));
                } else if (e.kind().equals("WITHDRAWAL") && e.state().equals("DISPENSE_STARTED")) {
                    append(e.transactionId(), "WITHDRAWAL", "RECONCILIATION_REQUIRED", identityFrom(e, "WDX"),
                            merge(e.data(), Map.of("reason", "restart occurred after dispense start; physical outcome unknown")));
                }
            } catch (BankNetworkException | BankOperationException ignored) {
                // Leave the last recoverable state in place; next restart/operator cycle can retry.
            }
        }
    }

    private void recoverClaimedOfflineAuthority(JournalEvent authority, Map<String, JournalEvent> latest) throws IOException {
        String tx = s(authority.data(), "localClaimTransactionId");
        JournalEvent physical = tx.isBlank() ? null : latest.get(tx);
        Identity id = identityFrom(authority, "OWA");
        if (physical == null) {
            Map<String,Object> released = new LinkedHashMap<>(authority.data());
            released.put("localClaimReleasedAt", Instant.now().toString());
            released.put("localClaimRecoveryReason", "claim persisted before dispense-start evidence; safe to reactivate");
            append(authority.transactionId(), "OFFLINE_AUTHORITY", "ACTIVE", id, released);
            return;
        }
        if (physical.state().equals("DISPENSE_FAILED") && n(physical.data(), "dispensedMinor", 0L) <= 0L) {
            Map<String,Object> released = new LinkedHashMap<>(authority.data());
            released.put("localClaimReleasedAt", Instant.now().toString());
            released.put("localClaimRecoveryReason", "durable zero-cash dispenser result");
            append(authority.transactionId(), "OFFLINE_AUTHORITY", "ACTIVE", id, released);
            return;
        }
        if (physical.state().equals("ADVICE_PENDING") || physical.state().equals("SETTLED")) {
            Map<String,Object> consumed = new LinkedHashMap<>(authority.data());
            consumed.put("localClaimRecoveryReason", "physical cash evidence already durable");
            append(authority.transactionId(), "OFFLINE_AUTHORITY", "CONSUMED_LOCALLY", id, consumed);
            return;
        }
        quarantineOfflineAuthority(authority.data(), id, "claim survived restart with uncertain physical outcome");
    }

    private void quarantineOfflineAuthority(Map<String,Object> data, Identity id, String reason) throws IOException {
        String authorityId = s(data, "offlineAuthorityId");
        if (authorityId.isBlank()) return;
        Map<String,Object> quarantined = new LinkedHashMap<>(data);
        quarantined.put("localQuarantineReason", reason);
        quarantined.put("localQuarantinedAt", Instant.now().toString());
        append("OA-" + authorityId, "OFFLINE_AUTHORITY", "QUARANTINED_LOCALLY", id, quarantined);
    }

    private boolean hasSessionBoundRecoveryPending(String sessionId) throws IOException {
        for (JournalEvent e : journal.latestByTransaction().values()) {
            if (!sessionId.equals(s(e.data(), "sessionId"))) continue;
            if (e.kind().equals("DEPOSIT") && (e.state().equals("PENDING_UPLOAD")
                    || e.state().equals("COMMIT_REQUESTED") || e.state().equals("CASH_ACCEPTED"))) return true;
            if (e.kind().equals("WITHDRAWAL") && e.state().equals("CANCELLATION_PENDING")) return true;
            if (e.kind().equals("OFFLINE_WITHDRAWAL") && (e.state().equals("ADVICE_PENDING")
                    || e.state().equals("DISPENSE_STARTED") || e.state().equals("RECONCILIATION_REQUIRED"))) return true;
            if (e.kind().equals("OFFLINE_AUTHORITY") && (e.state().equals("CLAIMED_LOCALLY")
                    || e.state().equals("QUARANTINED_LOCALLY") || e.state().equals("RELEASE_PENDING")
                    || e.state().equals("RELEASE_RECONCILIATION_REQUIRED"))) return true;
        }
        return false;
    }

    public AtmRules rules() { return rules; }
    public String terminalStatus() { return terminalStatus; }
    public String connectionStatus() { return network.isOnline() ? "ONLINE" : (validRulesPresent() ? "OFFLINE_RESTRICTED" : "OUT_OF_SERVICE"); }
    public String lastRuleError() { return lastRuleError; }
    private static boolean offlineModePermits(String ruleMode, String authorityMode) {
        if (ruleMode == null || authorityMode == null) return false;
        return switch (ruleMode) {
            case "BANK_ISSUED_AUTHORITY" -> authorityMode.equals("RESERVED_ALLOWANCE") || authorityMode.equals("DELEGATED_STAND_IN");
            case "RESERVED_ALLOWANCE" -> authorityMode.equals("RESERVED_ALLOWANCE");
            case "DELEGATED_STAND_IN" -> authorityMode.equals("DELEGATED_STAND_IN");
            default -> false;
        };
    }

    public String terminalId() { return terminalId; }

    private boolean validRulesPresent() { return rules != null && rules.currentlyValid(); }
    private AtmRules requireValidRules() {
        if (!validRulesPresent()) throw new BankOperationException("NO_VALID_BANK_RULES", "no current signed bank rules are available");
        return rules;
    }
    private void requireSession(BankSession session) {
        if (session == null || session.expired()) throw new BankOperationException("SESSION_INVALID", "customer session missing or expired");
    }
    private static void ensureOk(BankResponse r) { if (!r.ok()) throw new BankOperationException(r.code(), r.detail()); }

    private BankResponse sendNew(String operation, BankSession session, Map<String, Object> data) throws IOException, BankNetworkException {
        return sendFixed(operation, session, data, newIdentity(shortCode(operation)));
    }

    private BankResponse sendFixed(String operation, BankSession session, Map<String, Object> data, Identity id) throws BankNetworkException {
        AtmRules r = rules;
        BankRequest req = new BankRequest(REQUEST_SCHEMA, id.commandId(), id.idempotencyKey(), operation, terminalId,
                id.sequence(), session == null ? "" : session.sessionId(), Instant.now(),
                r == null ? "" : r.rulesetId(), r == null ? 0L : r.version(), data);
        return network.exchange(req);
    }

    private Identity newIdentity(String code) throws IOException {
        long seq = sequence.next();
        String command = terminalId + "-" + code + "-" + String.format("%012d", seq);
        return new Identity(command, command, seq);
    }

    private static Identity releaseIdentityFrom(JournalEvent e) {
        String command = s(e.data(), "releaseCommandId");
        String key = s(e.data(), "releaseIdempotencyKey");
        long seq = n(e.data(), "releaseTerminalSequence", 0L);
        if (command.isBlank()) command = e.commandId();
        if (key.isBlank()) key = e.idempotencyKey().isBlank() ? command : e.idempotencyKey();
        return new Identity(command, key, seq);
    }

    private static Identity identityFrom(JournalEvent e, String code) {
        String commitCommand = s(e.data(), "commitCommandId");
        String commitKey = s(e.data(), "commitIdempotencyKey");
        long commitSeq = n(e.data(), "commitTerminalSequence", 0L);
        if (!commitCommand.isBlank() && (code.equals("WDM") || code.equals("DPM")))
            return new Identity(commitCommand, commitKey.isBlank() ? commitCommand : commitKey, commitSeq);
        long seq = n(e.data(), "terminalSequence", 0L);
        String command = e.commandId().isBlank() ? e.transactionId() + "-" + code : e.commandId();
        String key = e.idempotencyKey().isBlank() ? command : e.idempotencyKey();
        return new Identity(command, key, seq);
    }

    private void append(String tx, String kind, String state, Identity id, Map<String, Object> data) throws IOException {
        Map<String, Object> d = new LinkedHashMap<>(data);
        d.put("terminalSequence", id.sequence());
        journal.append(new JournalEvent(Instant.now(), tx, kind, state, id.commandId(), id.idempotencyKey(), d));
    }

    private static BankSession recoverySession(Map<String, Object> d) {
        return new BankSession(s(d,"sessionId"), s(d,"customerId"), "Recovery", Instant.now().plusSeconds(300));
    }

    @SuppressWarnings("unchecked")
    private static boolean targetAllows(Map<String, Object> rules, String terminalId) {
        Object targetRaw = rules.get("target");
        if (!(targetRaw instanceof Map<?, ?>)) return false;
        Map<String, Object> target = (Map<String, Object>) targetRaw;
        String id = s(target, "terminalId");
        return id.equals("*") || id.equals(terminalId);
    }

    private static Map<String, Object> merge(Map<String, Object> a, Map<String, Object> b) {
        Map<String, Object> out = new LinkedHashMap<>(a); out.putAll(b); return out;
    }
    private static String s(Map<String, Object> m, String k) { return String.valueOf(m.getOrDefault(k, "")); }
    private static long n(Map<String, Object> m, String k) { return n(m,k,0L); }
    private static long n(Map<String, Object> m, String k, long d) {
        Object v = m.get(k); if (v == null) return d; return v instanceof Number x ? x.longValue() : Long.parseLong(String.valueOf(v));
    }
    private static String shortCode(String op) {
        return switch (op) {
            case "TERMINAL_SIGN_ON" -> "TSO"; case "GET_RULES" -> "RUL"; case "LOGON" -> "LGN";
            case "LOGOFF" -> "LGF"; case "LIST_ACCOUNTS" -> "LAC"; case "GET_BALANCE" -> "BAL";
            case "WITHDRAW_EXCEPTION" -> "WDX"; default -> "CMD";
        };
    }

    @Override public void close() {
        rulePoller.shutdownNow();
        network.close();
    }

    private record Identity(String commandId, String idempotencyKey, long sequence) {}

    public static final class BankOperationException extends RuntimeException {
        private static final long serialVersionUID = 1L;
        private final String code;
        public BankOperationException(String code, String message) { super(message); this.code = code; }
        public String code() { return code; }
    }
}

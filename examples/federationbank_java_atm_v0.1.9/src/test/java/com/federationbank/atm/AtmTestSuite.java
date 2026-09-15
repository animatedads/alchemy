package com.federationbank.atm;

import com.federationbank.atm.bank.BankNetwork;
import com.federationbank.atm.bank.BankNetworkException;
import com.federationbank.atm.bank.FederationBankV08Profile;
import com.federationbank.atm.bank.DemoBankNetwork;
import com.federationbank.atm.cash.CashDispenser;
import com.federationbank.atm.brokerage.BrokerageNetworkException;
import com.federationbank.atm.brokerage.BrokerageRequest;
import com.federationbank.atm.brokerage.BrokerageService;
import com.federationbank.atm.brokerage.DemoBrokerageNetwork;
import com.federationbank.atm.brokerage.MerchantPositionSummary;
import com.federationbank.atm.cash.DummyCashDispenser;
import com.federationbank.atm.cash.DummyDepositAcceptor;
import com.federationbank.atm.domain.AccountSummary;
import com.federationbank.atm.domain.Balance;
import com.federationbank.atm.domain.BankSession;
import com.federationbank.atm.domain.TransactionOutcome;
import com.federationbank.atm.journal.TerminalSequence;
import com.federationbank.atm.journal.TransactionJournal;
import com.federationbank.atm.protocol.BankRequest;
import com.federationbank.atm.protocol.BankResponse;
import com.federationbank.atm.protocol.Json;
import com.federationbank.atm.rules.RuleStore;
import com.federationbank.atm.rules.RuleVerifier;

import java.nio.file.Files;
import java.nio.file.Path;
import java.security.PublicKey;
import java.security.KeyFactory;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class AtmTestSuite {
    private int passed;
    private int failed;

    public static void main(String[] args) throws Exception {
        AtmTestSuite t = new AtmTestSuite();
        t.run("json canonical round-trip", t::jsonRoundTrip);
        t.run("FederationBank ATM wire request shape", t::wireRequestShape);
        t.run("logon accounts balance and no PIN journal", t::logonAccountsBalance);
        t.run("withdrawal commits exactly once after lost reply", t::withdrawalLostReply);
        t.run("dispenser failure does not debit", t::dispenserFailure);
        t.run("offline deposit queues and recovers exactly once", t::offlineDepositRecovery);
        t.run("tampered signed rules are rejected", t::tamperedRulesRejected);
        t.run("FederationBank v0.8 exact rule signature vector", t::federationBankV08RuleVector);
        t.run("pending deposit is not orphaned by logoff", t::pendingDepositDefersBankLogoff);
        t.run("pending withdrawal cancellation recovers", t::pendingCancelRecovers);
        t.run("bank-issued reserved allowance vends offline and settles once", t::offlineReservedAllowance);
        t.run("unused offline allowance releases reservation before logoff", t::unusedOfflineAllowanceReleasedBeforeLogoff);
        t.run("lost offline release reply recovers idempotently before logoff", t::lostOfflineReleaseReplyRecovers);
        t.run("pending offline cash advice is not orphaned by logoff", t::pendingOfflineAdviceDefersBankLogoff);
        t.run("offline zero-cash failure safely releases local authority claim", t::offlineZeroCashFailureReleasesClaim);
        t.run("offline partial dispense consumes authority and settles actual cash", t::offlinePartialStandinSettlesActualCash);
        t.run("offline partial reserved dispense settles actual cash and releases unused hold", t::offlinePartialReservedReleasesUnusedHold);
        t.run("offline crash after dispense start quarantines authority across restart", t::offlineCrashQuarantinesAuthority);
        t.run("new signed DENY overrides cached offline cash authority", t::signedDenyOverridesCachedAuthority);
        t.run("brokerage wire is separate and does not select an account", t::brokerageWireShape);
        t.run("brokerage summary is read-only and cannot change bank availability", t::brokerageSummaryIsSeparateTruth);
        t.run("brokerage linkage and outage remain brokerage-owned", t::brokerageLinkageAndOutageAreSeparate);
        System.out.printf("%nRESULT: %d passed, %d failed%n", t.passed, t.failed);
        if (t.failed != 0) System.exit(1);
    }

    private void wireRequestShape() {
        BankRequest r = new BankRequest("federationbank.atm.request/0.1", "ATM-IOM-001-WDM-7",
                "WDM-IOM-7", "WITHDRAW_COMMIT", "ATM-IOM-001", 7L, "SESSION-7",
                Instant.parse("2026-08-26T00:00:00Z"), "FB-ATM-IOM-DEMO", 1L,
                Map.of("physicalTransactionId", "PHYS-007", "dispensedMinor", 10_000L));
        String json = r.toJson();
        check(json.contains("\"commandId\":\"ATM-IOM-001-WDM-7\""), "commandId remains JSON string");
        check(json.contains("\"terminalId\":\"ATM-IOM-001\""), "terminalId remains JSON string");
        check(json.contains("\"physicalTransactionId\":\"PHYS-007\""), "physical evidence remains JSON string");
        check(json.contains("\"rulesVersion\":1"), "rules version remains JSON number");
        check(json.contains("\"dispensedMinor\":10000"), "money remains integer minor units");
        BankRequest fractional = new BankRequest("federationbank.atm.request/0.1", "T", "T", "GET_BALANCE",
                "ATM-IOM-001", 8L, "S", Instant.parse("2026-08-26T00:00:00.123456789Z"),
                "FB-ATM-IOM-DEMO", 1L, Map.of());
        check(fractional.toJson().contains("2026-08-26T00:00:00.123Z"), "wire timestamp bounded to millisecond precision");
    }

    private void jsonRoundTrip() {
        Map<String,Object> m = new LinkedHashMap<>();
        m.put("b", List.of(1L, true, "x\n")); m.put("a", Map.of("z", 2L));
        String c = Json.canonical(m);
        check(c.startsWith("{\"a\":"), "canonical keys sorted");
        Object parsed = Json.parse(c);
        check(parsed instanceof Map<?,?>, "parse object");
        Map<?,?> pm = (Map<?,?>) parsed;
        Object first = ((List<?>) pm.get("b")).get(0);
        check(first instanceof Long && ((Long) first) == 1L, "integer JSON token remains Long");
    }

    private void logonAccountsBalance() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            List<AccountSummary> accounts = atm.listAccounts(s);
            check(accounts.size() == 2, "customer-scoped account list");
            Balance b = atm.balance(s, accounts.get(0));
            check(b.availableBalanceMinor() == 125_000L, "available balance");
            String journal = Files.exists(dir.resolve("journal.jsonl")) ? Files.readString(dir.resolve("journal.jsonl")) : "";
            check(!journal.contains("1234"), "PIN absent from journal");
            atm.logoff(s);
        }
    }

    private void withdrawalLostReply() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        LostReplyNetwork flaky = new LostReplyNetwork(bank);
        try (AtmService atm = service(dir, flaky, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            flaky.loseNextWithdrawCommitReply = true;
            TransactionOutcome r = atm.withdraw(s, a, 10_000L);
            check(r.ok() && !r.bankConfirmed(), "cash dispensed with confirmation pending");
            check(bank.accountBookBalance(a.accountId()) == 115_000L, "bank committed first debit");
            check(bank.committedWithdrawalCount() == 1, "one committed withdrawal");
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 115_000L, "replay did not debit twice");
            check(bank.committedWithdrawalCount() == 1, "still one committed withdrawal");
        }
    }

    private void dispenserFailure() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        dispenser.failNext();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome r = atm.withdraw(s, a, 10_000L);
            check(!r.ok() && r.code().equals("DISPENSE_FAILED"), "dispense failure surfaced");
            Balance b = atm.balance(s, a);
            check(b.bookBalanceMinor() == 125_000L, "book balance unchanged");
            check(b.heldMinor() == 0L, "reservation released");
        }
    }

    private void offlineDepositRecovery() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            bank.setOnline(false);
            TransactionOutcome r = atm.deposit(s, a, 20_000L);
            check(r.ok() && !r.bankConfirmed(), "physical deposit accepted while bank offline");
            check(bank.accountBookBalance(a.accountId()) == 125_000L, "no bank credit while disconnected");
            bank.setOnline(true);
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 145_000L, "pending deposit credited on recovery");
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 145_000L, "second recovery is harmless");
            check(bank.committedDepositCount() == 1, "one committed deposit");
        }
    }



    private void pendingDepositDefersBankLogoff() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        SelectiveFailureNetwork flaky = new SelectiveFailureNetwork(bank);
        try (AtmService atm = service(dir, flaky, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            flaky.failOperation = "DEPOSIT_COMMIT";
            TransactionOutcome r = atm.deposit(s, a, 20_000L);
            check(r.ok() && !r.bankConfirmed(), "cash accepted while deposit commit unavailable");
            atm.logoff(s);
            check(flaky.logoffCount == 0, "bank LOGOFF deferred while physical deposit needs session-bound replay");
            flaky.failOperation = "";
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 145_000L, "deferred deposit settled");
            atm.logoff(s);
            check(flaky.logoffCount == 1, "bank LOGOFF sent after physical fact settled");
        }
    }

    private void offlineReservedAllowance() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s,a,10_000L,"RESERVED_ALLOWANCE");
            check(issued.ok(),"reserved allowance issued");
            Balance before = atm.balance(s,a);
            check(before.heldMinor()==10_000L,"allowance backed by hold");
            bank.setOnline(false);
            TransactionOutcome cash = atm.withdraw(s,a,10_000L);
            check(cash.ok() && !cash.bankConfirmed(),"cash vended offline under bank authority");
            TransactionOutcome second = atm.withdraw(s,a,10_000L);
            check(!second.ok() && second.code().equals("OFFLINE_ALLOWANCE_REQUIRED"),"single-use authority cannot vend twice");
            bank.setOnline(true);
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId())==115_000L,"offline cash settled once");
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId())==115_000L,"recovery replay harmless");
        }
    }

    private void unusedOfflineAllowanceReleasedBeforeLogoff() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "unused reserved authority issued");
            check(bank.accountHeldMinor(a.accountId()) == 10_000L, "reserved authority constrains availability");
            atm.logoff(s);
            check(bank.accountHeldMinor(a.accountId()) == 0L, "unused reservation released before LOGOFF");
            check(bank.accountAvailableBalance(a.accountId()) == 125_000L, "available balance restored without book movement");
            String journal = Files.readString(dir.resolve("journal.jsonl"));
            check(journal.contains("\"state\":\"RELEASE_PENDING\""), "release intent durable before bank request");
            check(journal.contains("\"state\":\"RELEASED\""), "bank-confirmed authority release durable");
        }
    }

    private void lostOfflineReleaseReplyRecovers() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        LostReplyNetwork flaky = new LostReplyNetwork(bank);
        try (AtmService atm = service(dir, flaky, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "authority issued before release reply loss");
            flaky.loseNextOfflineReleaseReply = true;
            atm.logoff(s);
            check(bank.accountHeldMinor(a.accountId()) == 0L, "bank released hold before reply was lost");
            String pending = Files.readString(dir.resolve("journal.jsonl"));
            check(pending.contains("\"state\":\"RELEASE_PENDING\""), "lost response leaves durable release pending");
            atm.recoverPendingTransactions();
            check(bank.accountHeldMinor(a.accountId()) == 0L, "release replay does not recreate or double-release hold");
            atm.logoff(s);
            String recovered = Files.readString(dir.resolve("journal.jsonl"));
            check(recovered.contains("\"state\":\"RELEASED\""), "same release identity recovers to confirmed state");
        }
    }

    private void pendingOfflineAdviceDefersBankLogoff() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        SelectiveFailureNetwork flaky = new SelectiveFailureNetwork(bank);
        try (AtmService atm = service(dir, flaky, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "offline authority issued");
            bank.setOnline(false);
            TransactionOutcome cash = atm.withdraw(s, a, 10_000L);
            check(cash.ok() && !cash.bankConfirmed(), "offline cash physically dispensed");
            String journal = Files.readString(dir.resolve("journal.jsonl"));
            check(journal.contains("\"dispensedAt\""), "physical dispense timestamp journalled");
            bank.setOnline(true);
            flaky.failOperation = "OFFLINE_WITHDRAWAL_ADVICE";
            atm.logoff(s);
            check(flaky.logoffCount == 0, "bank LOGOFF deferred while offline physical cash needs replay");
            flaky.failOperation = "";
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 115_000L, "offline advice settled after transport recovery");
            atm.logoff(s);
            check(flaky.logoffCount == 1, "bank LOGOFF sent after offline cash settlement");
        }
    }

    private void offlineZeroCashFailureReleasesClaim() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "offline authority issued");
            bank.setOnline(false);
            dispenser.failNext();
            TransactionOutcome failed = atm.withdraw(s, a, 10_000L);
            check(!failed.ok() && failed.code().equals("OFFLINE_DISPENSE_FAILED"), "known zero-cash failure surfaced");
            String afterFailure = Files.readString(dir.resolve("journal.jsonl"));
            check(afterFailure.contains("\"state\":\"CLAIMED_LOCALLY\""), "authority claimed before dispenser call");
            check(afterFailure.contains("\"state\":\"ACTIVE\""), "zero-cash result reactivated authority");
            TransactionOutcome retry = atm.withdraw(s, a, 10_000L);
            check(retry.ok() && !retry.bankConfirmed(), "same authority may be retried only after durable zero-cash result");
            bank.setOnline(true);
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 115_000L, "retried cash settled once");
        }
    }

    private void offlinePartialStandinSettlesActualCash() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "DELEGATED_STAND_IN");
            check(issued.ok(), "delegated stand-in authority issued");
            bank.setOnline(false);
            dispenser.partialNext();
            TransactionOutcome partial = atm.withdraw(s, a, 10_000L);
            check(partial.ok() && partial.code().equals("OFFLINE_PARTIAL_CASH_DISPENSED_SETTLEMENT_PENDING"), "partial physical cash becomes a pending fact");
            check(partial.amountMinor() == 5_000L, "outcome reports actual cash dispensed");
            TransactionOutcome second = atm.withdraw(s, a, 10_000L);
            check(!second.ok() && second.code().equals("OFFLINE_ALLOWANCE_REQUIRED"), "partially used authority cannot vend again");
            String journal = Files.readString(dir.resolve("journal.jsonl"));
            check(journal.contains("\"amountMinor\":5000"), "advice journals actual partial cash amount");
            check(journal.contains("\"state\":\"CONSUMED_LOCALLY\""), "authority consumed locally after any non-zero cash");
            bank.setOnline(true);
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 120_000L, "delegated partial cash settled at actual amount");
            atm.recoverPendingTransactions();
            check(bank.accountBookBalance(a.accountId()) == 120_000L, "partial settlement replay harmless");
        }
    }

    private void offlinePartialReservedReleasesUnusedHold() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DummyCashDispenser dispenser = new DummyCashDispenser();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "reserved authority issued");
            Balance reserved = atm.balance(s, a);
            check(reserved.heldMinor() == 10_000L && reserved.availableBalanceMinor() == 115_000L, "full reservation held before dispense");
            bank.setOnline(false);
            dispenser.partialNext();
            TransactionOutcome partial = atm.withdraw(s, a, 10_000L);
            check(partial.ok() && partial.amountMinor() == 5_000L, "partial reserved physical cash recorded at actual amount");
            bank.setOnline(true);
            atm.recoverPendingTransactions();
            Balance settled = atm.balance(s, a);
            check(settled.bookBalanceMinor() == 120_000L, "only actual 5000 cash debited");
            check(settled.heldMinor() == 0L && settled.availableBalanceMinor() == 120_000L, "unused reservation released with single-use hold");
        }
    }

    private void offlineCrashQuarantinesAuthority() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        BankSession oldSession;
        AccountSummary account;
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new CrashAfterStartDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            oldSession = atm.logon("4111111111111111", "1234".toCharArray());
            account = atm.listAccounts(oldSession).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(oldSession, account, 10_000L, "DELEGATED_STAND_IN");
            check(issued.ok(), "authority issued before crash simulation");
            bank.setOnline(false);
            boolean crashed = false;
            try { atm.withdraw(oldSession, account, 10_000L); }
            catch (SimulatedPowerLoss e) { crashed = true; }
            check(crashed, "simulated power loss reached dispenser boundary");
        }

        bank.setOnline(true);
        try (AtmService restarted = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            restarted.start();
            String journal = Files.readString(dir.resolve("journal.jsonl"));
            check(journal.contains("\"state\":\"QUARANTINED_LOCALLY\""), "restart quarantines authority with unknown physical outcome");
            check(journal.contains("offline dispense start; physical outcome unknown"), "restart records physical uncertainty");
            BankSession s = restarted.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = restarted.listAccounts(s).get(0);
            bank.setOnline(false);
            TransactionOutcome retry = restarted.withdraw(s, a, 10_000L);
            check(!retry.ok() && retry.code().equals("OFFLINE_ALLOWANCE_REQUIRED"), "quarantined authority is never reused for a second vend");
        }
    }


    private void signedDenyOverridesCachedAuthority() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession session = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary account = atm.listAccounts(session).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(session, account, 10_000L, "RESERVED_ALLOWANCE");
            check(issued.ok(), "bank issued offline authority before policy revocation");
            check(bank.accountHeldMinor(account.accountId()) == 10_000L, "reserved authority has a real bank hold");

            bank.publishRules("DENY", "CAPTURE_AND_QUEUE");
            atm.refreshRules();
            bank.setOnline(false);
            TransactionOutcome denied = atm.withdraw(session, account, 10_000L);
            check(!denied.ok() && denied.code().equals("OFFLINE_WITHDRAWAL_DISABLED_BY_RULE"),
                    "new signed DENY outranks older cached authority");
            check(bank.accountBookBalance(account.accountId()) == 125_000L, "denied offline vend did not debit book");

            bank.setOnline(true);
            int released = atm.releaseUnusedOfflineAllowances(session);
            check(released == 1, "policy revocation still permits return of the now-unused authority");
            check(bank.accountHeldMinor(account.accountId()) == 0L, "returned authority releases customer availability");
        }
    }

    private void brokerageWireShape() {
        BrokerageRequest request = new BrokerageRequest(
                "federationbank.brokerage.atm.request/0.1",
                "BRKPOS-1",
                "GET_MERCHANT_POSITION_SUMMARY",
                "ATM-IOM-001",
                "SESSION-1",
                "CUST-002",
                Instant.parse("2026-08-26T08:20:00Z"));
        String json = request.toJson();
        check(json.contains("\"bankSessionId\":\"SESSION-1\""), "bank session context crosses the explicit enquiry perimeter");
        check(json.contains("\"customerId\":\"CUST-002\""), "authenticated retail customer context is present");
        check(!json.contains("accountId"), "ATM does not choose a retail-bank account for brokerage enquiry");
        check(!json.contains("brokerageAccountId"), "ATM does not choose or discover a brokerage account identifier");
        check(!json.contains("WITHDRAW") && !json.contains("TRADE"), "brokerage wire operation is read-only enquiry only");
    }

    private void brokerageSummaryIsSeparateTruth() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DemoBrokerageNetwork brokerageNetwork = new DemoBrokerageNetwork();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor());
             BrokerageService brokerage = new BrokerageService("ATM-IOM-001", brokerageNetwork)) {
            atm.start();
            BankSession session = atm.logon("5555555555554444", "4321".toCharArray());
            AccountSummary account = atm.listAccounts(session).get(0);
            Balance before = atm.balance(session, account);

            MerchantPositionSummary summary = brokerage.currentMerchantPosition(session).orElseThrow();
            check(summary.relationshipId().equals("BRK-RET-0002"), "brokerage resolved its own linked retail relationship");
            check(summary.currency().equals("AUD"), "brokerage summary currency retained");
            check(summary.netMarketValueMinor() == 7_244_000L, "brokerage market value is source-owned position truth");
            check(summary.availableMarginMinor() == 412_000L, "brokerage available margin retained as margin, not cash");
            check(summary.positionCount() == 2, "narrow summary carries count without individual trade details");
            check(summary.sourceAuthority().equals("FEDERATION_BROKERAGE_POSITION_AUTHORITY"), "source authority is explicit");

            Balance after = atm.balance(session, account);
            check(before.bookBalanceMinor() == after.bookBalanceMinor(), "position enquiry does not change retail book balance");
            check(before.availableBalanceMinor() == after.availableBalanceMinor(), "derivatives valuation cannot inflate retail withdrawable funds");
            check(summary.netMarketValueMinor() > after.availableBalanceMinor(), "test proves large derivative value remains separate from cash availability");

            String journal = Files.exists(dir.resolve("journal.jsonl")) ? Files.readString(dir.resolve("journal.jsonl")) : "";
            check(!journal.contains("BRK-RET-0002") && !journal.contains("netMarketValueMinor"),
                    "brokerage position is not persisted into the ATM monetary/recovery journal");
        }
    }

    private void brokerageLinkageAndOutageAreSeparate() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        DemoBrokerageNetwork brokerageNetwork = new DemoBrokerageNetwork();
        try (AtmService atm = service(dir, bank, bank.rulesPublicKey(), new DummyCashDispenser(), new DummyDepositAcceptor());
             BrokerageService brokerage = new BrokerageService("ATM-IOM-001", brokerageNetwork)) {
            atm.start();
            BankSession unlinked = atm.logon("4111111111111111", "1234".toCharArray());
            check(brokerage.currentMerchantPosition(unlinked).isEmpty(), "brokerage, not ATM, decides there is no linked relationship");
            atm.logoff(unlinked);

            BankSession linked = atm.logon("5555555555554444", "4321".toCharArray());
            AccountSummary account = atm.listAccounts(linked).get(0);
            check(brokerage.currentMerchantPosition(linked).isPresent(), "linked customer can obtain current position summary");
            brokerageNetwork.setOnline(false);
            boolean failed = false;
            try { brokerage.currentMerchantPosition(linked); }
            catch (BrokerageNetworkException expected) { failed = true; }
            check(failed, "ATM does not serve a cached brokerage position as current when brokerage is offline");
            Balance bankStillWorks = atm.balance(linked, account);
            check(bankStillWorks.availableBalanceMinor() == 410_000L, "brokerage outage does not become a retail-bank outage");
        }
    }

    private void pendingCancelRecovers() throws Exception {
        Path dir = Files.createTempDirectory("fb-atm-test-");
        DemoBankNetwork bank = new DemoBankNetwork();
        SelectiveFailureNetwork flaky = new SelectiveFailureNetwork(bank);
        DummyCashDispenser dispenser = new DummyCashDispenser();
        dispenser.failNext();
        try (AtmService atm = service(dir, flaky, bank.rulesPublicKey(), dispenser, new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            flaky.failOperation = "WITHDRAW_CANCEL";
            TransactionOutcome r = atm.withdraw(s, a, 10_000L);
            check(!r.ok() && r.code().equals("DISPENSE_FAILED"), "dispenser failure returned");
            flaky.failOperation = "";
            atm.recoverPendingTransactions();
            Balance b = atm.balance(s, a);
            check(b.heldMinor() == 0L, "pending cancellation released hold on recovery");
            check(b.bookBalanceMinor() == 125_000L, "cancel recovery did not debit book");
        }
    }

    @SuppressWarnings("unchecked")
    private void federationBankV08RuleVector() throws Exception {
        Map<String,Object> rules = new LinkedHashMap<>();
        rules.put("schema", FederationBankV08Profile.RULES_SCHEMA);
        rules.put("rulesetId", FederationBankV08Profile.DEMO_RULESET_ID);
        rules.put("version", FederationBankV08Profile.DEMO_RULES_VERSION);
        rules.put("issuedAt", "2026-08-25T00:00:00Z");
        rules.put("validFrom", "2026-08-25T00:00:00Z");
        rules.put("validUntil", "2030-01-01T00:00:00Z");
        rules.put("target", Map.of("terminalId", "*", "region", "IOM"));
        rules.put("online", Map.of("balance", true, "withdrawal", true, "deposit", true));
        rules.put("offline", Map.of(
                "balanceMode", "CACHED_MARKED_STALE",
                "withdrawalMode", "DENY",
                "depositMode", "CAPTURE_AND_QUEUE"));
        rules.put("limits", Map.of(
                "maxWithdrawalMinor", 50_000L,
                "maxDepositMinor", 100_000L,
                "sessionTimeoutSeconds", 600L));

        byte[] spki = Base64.getDecoder().decode(FederationBankV08Profile.DEMO_RULE_PUBLIC_KEY_SPKI_BASE64);
        PublicKey key = KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(spki));
        RuleVerifier verifier = new RuleVerifier(key);
        String signature = "vTV+IEl58BpTq5jdLMV90wC+bsNu07kIPsptBcKLosqGp5d9GAYuYr+/CABOwvWSyXOAaOFD0kr2L/4CtkkuAg==";
        check(verifier.verify(rules, signature, "Ed25519"), "v0.8 ooRexx fixture verifies in Java");
        Map<String,Object> wireRules = (Map<String,Object>) Json.parse(Json.stringify(rules));
        check(verifier.verify(wireRules, signature, "Ed25519"), "v0.8 signature survives JSON wire round-trip");

        Map<String,Object> changed = new LinkedHashMap<>(rules);
        Map<String,Object> offline = new LinkedHashMap<>((Map<String,Object>) rules.get("offline"));
        offline.put("withdrawalMode", "RESERVED_ALLOWANCE");
        changed.put("offline", offline);
        check(!verifier.verify(changed, signature, "Ed25519"), "v0.8 fixture detects rule mutation");
    }

    @SuppressWarnings("unchecked")
    private void tamperedRulesRejected() throws Exception {
        DemoBankNetwork bank = new DemoBankNetwork();
        BankRequest req = new BankRequest("federationbank.atm.request/0.1", "T-1", "T-1", "GET_RULES", "ATM-IOM-001", 1,
                "", Instant.now(), "", 0, Map.of());
        BankResponse r = bank.exchange(req);
        Map<String,Object> rules = new LinkedHashMap<>((Map<String,Object>)r.data().get("rules"));
        RuleVerifier verifier = new RuleVerifier(bank.rulesPublicKey());
        check(verifier.verify(rules, String.valueOf(r.data().get("signature")), "Ed25519"), "original rule signature valid");
        Map<String,Object> offline = new LinkedHashMap<>((Map<String,Object>)rules.get("offline"));
        offline.put("withdrawalMode", "UNLIMITED"); rules.put("offline", offline);
        check(!verifier.verify(rules, String.valueOf(r.data().get("signature")), "Ed25519"), "tampered rule rejected");
    }

    private static AtmService service(Path dir, BankNetwork network, PublicKey key, CashDispenser dispenser, DummyDepositAcceptor acceptor) throws Exception {
        return new AtmService("ATM-IOM-001", network, new RuleVerifier(key), new RuleStore(dir.resolve("rules.json")),
                new TransactionJournal(dir.resolve("journal.jsonl")), new TerminalSequence(dir.resolve("sequence.txt")), dispenser, acceptor);
    }

    private void run(String name, Checked test) {
        try { test.run(); passed++; System.out.println("PASS  " + name); }
        catch (Throwable e) { failed++; System.out.println("FAIL  " + name + " :: " + e); e.printStackTrace(System.out); }
    }

    private static void check(boolean value, String message) { if (!value) throw new AssertionError(message); }
    @FunctionalInterface private interface Checked { void run() throws Exception; }

    private static final class SimulatedPowerLoss extends RuntimeException {
        private static final long serialVersionUID = 1L;
        SimulatedPowerLoss() { super("simulated power loss after dispense start"); }
    }

    private static final class CrashAfterStartDispenser implements CashDispenser {
        @Override public com.federationbank.atm.cash.DispenseResult dispense(String currency, long amountMinor) {
            throw new SimulatedPowerLoss();
        }
    }

    private static final class SelectiveFailureNetwork implements BankNetwork {
        private final DemoBankNetwork delegate;
        String failOperation = "";
        int logoffCount;
        SelectiveFailureNetwork(DemoBankNetwork delegate) { this.delegate = delegate; }
        @Override public BankResponse exchange(BankRequest request) throws BankNetworkException {
            if (request.operation().equals("LOGOFF")) logoffCount++;
            if (request.operation().equals(failOperation)) throw new BankNetworkException("simulated unavailable " + failOperation);
            return delegate.exchange(request);
        }
        @Override public BankResponse pollRuleUpdate(long timeoutMillis) throws BankNetworkException { return delegate.pollRuleUpdate(timeoutMillis); }
        @Override public boolean isOnline() { return delegate.isOnline(); }
    }

    private static final class LostReplyNetwork implements BankNetwork {
        private final DemoBankNetwork delegate;
        boolean loseNextWithdrawCommitReply;
        boolean loseNextOfflineReleaseReply;
        LostReplyNetwork(DemoBankNetwork delegate) { this.delegate = delegate; }
        @Override public BankResponse exchange(BankRequest request) throws BankNetworkException {
            BankResponse r = delegate.exchange(request);
            if (loseNextWithdrawCommitReply && request.operation().equals("WITHDRAW_COMMIT")) {
                loseNextWithdrawCommitReply = false;
                throw new BankNetworkException("simulated lost reply after bank commit");
            }
            if (loseNextOfflineReleaseReply && request.operation().equals("RELEASE_OFFLINE_ALLOWANCE")) {
                loseNextOfflineReleaseReply = false;
                throw new BankNetworkException("simulated lost reply after offline allowance release");
            }
            return r;
        }
        @Override public BankResponse pollRuleUpdate(long timeoutMillis) throws BankNetworkException { return delegate.pollRuleUpdate(timeoutMillis); }
        @Override public boolean isOnline() { return delegate.isOnline(); }
    }
}

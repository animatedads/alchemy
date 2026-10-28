// Runs the Federation Bank Java ATM's offline cash rules on the cases SLAM chose from the rules it
// read in both languages. One fresh ATM per case: an authority is single-use.
// Architecture: Tom Dyer. Code: Claude (Opus 5.5), 2026-10-28.
// Prints one line per case:  CASE <name> <ok|refused> <code>
import com.federationbank.atm.AtmService;
import com.federationbank.atm.bank.DemoBankNetwork;
import com.federationbank.atm.cash.DummyCashDispenser;
import com.federationbank.atm.cash.DummyDepositAcceptor;
import com.federationbank.atm.domain.AccountSummary;
import com.federationbank.atm.domain.BankSession;
import com.federationbank.atm.domain.TransactionOutcome;
import com.federationbank.atm.journal.TerminalSequence;
import com.federationbank.atm.journal.TransactionJournal;
import com.federationbank.atm.rules.RuleStore;
import com.federationbank.atm.rules.RuleVerifier;
import java.nio.file.Files;
import java.nio.file.Path;

public final class OfflineRuleProbe {
    public static void main(String[] args) throws Exception {
        // EQ K:maxAmountMinor boundary: GE K:maxAmountMinor V must hold, so the max itself is allowed
        offline("MAX_EQUAL", 10_000L, 10_000L, false);
        offline("MAX_PLUS_ONE", 10_000L, 10_001L, false);
        // GT V N:0 is not in withdrawOffline; SLAM found it earlier on the path, in withdraw
        offline("ZERO", 10_000L, 0L, false);
        // EQ K:currency V: the bank upper-cases the presented currency, the ATM compares exactly
        offline("CURRENCY_LOWER", 10_000L, 10_000L, true);
    }

    static void offline(String name, long allowance, long amount, boolean lowerCurrency) throws Exception {
        Path dir = Files.createTempDirectory("slam-atm-");
        DemoBankNetwork bank = new DemoBankNetwork();
        try (AtmService atm = new AtmService("ATM-IOM-001", bank, new RuleVerifier(bank.rulesPublicKey()),
                new RuleStore(dir.resolve("rules.json")), new TransactionJournal(dir.resolve("journal.jsonl")),
                new TerminalSequence(dir.resolve("sequence.txt")), new DummyCashDispenser(), new DummyDepositAcceptor())) {
            atm.start();
            BankSession s = atm.logon("4111111111111111", "1234".toCharArray());
            AccountSummary a = atm.listAccounts(s).get(0);
            TransactionOutcome issued = atm.requestOfflineAllowance(s, a, allowance, "RESERVED_ALLOWANCE");
            if (!issued.ok()) { System.out.println("CASE " + name + " setup-failed " + issued.code()); return; }
            bank.setOnline(false);
            AccountSummary presented = lowerCurrency
                    ? new AccountSummary(a.accountId(), a.displayName(), a.productCode(), a.currency().toLowerCase(), a.status())
                    : a;
            TransactionOutcome out = atm.withdraw(s, presented, amount);
            System.out.println("CASE " + name + " " + (out.ok() ? "ok" : "refused") + " " + out.code()
                    + " currency=" + a.currency());
        }
    }
}

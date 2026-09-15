import com.federationbank.atm.AtmService;
import com.federationbank.atm.bank.JndiJmsBankNetwork;
import com.federationbank.atm.bank.FederationBankV08Profile;
import com.federationbank.atm.cash.DummyCashDispenser;
import com.federationbank.atm.cash.DummyDepositAcceptor;
import com.federationbank.atm.domain.AccountSummary;
import com.federationbank.atm.domain.Balance;
import com.federationbank.atm.domain.BankSession;
import com.federationbank.atm.domain.TransactionOutcome;
import com.federationbank.atm.journal.TerminalSequence;
import com.federationbank.atm.journal.TransactionJournal;
import com.federationbank.atm.rules.RuleStore;
import com.federationbank.atm.rules.RuleVerifier;

import java.nio.file.*;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.List;
import java.util.Properties;

public final class LiveAtmE2E {
  private static void check(boolean ok, String label) {
    if (!ok) throw new AssertionError(label);
    System.out.println("PASS " + label);
  }
  private static PublicKey bankKey() throws Exception {
    byte[] b = Base64.getDecoder().decode(FederationBankV08Profile.DEMO_RULE_PUBLIC_KEY_SPKI_BASE64);
    return KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(b));
  }
  public static void main(String[] args) throws Exception {
    String broker = args.length == 0 ? "tcp://127.0.0.1:61626" : args[0];
    Properties p = new Properties();
    p.setProperty("jms.initialContextFactory", "org.apache.activemq.jndi.ActiveMQInitialContextFactory");
    p.setProperty("jms.providerUrl", broker);
    p.setProperty("jms.connectionFactoryJndi", "ConnectionFactory");
    p.setProperty("jms.requestQueueJndi", "dynamicQueues/FB.ATM.REQUESTS");
    p.setProperty("jms.replyQueueJndi", "dynamicQueues/FB.ATM.REPLIES.ATM-IOM-001");
    p.setProperty("jms.requestTimeoutMillis", "10000");
    Path state = Files.createTempDirectory("fb-live-atm-");
    JndiJmsBankNetwork net = new JndiJmsBankNetwork(p);
    try (AtmService atm = new AtmService("ATM-IOM-001", net, new RuleVerifier(bankKey()),
        new RuleStore(state.resolve("rules.json")), new TransactionJournal(state.resolve("journal.jsonl")),
        new TerminalSequence(state.resolve("sequence.txt")), new DummyCashDispenser(), new DummyDepositAcceptor())) {
      atm.start();
      check("ACTIVE".equals(atm.terminalStatus()), "terminal sign-on through real JMS");
      check(atm.rules() != null && atm.rules().version() == 1, "signed bank rules over real JMS");
      BankSession session = atm.logon("4111111111111111", "1234".toCharArray());
      check("CUST-001".equals(session.customerId()), "customer authentication");
      List<AccountSummary> accounts = atm.listAccounts(session);
      AccountSummary account = accounts.stream().filter(a -> "GBP-001".equals(a.accountId())).findFirst().orElseThrow();
      check("GBP".equals(account.currency()), "customer-scoped account listing");
      Balance b0 = atm.balance(session, account);
      check(b0.bookBalanceMinor() == 125000 && b0.availableBalanceMinor() == 125000, "initial Ledger balance");
      TransactionOutcome wd = atm.withdraw(session, account, 10000);
      check(wd.ok() && wd.bankConfirmed(), "withdraw authorise + physical dispense + bank commit");
      Balance b1 = atm.balance(session, account);
      check(b1.bookBalanceMinor() == 115000 && b1.availableBalanceMinor() == 115000, "withdrawal exactly once");
      TransactionOutcome dep = atm.deposit(session, account, 20000);
      check(dep.ok() && dep.bankConfirmed(), "physical deposit + bank commit");
      Balance b2 = atm.balance(session, account);
      check(b2.bookBalanceMinor() == 135000 && b2.availableBalanceMinor() == 135000, "deposit exactly once");
      atm.logoff(session);
      check(net.isOnline(), "JMS network remains online");
    }
    System.out.println("FEDERATIONBANK JAVA ATM REAL JMS END-TO-END PASS 11");
  }
}

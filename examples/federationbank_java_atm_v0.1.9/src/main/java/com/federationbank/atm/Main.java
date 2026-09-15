package com.federationbank.atm;

import com.federationbank.atm.bank.BankNetwork;
import com.federationbank.atm.bank.DemoBankNetwork;
import com.federationbank.atm.bank.JndiJmsBankNetwork;
import com.federationbank.atm.bank.FederationBankV08Profile;
import com.federationbank.atm.cash.DummyCashDispenser;
import com.federationbank.atm.brokerage.BrokerageNetwork;
import com.federationbank.atm.brokerage.BrokerageService;
import com.federationbank.atm.brokerage.DemoBrokerageNetwork;
import com.federationbank.atm.brokerage.JndiJmsBrokerageNetwork;
import com.federationbank.atm.cash.DummyDepositAcceptor;
import com.federationbank.atm.journal.TerminalSequence;
import com.federationbank.atm.journal.TransactionJournal;
import com.federationbank.atm.rules.RuleStore;
import com.federationbank.atm.rules.RuleVerifier;
import com.federationbank.atm.ui.AtmConsole;
import com.federationbank.atm.ui.ConsoleIo;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.KeyFactory;
import java.security.PublicKey;
import java.security.spec.X509EncodedKeySpec;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

public final class Main {
    private Main() {}

    public static void main(String[] args) throws Exception {
        Map<String, String> options = parseArgs(args);
        Properties p = defaults();
        String configPath = options.get("config");
        if (configPath != null) try (InputStream in = Files.newInputStream(Path.of(configPath))) { p.load(in); }
        options.forEach((k, v) -> {
            if (k.equals("transport")) p.setProperty("transport", v);
            if (k.equals("terminal-id")) p.setProperty("atm.terminalId", v);
            if (k.equals("brokerage-transport")) p.setProperty("brokerage.transport", v);
        });

        String terminalId = p.getProperty("atm.terminalId", "ATM-IOM-001");
        String transport = p.getProperty("transport", "demo").trim().toLowerCase();
        DemoBankNetwork demo = null;
        BankNetwork network;
        PublicKey ruleKey;
        if (transport.equals("demo")) {
            demo = new DemoBankNetwork();
            network = demo;
            ruleKey = demo.rulesPublicKey();
        } else if (transport.equals("jms")) {
            network = new JndiJmsBankNetwork(p);
            String configuredKey = p.getProperty("bank.rules.publicKeyBase64", "").trim();
            boolean useV08Fixture = Boolean.parseBoolean(p.getProperty("bank.rules.useFederationBankV08DemoKey", "false"));
            if (configuredKey.isEmpty() && useV08Fixture) configuredKey = FederationBankV08Profile.DEMO_RULE_PUBLIC_KEY_SPKI_BASE64;
            if (configuredKey.isEmpty()) throw new IOException("missing required configuration: bank.rules.publicKeyBase64 (or explicitly enable bank.rules.useFederationBankV08DemoKey for the v0.8 demo gateway)");
            ruleKey = decodePublicKey(configuredKey);
        } else throw new IllegalArgumentException("transport must be demo or jms");

        String brokerageTransport = p.getProperty("brokerage.transport", "auto").trim().toLowerCase();
        if (brokerageTransport.equals("auto")) brokerageTransport = transport.equals("demo") ? "demo" : "disabled";
        DemoBrokerageNetwork demoBrokerage = null;
        BrokerageNetwork brokerageNetwork = null;
        if (brokerageTransport.equals("demo")) {
            demoBrokerage = new DemoBrokerageNetwork();
            brokerageNetwork = demoBrokerage;
        } else if (brokerageTransport.equals("jms")) {
            brokerageNetwork = new JndiJmsBrokerageNetwork(p);
        } else if (!brokerageTransport.equals("disabled")) {
            throw new IllegalArgumentException("brokerage.transport must be auto, demo, jms or disabled");
        }
        BrokerageService brokerage = brokerageNetwork == null ? null : new BrokerageService(terminalId, brokerageNetwork);

        boolean ansi = ansi(options.getOrDefault("ansi", p.getProperty("atm.ansi", "auto")));
        boolean visiblePin = options.containsKey("allow-visible-demo-pin");
        AtmService service = new AtmService(terminalId, network, new RuleVerifier(ruleKey),
                new RuleStore(Path.of(p.getProperty("atm.rulesPath", "var/atm-rules.json"))),
                new TransactionJournal(Path.of(p.getProperty("atm.journalPath", "var/atm-journal.jsonl"))),
                new TerminalSequence(Path.of(p.getProperty("atm.sequencePath", "var/terminal-sequence.txt"))),
                new DummyCashDispenser(), new DummyDepositAcceptor());

        try (service; brokerage) {
            service.start();
            new AtmConsole(service, brokerage, new ConsoleIo(System.in, System.out, visiblePin), demo, demoBrokerage, ansi).run();
        }
    }

    private static Properties defaults() {
        Properties p = new Properties();
        p.setProperty("transport", "demo"); p.setProperty("atm.terminalId", "ATM-IOM-001");
        p.setProperty("atm.ansi", "auto"); p.setProperty("atm.journalPath", "var/atm-journal.jsonl");
        p.setProperty("atm.sequencePath", "var/terminal-sequence.txt"); p.setProperty("atm.rulesPath", "var/atm-rules.json");
        p.setProperty("brokerage.transport", "auto");
        return p;
    }

    private static Map<String, String> parseArgs(String[] args) {
        Map<String, String> out = new HashMap<>();
        for (String arg : args) {
            if (!arg.startsWith("--")) throw new IllegalArgumentException("unknown argument: " + arg);
            String body = arg.substring(2); int eq = body.indexOf('=');
            if (eq < 0) out.put(body, "true"); else out.put(body.substring(0, eq), body.substring(eq + 1));
        }
        return out;
    }

    private static boolean ansi(String mode) {
        return switch (mode.toLowerCase()) {
            case "always", "true", "yes" -> true;
            case "never", "false", "no" -> false;
            case "auto" -> System.console() != null && System.getenv("NO_COLOR") == null && !"dumb".equals(System.getenv("TERM"));
            default -> throw new IllegalArgumentException("atm.ansi must be auto/always/never");
        };
    }

    private static PublicKey decodePublicKey(String base64) throws Exception {
        byte[] bytes = Base64.getDecoder().decode(base64.replaceAll("\\s+", ""));
        return KeyFactory.getInstance("Ed25519").generatePublic(new X509EncodedKeySpec(bytes));
    }

    private static String required(Properties p, String key) throws IOException {
        String v = p.getProperty(key, "").trim();
        if (v.isEmpty()) throw new IOException("missing required configuration: " + key);
        return v;
    }
}

package com.federationbank.atm.ui;

import com.federationbank.atm.AtmService;
import com.federationbank.atm.bank.BankNetworkException;
import com.federationbank.atm.bank.DemoBankNetwork;
import com.federationbank.atm.brokerage.BrokerageNetworkException;
import com.federationbank.atm.brokerage.BrokerageService;
import com.federationbank.atm.brokerage.DemoBrokerageNetwork;
import com.federationbank.atm.brokerage.MerchantPositionSummary;
import com.federationbank.atm.domain.AccountSummary;
import com.federationbank.atm.domain.AtmRules;
import com.federationbank.atm.domain.Balance;
import com.federationbank.atm.domain.BankSession;
import com.federationbank.atm.domain.TransactionOutcome;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import java.util.Optional;

public final class AtmConsole {
    private final AtmService atm;
    private final BrokerageService brokerage;
    private final ConsoleIo io;
    private final DemoBankNetwork demoNetwork;
    private final DemoBrokerageNetwork demoBrokerage;
    private final boolean ansi;

    public AtmConsole(AtmService atm, BrokerageService brokerage, ConsoleIo io,
                      DemoBankNetwork demoNetwork, DemoBrokerageNetwork demoBrokerage, boolean ansi) {
        this.atm = atm;
        this.brokerage = brokerage;
        this.io = io;
        this.demoNetwork = demoNetwork;
        this.demoBrokerage = demoBrokerage;
        this.ansi = ansi;
    }

    public void run() throws IOException {
        io.println(TerminalBranding.banner(ansi));
        io.printf("Terminal: %s%n", atm.terminalId());
        io.printf("Bank network      : %s%n", atm.connectionStatus());
        io.printf("Brokerage service : %s%n%n", brokerageStatus());
        while (true) {
            io.println("1. Log on");
            io.println("2. Terminal status");
            if (demoBrokerage != null) io.println("8. Demo operator: toggle brokerage connection");
            if (demoNetwork != null) io.println("9. Demo operator: toggle bank connection");
            io.println("0. Exit");
            String choice = io.line("Selection: ");
            if (choice == null || choice.trim().equals("0")) return;
            try {
                switch (choice.trim()) {
                    case "1" -> customerSession();
                    case "2" -> status();
                    case "8" -> { if (demoBrokerage != null) toggleDemoBrokerage(); else io.println("Unknown selection."); }
                    case "9" -> { if (demoNetwork != null) toggleDemoNetwork(); else io.println("Unknown selection."); }
                    default -> io.println("Unknown selection.");
                }
            } catch (AtmService.BankOperationException e) {
                io.printf("Bank response: %s - %s%n%n", e.code(), e.getMessage());
            } catch (BankNetworkException e) {
                io.printf("Bank network unavailable: %s%n%n", e.getMessage());
            }
        }
    }

    private void customerSession() throws IOException, BankNetworkException {
        String card = io.line("Card/customer number: ");
        if (card == null) return;
        char[] pin = io.secret("PIN: ");
        if (pin == null) return;
        BankSession session = atm.logon(card.trim(), pin);
        io.printf("%nWelcome, %s%n%n", session.customerDisplayName());
        try {
            List<AccountSummary> accounts = atm.listAccounts(session);
            if (accounts.isEmpty()) { io.println("No available accounts."); return; }
            int accountIndex = 0;
            while (accountIndex >= 0) {
                AccountSummary selected = chooseAccount(accounts);
                if (selected == null) return;
                accountIndex = accountMenu(session, selected) ? 0 : -1;
            }
        } finally {
            atm.logoff(session);
            io.println("Logged out.\n");
        }
    }

    private AccountSummary chooseAccount(List<AccountSummary> accounts) throws IOException {
        io.println("Retail Bank Accounts");
        for (int i = 0; i < accounts.size(); i++) {
            AccountSummary a = accounts.get(i);
            io.printf("  %d. %-24s %s%n", i + 1, a.displayName(), a.currency());
        }
        io.println("  0. Log out");
        String text = io.line("Select account: ");
        if (text == null || text.trim().equals("0")) return null;
        try {
            int i = Integer.parseInt(text.trim()) - 1;
            if (i >= 0 && i < accounts.size()) return accounts.get(i);
        } catch (NumberFormatException ignored) {}
        io.println("Invalid account selection.\n");
        return chooseAccount(accounts);
    }

    /** true = change account, false = log out */
    private boolean accountMenu(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        while (true) {
            io.printf("%n%s (%s)%n", account.displayName(), account.currency());
            io.println("1. Balance");
            io.println("2. Withdraw cash");
            io.println("3. Deposit cash");
            io.println("4. Reserve funds for offline cash");
            io.println("5. Return unused offline cash authority");
            if (brokerage != null) io.println("6. Merchant Bank derivatives position (separate relationship)");
            io.println("7. Change account");
            if (demoBrokerage != null) io.println("8. Demo operator: toggle brokerage connection");
            if (demoNetwork != null) io.println("9. Demo operator: toggle bank connection");
            io.println("0. Log out");
            String choice = io.line("Selection: ");
            if (choice == null || choice.trim().equals("0")) return false;
            switch (choice.trim()) {
                case "1" -> showBalance(session, account);
                case "2" -> withdraw(session, account);
                case "3" -> deposit(session, account);
                case "4" -> reserveOfflineCash(session, account);
                case "5" -> returnOfflineCashAuthority(session);
                case "6" -> { if (brokerage != null) showMerchantPosition(session); else io.println("Unknown selection."); }
                case "7" -> { return true; }
                case "8" -> { if (demoBrokerage != null) toggleDemoBrokerage(); else io.println("Unknown selection."); }
                case "9" -> { if (demoNetwork != null) toggleDemoNetwork(); else io.println("Unknown selection."); }
                default -> io.println("Unknown selection.");
            }
        }
    }

    private void showBalance(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        Balance b = atm.balance(session, account);
        io.printf("Available balance: %s%n", money(b.currency(), b.availableBalanceMinor()));
        io.printf("Book balance     : %s%n", money(b.currency(), b.bookBalanceMinor()));
        if (b.heldMinor() != 0) io.printf("Active holds     : %s%n", money(b.currency(), b.heldMinor()));
        io.printf("As of            : %s%s%n", b.asOf(), b.stale() ? "  *** CACHED / MAY BE STALE ***" : "");
    }

    private void withdraw(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        Long amount = amount(io.line("Amount to withdraw: "));
        if (amount == null) { io.println("Invalid amount."); return; }
        if (!confirm("Dispense " + money(account.currency(), amount) + "? [y/N]: ")) return;
        TransactionOutcome result = atm.withdraw(session, account, amount);
        io.printf("%s: %s%n", result.code(), result.detail());
        if (!result.bankConfirmed() && result.amountMinor() > 0)
            io.println("IMPORTANT: physical cash state is recorded; do not repeat this withdrawal.");
    }

    private void deposit(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        Long amount = amount(io.line("Cash amount to insert (dummy acceptor): "));
        if (amount == null) { io.println("Invalid amount."); return; }
        if (!confirm("Simulate accepting " + money(account.currency(), amount) + "? [y/N]: ")) return;
        TransactionOutcome result = atm.deposit(session, account, amount);
        io.printf("%s: %s%n", result.code(), result.detail());
        if (!result.bankConfirmed() && result.amountMinor() > 0)
            io.println("Receipt status: CASH RECEIVED BY TERMINAL / BANK CONFIRMATION PENDING");
    }

    private void reserveOfflineCash(BankSession session, AccountSummary account) throws IOException, BankNetworkException {
        Long amount = amount(io.line("Amount to reserve for possible offline cash: "));
        if (amount == null) { io.println("Invalid amount."); return; }
        TransactionOutcome result = atm.requestOfflineAllowance(session, account, amount, "RESERVED_ALLOWANCE");
        io.printf("%s: %s%n", result.code(), result.detail());
        if (result.ok()) io.println("The reserved amount is no longer available for other withdrawals until used or returned.");
    }

    private void returnOfflineCashAuthority(BankSession session) throws IOException {
        int released = atm.releaseUnusedOfflineAllowances(session);
        if (released == 0) io.println("No unused offline cash authority was returned.");
        else io.printf("Returned %d unused offline cash authorit%s.%n", released, released == 1 ? "y" : "ies");
    }

    private void showMerchantPosition(BankSession session) throws IOException {
        if (brokerage == null) { io.println("Merchant Bank position enquiry is not configured."); return; }
        try {
            Optional<MerchantPositionSummary> result = brokerage.currentMerchantPosition(session);
            if (result.isEmpty()) {
                io.println("No linked Merchant Bank retail derivatives relationship was found.");
                return;
            }
            MerchantPositionSummary p = result.get();
            io.println("");
            io.println("FEDERATION BANK AUSTRALIA IOM");
            io.println("Merchant Bank - Derivatives Position Summary");
            io.println("------------------------------------------------");
            io.printf("Market value       : %s%n", money(p.currency(), p.netMarketValueMinor()));
            io.printf("Unrealised P/L     : %s%n", signedMoney(p.currency(), p.unrealisedPnlMinor()));
            io.printf("Realised P/L       : %s%n", signedMoney(p.currency(), p.realisedPnlMinor()));
            io.printf("Margin / collateral: %s%n", money(p.currency(), p.collateralMinor()));
            io.printf("Required margin    : %s%n", money(p.currency(), p.marginRequiredMinor()));
            io.printf("Available margin   : %s%n", money(p.currency(), p.availableMarginMinor()));
            io.printf("Open positions     : %d%n", p.positionCount());
            io.printf("Valuation status   : %s%n", p.valuationStatus());
            io.printf("As at              : %s%n", p.valuationTime());
            io.printf("Source authority   : %s%n", p.sourceAuthority());
            io.println("------------------------------------------------");
            io.println("Market prices may have changed.");
            io.println("This is NOT a Retail Bank balance and does not change cash available to withdraw.");
        } catch (BrokerageNetworkException e) {
            io.printf("Merchant Bank position service unavailable: %s%n", e.getMessage());
            io.println("No cached derivatives position is displayed as current.");
        }
    }

    private void status() {
        io.printf("%nTerminal status   : %s%n", atm.terminalStatus());
        io.printf("Bank connection   : %s%n", atm.connectionStatus());
        io.printf("Brokerage service : %s%n", brokerageStatus());
        AtmRules r = atm.rules();
        if (r == null) io.println("Bank rules        : NONE");
        else {
            io.printf("Bank rules        : %s v%d (valid until %s)%n", r.rulesetId(), r.version(), r.validUntil());
            io.printf("Offline cash      : %s%n", r.offlineWithdrawalMode());
            io.printf("Offline deposit   : %s%n", r.offlineDepositMode());
        }
        if (!atm.lastRuleError().isBlank()) io.printf("Last rule error   : %s%n", atm.lastRuleError());
        io.println("");
    }

    private String brokerageStatus() {
        if (brokerage == null) return "NOT CONFIGURED";
        return brokerage.isOnline() ? "ONLINE" : "OFFLINE / UNKNOWN";
    }

    private void toggleDemoNetwork() {
        demoNetwork.setOnline(!demoNetwork.isOnline());
        io.printf("Demo bank connection is now %s.%n%n", demoNetwork.isOnline() ? "ONLINE" : "OFFLINE");
    }

    private void toggleDemoBrokerage() {
        demoBrokerage.setOnline(!demoBrokerage.isOnline());
        io.printf("Demo brokerage connection is now %s.%n%n", demoBrokerage.isOnline() ? "ONLINE" : "OFFLINE");
    }

    private boolean confirm(String prompt) throws IOException {
        String answer = io.line(prompt);
        return answer != null && (answer.equalsIgnoreCase("y") || answer.equalsIgnoreCase("yes"));
    }

    private static Long amount(String text) {
        if (text == null) return null;
        try {
            BigDecimal v = new BigDecimal(text.trim()).setScale(2, RoundingMode.UNNECESSARY);
            if (v.signum() <= 0) return null;
            return v.movePointRight(2).longValueExact();
        } catch (Exception e) { return null; }
    }

    private static String money(String currency, long minor) {
        BigDecimal v = BigDecimal.valueOf(minor, 2);
        return currency + " " + String.format("%,.2f", v);
    }

    private static String signedMoney(String currency, long minor) {
        if (minor > 0) return "+" + money(currency, minor);
        return money(currency, minor);
    }
}

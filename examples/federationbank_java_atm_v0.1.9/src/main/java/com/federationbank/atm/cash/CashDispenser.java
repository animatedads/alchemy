package com.federationbank.atm.cash;

public interface CashDispenser {
    DispenseResult dispense(String currency, long amountMinor);
}

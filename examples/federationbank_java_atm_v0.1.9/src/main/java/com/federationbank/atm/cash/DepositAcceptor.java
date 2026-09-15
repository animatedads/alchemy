package com.federationbank.atm.cash;

public interface DepositAcceptor {
    DepositResult accept(String currency, long expectedMinor);
}

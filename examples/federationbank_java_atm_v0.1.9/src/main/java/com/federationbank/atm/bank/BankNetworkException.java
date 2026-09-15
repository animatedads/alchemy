package com.federationbank.atm.bank;

public class BankNetworkException extends Exception {
    private static final long serialVersionUID = 1L;
    public BankNetworkException(String message) { super(message); }
    public BankNetworkException(String message, Throwable cause) { super(message, cause); }
}

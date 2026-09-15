package com.federationbank.atm.brokerage;

public final class BrokerageNetworkException extends Exception {
    private static final long serialVersionUID = 1L;
    public BrokerageNetworkException(String message) { super(message); }
    public BrokerageNetworkException(String message, Throwable cause) { super(message, cause); }
}

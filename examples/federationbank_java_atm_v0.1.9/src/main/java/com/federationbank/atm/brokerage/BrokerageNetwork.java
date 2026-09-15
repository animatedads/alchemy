package com.federationbank.atm.brokerage;

public interface BrokerageNetwork extends AutoCloseable {
    boolean isOnline();
    BrokerageResponse exchange(BrokerageRequest request) throws BrokerageNetworkException;
    @Override default void close() {}
}

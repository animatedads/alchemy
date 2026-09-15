package com.federationbank.atm.bank;

import com.federationbank.atm.protocol.BankRequest;
import com.federationbank.atm.protocol.BankResponse;

/** Transport-neutral ATM network boundary. */
public interface BankNetwork extends AutoCloseable {
    BankResponse exchange(BankRequest request) throws BankNetworkException;

    /** Optional non-blocking/polling delivery of a bank-published rules update. */
    default BankResponse pollRuleUpdate(long timeoutMillis) throws BankNetworkException { return null; }

    boolean isOnline();

    @Override default void close() {}
}

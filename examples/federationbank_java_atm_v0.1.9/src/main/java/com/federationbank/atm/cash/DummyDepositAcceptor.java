package com.federationbank.atm.cash;

import java.util.UUID;

public final class DummyDepositAcceptor implements DepositAcceptor {
    private volatile boolean rejectNext;
    public void rejectNext() { rejectNext = true; }
    @Override public DepositResult accept(String currency, long expectedMinor) {
        boolean reject = rejectNext;
        rejectNext = false;
        String id = "PHYS-DEP-" + UUID.randomUUID();
        return reject
                ? new DepositResult(false, 0, id, "dummy acceptor rejected cash")
                : new DepositResult(true, expectedMinor, id, "dummy acceptor counted cash");
    }
}

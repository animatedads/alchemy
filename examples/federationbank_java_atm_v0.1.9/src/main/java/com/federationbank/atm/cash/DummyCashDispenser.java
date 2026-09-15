package com.federationbank.atm.cash;

import java.util.UUID;

/** Simulated physical dispenser; tests may inject a one-shot failure or partial dispense. */
public final class DummyCashDispenser implements CashDispenser {
    private volatile DispenseResult.Status nextStatus = DispenseResult.Status.SUCCESS;
    public void failNext() { nextStatus = DispenseResult.Status.FAILURE; }
    public void partialNext() { nextStatus = DispenseResult.Status.PARTIAL; }

    @Override public DispenseResult dispense(String currency, long amountMinor) {
        DispenseResult.Status status = nextStatus;
        nextStatus = DispenseResult.Status.SUCCESS;
        String id = "PHYS-DISP-" + UUID.randomUUID();
        return switch (status) {
            case SUCCESS -> new DispenseResult(status, amountMinor, amountMinor, id, "dummy dispenser completed");
            case FAILURE -> new DispenseResult(status, amountMinor, 0, id, "dummy dispenser jam/no cash dispensed");
            case PARTIAL -> new DispenseResult(status, amountMinor, amountMinor / 2, id, "dummy partial dispense; reconciliation required");
        };
    }
}

package com.federationbank.atm.domain;

public record TransactionOutcome(boolean ok, String code, String detail, String transactionId,
                                 long amountMinor, boolean bankConfirmed) {
    public static TransactionOutcome failed(String code, String detail, String tx) {
        return new TransactionOutcome(false, code, detail, tx, 0, false);
    }
}

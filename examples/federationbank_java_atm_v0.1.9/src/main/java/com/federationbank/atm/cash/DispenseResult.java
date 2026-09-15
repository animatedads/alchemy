package com.federationbank.atm.cash;

public record DispenseResult(Status status, long requestedMinor, long dispensedMinor, String physicalTransactionId, String detail) {
    public enum Status { SUCCESS, FAILURE, PARTIAL }
}

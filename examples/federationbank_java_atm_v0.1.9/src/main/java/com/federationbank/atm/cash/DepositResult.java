package com.federationbank.atm.cash;

public record DepositResult(boolean accepted, long acceptedMinor, String physicalTransactionId, String detail) {}

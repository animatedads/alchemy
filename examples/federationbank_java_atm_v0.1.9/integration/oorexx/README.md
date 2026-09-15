# FederationBank ATM composed ooRexx integration

This directory contains deterministic acceptance harnesses that compose the real project layers around the Java ATM wire contract:

```text
JMS-shaped delivery
  -> JMSQueueBridgeService (dev7-fb1)
  -> Queue Fabric
  -> FederationBankAtmGateway.processBridgeMessage()
  -> Payments Engine
  -> Ledger Engine / SQL fixture store
  -> Queue Fabric
  -> JMSQueueBridgeService
  -> captured JMS-shaped reply
```

No fake banking logic is used by these harnesses. Monetary holds, postings, durable idempotency, offline authorities and balances come from FederationBank.

## JSON boundary compatibility

`federationbank_v0.8_atm_json_boundary.patch` and `federationbank_v0.9_atm_json_boundary.patch` canonicalise ooRexx `json.cls` `.JsonString` wrappers to ordinary strings at the ATM gateway boundary before durable Queue Fabric payloads are built. The original defect was independently reproduced as `PAYLOAD_NOT_PERSISTABLE:Directory`.

## v0.9 offline authority

`test_federationbank_v09_offline_roundtrip.rex` proves:

```text
GET_OFFLINE_ALLOWANCE
  -> real Ledger hold
  -> disconnected physical cash fact
  -> reconnect OFFLINE_WITHDRAWAL_ADVICE
  -> one settlement
  -> replay harmless
  -> authority reuse rejected
```

## v0.1.6 partial-cash work

`test_federationbank_v09_partial_offline_roundtrip.rex` runs against stock JSON-boundary-compatible v0.9 and demonstrates both current behaviours:

- `DELEGATED_STAND_IN`: an authority ceiling of 10000 may settle actual partial cash of 5000;
- `RESERVED_ALLOWANCE`: a 10000 hold followed by 5000 physical cash is rejected with `ATM_HOLD_MISMATCH`, leaving the hold active.

`federationbank_v0.9_atm_partial_reservation.patch` is a narrow bank candidate. It permits a single-use reserved authority to settle any positive actual cash amount up to its reservation ceiling, releases the unused reservation, reports `reservedMinor` / `unusedReservedMinor`, and rejects `amountMinor != dispensedMinor`.

`test_federationbank_v09_partial_reservation_candidate.rex` qualifies that candidate.

The supplied bank source is never silently replaced by these patches; the scripts use disposable copies or expect an explicitly selected patched tree.

## Live broker evidence

The actual `oorexx_jms_queue_bridge_v0.1-dev7-fb1`, BSF4ooRexx v850 and ActiveMQ 5.18.3 were previously exercised end-to-end for ATM v0.1.4. `JndiJmsBankNetwork` is unchanged. The v0.1.6 partial-cash semantics are newly qualified through the delivered dev7-fb1 neutral bridge and Queue Fabric composed boundary; this package does not claim that the new partial-cash scenario itself was re-run through a physical ActiveMQ broker.

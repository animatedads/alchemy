# FederationBank real JMS qualification — ATM v0.1.4

This qualification deliberately exercises the transport boundary rather than
substituting an in-process bank network.

## Executed path

```text
Java AtmService / JndiJmsBankNetwork
  -> ActiveMQ 5.18.3
  -> BSF4ooRexx v850
  -> ooRexx JMS Queue Bridge v0.1-dev7-fb1
  -> durable Queue Fabric
  -> FederationBank v0.8 ATM Gateway
  -> Payments Engine
  -> Ledger Engine
  -> durable Queue Fabric
  -> JMS reply
  -> Java AtmService
```

Runtime: ooRexx 5.3.0 r13196 and Java 21.  The bank side uses the v0.8
JSON-boundary compatibility patch shipped under `integration/oorexx/`; it does
not move banking authority into the ATM or bridge.

## Result

`FEDERATIONBANK JAVA ATM REAL JMS END-TO-END PASS 11`

Observed customer journey:

1. terminal sign-on accepted;
2. signed bank rules crossed JMS and verified with the v0.8 Ed25519 key;
3. CUST-001 authenticated;
4. GBP-001 was returned by customer-scoped account listing;
5. opening book/available balance was 125000 minor units;
6. WDA authorised a 10000-minor-unit withdrawal and created the bank hold;
7. physical dispense was followed by WDM commit;
8. book/available balance became 115000;
9. a 20000-minor-unit physical deposit committed;
10. book/available balance became 135000;
11. logoff completed and the JMS network remained online.

## Defects found only by the literal cross-language run

### Java integer JSON promotion

The parser used a conditional expression returning `Double` or `Long`. Java
numeric promotion caused integer tokens to become `Double`, so a signed rule
value such as `50000` canonicalised as `50000.0` after transport. Ed25519
verification correctly rejected it. v0.1.4 uses explicit branches and adds a
wire-round-trip signature regression.

### Timestamp precision

`Instant.now()` may emit nanosecond precision while ooRexx
`DateTime~fromIsoDate` rejects the nine-digit form used by Java. ATM requests
now emit UTC timestamps at millisecond precision. Operation identity and replay
safety continue to use terminal sequence and idempotency keys, not timestamp
precision.

## Reproduction harnesses

- `integration/java/LiveAtmE2E.java` — drives the real ATM client.
- `integration/oorexx/live_atm_server.rex` — hosts the real v0.8 ATM gateway,
  Payments/Ledger fixtures, Queue Fabric and JMS bridge against a configured
  broker.

These are qualification harnesses, not production service launchers.

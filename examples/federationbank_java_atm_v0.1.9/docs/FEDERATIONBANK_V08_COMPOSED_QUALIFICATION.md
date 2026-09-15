# FederationBank v0.8 composed ATM qualification

ATM v0.1.2 adds a composed acceptance test rather than relying only on the Java
simulator and the bank's direct gateway unit tests.

## Qualified path

The test uses the real `JMSQueueBridgeService`, real Queue Fabric, real
`FederationBankAtmGateway`, Payments Engine and Ledger Engine.  The Java/JMS
provider edge is represented by a deterministic provider implementing the same
neutral bridge contract.

Covered operations:

- terminal sign-on;
- customer logon;
- balance query;
- withdrawal authorisation -> Ledger-owned hold;
- withdrawal commit -> exactly two monetary legs;
- fresh JMS redelivery of the same WDM command -> bank idempotent replay;
- same-transfer-ID broker redelivery -> Queue Fabric duplicate suppression;
- deposit commit;
- fresh JMS redelivery of the same DPM command -> no duplicate credit;
- JMS correlation ID preservation on replies.

## Defect exposed

The original FederationBank v0.8 `processBridgeMessage()` leaves `.JsonString`
parser wrappers in the request object.  The money tests call `handleRequest()`
directly with native ooRexx values, so the defect is invisible there.

Through the actual TEXT/JSON gateway boundary, `WITHDRAW_COMMIT` originally
failed with:

```text
ATM_BACKEND_SUBMIT_FAILED
PAYLOAD_NOT_PERSISTABLE:Directory
```

The compatibility patch canonicalises `.JsonString` values immediately after
wire parsing and before constructing durable banking commands.  With that patch,
the complete composed path passes, including both idempotency layers.

## Qualification status

Validated locally with the user-supplied ooRexx 5.3.0 r13196 debug runtime and
the supplied v0.8 dependency family.  The bank regression suite was run through
the ATM tests and subsequent suite; all test scripts passed.  The complete
single `run_tests.sh` invocation exceeded the execution sandbox's 45-second
command window late in the suite, so the remaining tests and smoke runtime were
then run separately and passed.

This is **not yet a live JMS broker qualification** because BSF4ooRexx and a JMS
provider implementation/broker are not present in the supplied roll-up.

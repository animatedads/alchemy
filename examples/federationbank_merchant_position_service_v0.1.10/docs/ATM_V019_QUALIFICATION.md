# FederationBank Java ATM v0.1.9 brokerage qualification

The supplied ATM v0.1.9 package was independently checked before the Merchant endpoint was implemented:

- `MANIFEST.sha256`: PASS
- Java test suite: 22/22 PASS

The Merchant position service implements the exact brokerage schemas and operation documented by ATM v0.1.9:

- request: `federationbank.brokerage.atm.request/0.1`
- response: `federationbank.brokerage.atm.response/0.1`
- operation: `GET_MERCHANT_POSITION_SUMMARY`
- source authority: `FEDERATION_BROKERAGE_POSITION_AUTHORITY`

A real transport qualification was then run with:

```text
Java ATM v0.1.9 BrokerageService
 -> JndiJmsBrokerageNetwork
 -> ActiveMQ 5.18.3
 -> BSF4ooRexx v850
 -> ooRexx JMS Queue Bridge v0.1-dev7-fb1
 -> FederationBank Merchant Position Service v0.1
 -> Merchant Bank v0.2
 -> correlated JMS reply
 -> Java ATM v0.1.9
```

Observed result:

```text
JAVA ATM BROKERAGE REAL JMS PASS relationship=BRK-RET-0002 marketValue=7244000 positions=2
MERCHANT POSITION REAL JMS SERVER PASS
```

The live fixture uses an injected `LiveLinkageAuthority` as the stand-in for the independent Retail/Core trust/linkage service. The Merchant endpoint itself never derives a Merchant relationship directly from a bare customer ID.

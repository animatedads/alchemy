# FederationBank / IJCIB JMS Boundary v0.3

## Ownership

IJCIB is an external sealed credit-reference bureau. FederationBank does not own its methodology, reason-code meanings, product schedule or operational behaviour.

Only FederationBank Account Authority may call it. Browser/Wire UI and Payments/Ledger do not receive broker credentials and do not invoke the bureau.

## Design rule

The bureau returns a **Credit Intelligence Product**, not a FederationBank account-opening decision.

FederationBank Institutional Policy consumes the published bureau evidence and decides `ACCEPTED`, `REFERRED` or `REJECTED` for a bank product. Opaque IJCIB reason codes remain opaque.

## Wire shape

The bank-side adapter targets the supplied IJCIB-style JMS contract and therefore preserves the provider's required interface rather than replacing it with a friendly REST-like abstraction.

The compatibility path uses:

- JMS `MapMessage`;
- exact provider-owned `IJCIB_*` properties;
- explicit request identity and correlation token;
- request nonce;
- SHA-512 request digest;
- institution identity;
- policy-selected opaque bureau product code;
- customer/request/product/currency/purpose facts;
- CivicPort address verification reference where applicable.

Broker URL, credentials and Secret Broker material remain below the JMS adapter boundary.

## Product evidence retained by FederationBank

The adapter preserves, when supplied:

```text
protocol version
request id
correlation token
bureau product id
bureau reference
generation timestamp
methodology version
overall disposition
scaled value (optional)
scale minimum / maximum
scale direction
normalisation method
score-band label
confidence material
suppression flags
opaque reason-code tree
source/adverse-indicator material
disclaimers
next permitted refresh not-before
raw provider product payload
```

A suppressed or missing scaled value remains absent. It must never be normalised to zero.

## Refresh/retry semantics

IJCIB may specify when FederationBank is next permitted to refresh a product. That restriction is external evidence and must be preserved. FederationBank must not invent its own meaning for a bureau reason code to decide whether the restriction can be bypassed.

Transport timeout/refusal/unavailability is a failed external observation. Account Authority maps it to a structured non-monetary bank outcome according to bank policy; no customer/account state is committed merely because the bureau is unavailable.

## Persistence

The complete IJCIB product is persisted as immutable evidence in its own SQL evidence row inside the same serializable transaction as the accepted account-opening state and durable command receipt.

The normal receipt carries only compact bureau identity/disposition fields so receipt SQL remains bounded.

## Bridge requirement

The supplied JMS Queue Bridge dev6 did not provide the complete BSF edge required by this contract. FederationBank therefore carries a narrow compatibility candidate, `oorexx_jms_queue_bridge_v0.1-dev7-fb1`, adding MAP message handling and arbitrary property forwarding.

Deterministic bridge tests and FederationBank MAP/property contract tests pass. A live BSF4ooRexx/IJCIB broker qualification is not claimed by v0.3.

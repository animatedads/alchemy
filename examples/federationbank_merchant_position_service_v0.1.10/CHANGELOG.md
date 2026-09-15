# Changelog

## v0.1.10

- Dependency-only qualification against FederationBank Merchant Bank v0.13.
- No ATM brokerage request/response or authority semantics changed.

## v0.1.9

- Dependency-only qualification against FederationBank Merchant Bank v0.12.
- No ATM/JMS request, authority, or bounded position-summary semantics changed.

## v0.1.7

- Dependency-only qualification against reconciled FederationBank Merchant Bank v0.9.
- No API or authority-boundary changes.
- ATM remains read-only and receives only the bounded Merchant position summary.


## v0.1.6

- Dependency-only qualification against FederationBank Merchant Bank v0.8.
- No ATM/JMS request, authority or projection semantics changed.
- Whole-book/remediation state remains Merchant-internal and does not become retail withdrawal availability.

## v0.1.5

- Dependency-only qualification against FederationBank Merchant Bank v0.7.
- No request/response or authority semantics changed.
- Closed client positions remain excluded from the client count while live contracts/remediation remain Merchant-risk concerns.

## v0.1.4

- Dependency-qualification cut against `federationbank_merchant_bank_v0.6`.
- No request/response or authority semantic change.
- Reconfirmed that a client-visible closed CFD can remain represented by live monitored contracts and hedge-equivalence evidence inside Merchant Banking.

## v0.1.3

Dependency-qualification cut only: source semantics unchanged from v0.1.2; qualified against FederationBank Merchant Bank v0.5 evidence-bound instrument identity.


## v0.1.3

- Dependency-qualification cut against `federationbank_merchant_bank_v0.5`.
- No position-enquiry protocol or service semantic changes.
- ATM v0.1.9 read-only brokerage contract remains unchanged.

## v0.1

- Initial read-only Merchant position service.

## v0.1.3

- Requalified unchanged read-only ATM/JMS contract against Merchant Bank v0.5.
- Client position count now inherits v0.5 economic-position semantics while live CFD contracts remain monitored in the Merchant risk book.

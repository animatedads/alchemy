# FederationBank Merchant Collateral Adapter v0.1.11

Merchant-side integration of the arm's-length collateral protocol with the Merchant Bank collateral book.

It validates the Core Banking decision through the protocol validator, then rechecks the exact Merchant agreement, legal entity, Core asset reference, secured obligation, currency and controlled amount before registering Core control evidence.

It contains no Core Banking mutation and no Ledger posting path.


## v0.1.7 qualification

Requalified unchanged against Merchant Bank v0.8.  Core Banking remains a separate regulatory perimeter; this adapter still consumes only an explicit Core collateral-control decision and cannot create or mutate a Core encumbrance.


## v0.1.11 qualification

Dependency-only requalification against Merchant Bank v0.13 execution-evidence semantics. Core collateral-control boundaries are unchanged.

## v0.1.10 qualification

Dependency-only requalification against reconciled Merchant Bank v0.12.  Core
Banking remains outside this package and outside the Merchant regulatory
perimeter.  The adapter still consumes only an explicit Core collateral-control
decision and cannot create, amend or realise a Core encumbrance.

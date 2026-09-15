# Handover — FederationBank Staff Banking v0.3

## Candidate baseline

v0.3 supersedes the recovered v0.2 aggregate as the current Staff Banking continuation candidate.

### Retained unchanged business-authority components

- FederationBank Staff Authority v0.2
- FederationBank Staff Authority Service v0.2
- FederationBank Intermediary Staff Authority v0.1
- FederationBank Staff Channel v0.1 / Staff Channel Service v0.1 delivery

The exact three v0.2/v0.1 reconstructed staff-authority package bytes in the new 19:19 roll-up match the previously sealed recovery packages.

### New component

- FederationBank Staff Method Permissions v0.1

This component is intentionally **not Staff Authority v0.3**. Low-level method permission is a different authority with a different decision boundary. It is therefore delivered as a separate component rather than being hidden inside Staff Authority.

## Required authority separation

1. An authentication/attribution reference must never imply Access Control, method permission, Staff Authority or Core authority.
2. Passing Access Control must never imply object/method permission.
3. A method permission is exact to the principal, Alchemy object identity, class, method and Security Effect context.
4. A `FederationBankStaffMethodPermissionAdmission` is durable non-bearer evidence and is not a `FederationBankStaffAuthorityEnvelope`.
5. A valid Staff Authority envelope cannot bypass a method-permission DENY.
6. CUSTOMER vs INSTITUTIONAL Staff Authority remains disjoint. Only CUSTOMER staff authority can enter the ordinary Staff→Core binder.
7. RID remains independently authoritative for regulatory permissions/status/appointment/competence/product/journey/customer-evidence rules.
8. Core Banking remains final execution authority for its commands; Ledger remains outside these authority layers.

## Current qualification

Using the supplied ooRexx 5.3.0 r13196 Internal Test Version and `oorexxapis(20260828-191958).zip`:

- Existing Staff Banking recovery baseline: 47/47 green.
- New Staff Method Permissions v0.1: 7/7 green.
- Staff Banking candidate total: **54/54 green**.
- Generic ooRexx Access Permissions v0.1 dependency: separately requalified **6/6 green** against Crypto v0.5, including actual Security Manager interception.
- New package `.cls` files compile successfully with `rexxc`.

See `VALIDATION_SUMMARY.md` and `evidence/`.

## Deferred teller-cash closure

Do not silently pull Teller Cash into this candidate. The 19:19 roll-up contains `federationbank_teller_cash_v0.1.zip`, `federationbank_teller_cash_service_v0.1.zip`, and `federationbank_teller_till_v0.2.zip`, but the Teller Cash dependency declaration references `federationbank_teller_till_service_v0.1`, which is absent from the supplied roll-up. This needs an exact dependency delivery or an intentional Teller Cash migration/requalification; it is not repaired by guessing.

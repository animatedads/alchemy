# Changelog

## 0.2

- Added executable `AlchemyAccessControlledDomain` / `AlchemyAccessControlledSession` composition: Access Control gates domain entry; Alchemy Security Manager independently enforces exact method Permission inside the admitted session.
- Protected-domain entry requires a cryptographically proved Access Control ALLOW by default.
- Added contextual Access Control rule predicates with `AccessControlRule~requireAttribute`.
- Snapshotted Access Control request attributes to strings to preserve sealed canonical identity against caller-owned mutable values.
- Closed attributed-principal/request-subject confusion in both Access Control and Permission authorities.
- Added `AuthorizationDecisionEnvelope~semanticIdentity`.
- Requalified against ooRexx Crypto v0.8.3 and the 2026-09-01 API roll-up.
- Expanded module suite from 6 to 9 tests.

## 0.1

- Initial Access Control / attribution / Permissions module.
- Separated building/domain admission from exact method/object permission.
- Permission requests require Security Effect assessment evidence.
- Exact Security Effect policy and trace identities retained in decisions.
- Default DENY, deterministic priority, deny-wins-tie policy semantics.
- Crypto key-ring attribution assertions and generic SipHash-128 MAC policy/decision proofs.
- Alchemy Security Manager policy adapter with retained cryptographically proved decision envelopes.
- Integration test proved one exact Alchemy object is allowed and a second instance of the same class is denied.

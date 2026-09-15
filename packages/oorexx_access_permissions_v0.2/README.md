# ooRexx Access Permissions v0.2

Granular, policy-driven, cryptographically provable authority for ooRexx, designed to sit **alongside** Alchemy Security Manager and Security Effect.

This is deliberately three different things rather than one generic "security" switch:

1. **Authentication attribution** — proves which principal/key produced exact evidence. It grants no authority.
2. **Access Control** — coarse permission to cross a protected domain boundary: *enter the building*.
3. **Permissions** — exact authority to invoke a specific method on a specific object, evaluated with Security Effect evidence and enforced by Alchemy Security Manager.

## v0.2: executable composition

v0.1 already implemented each authority and the Security Manager Permission adapter. v0.2 makes the whole composition executable without collapsing the layers.

`AlchemyAccessControlledDomain` is the outer domain/building gate. `~enter` requires:

- a sealed `AccessControlRequest` for the exact domain;
- a sealed attributed `AccessPrincipal`;
- a cryptographic `AuthenticationAssertion` over that exact request;
- a current Access Control policy ALLOW;
- by default, a cryptographic proof on that Access Control decision.

Only then is an `AlchemyAccessControlledSession` created. The session owns an `AlchemySecurityManager` whose METHOD policy is still `AlchemyPermissionPolicyAdapter`. Every protected method invocation therefore receives a **new, separate Permission decision** over exact principal × object identity × class × method after Security Effect evaluation.

An Access Control ALLOW is never accepted as a method capability.

## Contextual Access Control

`AccessControlRule~requireAttribute(name, pattern)` adds deterministic contextual predicates to the domain boundary. Request attributes are snapshotted to strings when inserted, so mutating a source object cannot alter a sealed request or its cryptographic identity.

Example:

```rexx
rule = .AccessControlRule~new("STAFF-IN", 100, "ALLOW", "STAFF:*", "HQ", "FRONT_DOOR")
rule~requireAttribute("BADGE", "GREEN")
rule~requireAttribute("NETWORK", "CORP-*")
rule~seal
```

All required attributes must match. Missing or mismatched context means the rule does not match and the default remains DENY.

## Attribution binding hardening

v0.2 closes a subtle v0.1 authority-binding gap. A valid signer can truthfully sign bytes describing somebody else; therefore authentication validity alone cannot establish the request subject. `AccessControlAuthority` and `PermissionAuthority` now explicitly require:

`request.principalId == attributedPrincipal.principalId`

before policy evaluation. Regression tests prove Alice cannot sign a Bob request and inherit Bob's Access Control or method rights.

## Main classes

- `AccessPrincipal`, `AuthenticationAssertion`, `AuthenticationVerifier`
- `AccessControlRequest`, `AccessControlRule`, `AccessControlPolicy`, `AccessControlAuthority`
- `PermissionRequest`, `PermissionRule`, `PermissionPolicy`, `PermissionAuthority`
- `AccessPermissionsSigner`, `AccessPermissionsProof`, `AuthorizationDecisionEnvelope`
- `AlchemyPermissionPolicyAdapter`
- `AlchemyAccessControlledDomain`, `AlchemyAccessControlledSession`

## Cryptographic invariant

A valid identity assertion, policy/decision proof, or retained ALLOW receipt is **evidence**. It is not itself executable authority.

The v0.2 protected-domain composition requires a proved Access Control ALLOW by default. Permission decisions can also be MAC-proved. Proof verification uses ooRexx Crypto's trusted `CryptoMacKeyRing`; possession of a receipt alone does not substitute for current policy evaluation or Security Manager enforcement.

## Enforcement boundary

Alchemy Security Manager receives METHOD checkpoints only for interpreter-protected method surfaces. A method governed by this module must therefore remain `PROTECTED` (or implement an independent method-local gate). Making a method public changes the enforcement boundary; policy cannot compensate for a checkpoint the interpreter never emits.

## Current qualification baseline

- ooRexx 5.3.0 r13196 Internal Test Version
- Alchemy Objects v0.8
- ooRexx Crypto v0.8.3
- Institutional Policy v0.8
- Security Effect v0.10

Module suite: **9/9 PASS**.

Focused upstream compatibility also passes Alchemy Security Manager contract, Security Effect deterministic policy, and shared Institutional Policy tests.

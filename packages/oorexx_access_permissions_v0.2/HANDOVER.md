# Handover — ooRexx Access Permissions v0.2

Candidate: `oorexx_access_permissions_v0.2`
API: `access.permissions/0.2`
Date: 2026-09-01

## Supersedes

v0.2 supersedes `oorexx_access_permissions_v0.1` as the continuation candidate.

## Architectural contract

- Authentication proves attribution/integrity only.
- Access Control is the domain-entry/building gate.
- Permission is exact subject × object × method authority after Security Effect evaluation.
- Alchemy Security Manager enforces protected METHOD decisions.
- Access Control ALLOW never becomes method authority.
- Cryptographic decision receipts are evidence, not bearer capabilities.

## v0.2 implementation

- Added `AlchemyAccessControlledDomain` and `AlchemyAccessControlledSession`.
- Protected-domain entry requires exact authentication attribution plus Access Control ALLOW and, by default, a cryptographic Access Control decision proof.
- Session owns the existing Permission adapter + Alchemy Security Manager composition, so protected methods still receive independent Permission decisions.
- Added deterministic contextual Access Control predicates through `AccessControlRule~requireAttribute`.
- Access request attributes are snapshotted as strings, closing post-seal mutation through caller-owned mutable values.
- Added exact attributed-principal/request-subject binding in both Access Control and Permission authorities.
- Added `AuthorizationDecisionEnvelope~semanticIdentity` for retained composition/session evidence.
- Preserved v0.1 public authority classes and direct decision paths.

## Security regression closed

v0.1 could verify an assertion made by Alice over a request whose `principalId` named Bob, then evaluate Bob's policy selectors. v0.2 rejects this before policy evaluation with:

- `ACCESS_ATTRIBUTION_SUBJECT_MISMATCH`
- `PERMISSION_ATTRIBUTION_SUBJECT_MISMATCH`

The regression suite proves the attack fails at both authority layers.

## Qualification

Module suite: 9/9 PASS under the user-supplied ooRexx 5.3.0 r13196 debug package.

Focused upstream compatibility:

- Alchemy Security Manager contract PASS
- Security Effect deterministic policy PASS
- Security Effect shared Institutional Policy PASS

## Current roll-up anchors

- `0c7b54efd1db655927ec6f6937985825539d0aa14fd91890e144b4a48baed0c2` — `oorexxapis(20260901-103912).zip`
- `8add57fd2463403c9e91f3f49856e3f61b34753938abab3a617fc8063d2df4ae` — ooRexx 5.3.0 r13196 `.deb`
- `7683ed56ea99097226ea2f13f73305fb49919ba2ec822df2253ccfff59c6c073` — Alchemy Objects v0.8
- `5ebcab81493287499719f98920cb190d37afc79992cb34c7772d5392f63b9b49` — ooRexx Crypto v0.8.3
- `cc299764ae7e4d5c9aab7457b46f49ba524320296ed1e85d37b74025b16700bc` — Institutional Policy v0.8
- `37661bc708f29061757d7c2ff8946fd7d63da39bec47a993e257760180bc6465` — Security Effect v0.10

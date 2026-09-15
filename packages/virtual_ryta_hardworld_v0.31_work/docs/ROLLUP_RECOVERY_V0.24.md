# RYTA v0.24-work roll-up

Canonical upstream bundle: `oorexx-libs(20260822-crypto-consolidated)(7).zip`.
Outer SHA-256: `e95f489b0088c7d11d31f3b04ac7d2bc766661c6e103a0cfaec8292ffe5203c1`.

## House base

`RYTAObject` is the RYTA-owned subclass of Alchemy Objects v0.4.3 `AlchemyObject`.
It is used for long-lived service/state/authority-bearing RYTA objects.  The
Alchemy object id, lifecycle telemetry, contracts, Security Manager surface and
sealed introspection are evidence/operations infrastructure; they do not grant
HardWorld, Legal Effect or promotion authority and are excluded from canonical
promotion and queue replay identities.

Hot immutable/value-style records such as `RYTAFact` and `HardWorldClause` are
intentionally not full Alchemy objects.  A broad mechanical migration changed
the rules-coverage test from about 0.04 s to about 0.60 s on the supplied debug
interpreter; narrowing the boundary reduced it to about 0.22 s while preserving
the common base on the objects that own state and authority-use boundaries.

## Legal Effect v0.10.1

The old v0.7 conservative semantic/execution pinning and reducer guard remains
because the REVIEW/STATUS_EFFECT + REQUIRES_OBLIGATION insertion-order adversary
still reproduces under v0.10.1.

Native live v0.10 promotion is nevertheless distinct.  `LegalEffectV010PromotionAdapter`
requires the live Legal Effect execution envelope and successful host-owned
source-authority verification evidence.  Its authority identity is:

```
LEGAL_EFFECT/0.10/<generation>
  @<semantic-hash>
  +<conservative-execution-hash>
  +cert:<compiler-certificate-hash>
  +verified:<source/provision-verification-closure>
  +sourceauth:<host-source-authority-verification-closure>
```

Runtime Registry generation/artifact ids remain promotion provenance basis only.
A revoked publisher is refused by Legal Effect before the RYTA adapter receives
a live authority envelope.

Legacy v0.7 Structured/NoSQL paths remain compatibility tests and retain their
truthful `LEGAL_EFFECT/0.7/...` namespace.

## Crypto consolidation

Alchemy Objects, Legal Effect and Runtime Registry now consume the standalone
`oorexx_crypto_v0.1` package.  RYTA test fixtures no longer assume Runtime
Registry vendors `src/crypto.cls`.

## Ownership

Every exercised upstream tree was compared file-by-file against a fresh
extraction of its exact nested archive.  All comparisons passed.  Only this
RYTA working tree is modified.

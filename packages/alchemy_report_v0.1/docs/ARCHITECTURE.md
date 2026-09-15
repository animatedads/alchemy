# Alchemy Report v0.1 architecture

A report is a sealed document of *claims* and *bindings*. Bindings point at
retained sources. They do not replace them.

```
claim text  →  ReportClaim  →  ReportBinding[]  →  sourcePoint + digest + span
```

## Seal

`groundAll` then `canSeal`. A claim marked GROUNDED must have at least one
existing PRIMARY or SUPPORTING binding. Seal fingerprints the canonical
`machineForm` with `FINGERPRINT/1` (portable; not a claim of SHA-512).

## Trail

`trail(claimId)` walks the claim's binding ids in order. Duplicate ids on one
claim are refused. Empty trail terminal = UNRESOLVED; otherwise LEAF.

## Privacy

Bindings default to privacyClass UNKNOWN. Customer projections must omit
claims that rest only on UNKNOWN bindings. The sealed document still holds them.

## What this package does not do

Legal Effect evaluation, CivicPort fetch, PDF layout, Wire UI rendering,
LLM authorship as authority.

# Reporting filing lifecycle contract — v0.10

## Purpose

`accounting.reporting.filing/0.1` and `accounting.reporting.lifecycle/0.1` add immutable filing lineage and append-only regulator/workflow observations above the existing sealed snapshot, attestation and submission contracts.

Accounting Core does not mutate a previously sealed report when a regulator rejects it or when later accounting evidence requires a correction.  The historical filing remains evidence of exactly what was prepared, approved and submitted.

## Filing version

`AccountingReportingFilingVersion` binds:

- logical filing series identity;
- filing/version identity and kind (`ORIGINAL`, `AMENDMENT`, `CORRECTION`);
- exact sealed snapshot ID/fingerprint and boundary fingerprint;
- exact attestation set;
- creation time, reason/evidence and metadata; and
- for amendments/corrections, the exact prior filing ID and fingerprint.

An amendment/correction therefore cannot vaguely say "replace filing 1".  It identifies the exact immutable predecessor it changes.

## Lifecycle events

`AccountingReportingLifecycleEvent` is append-only evidence.  Supported event types are:

- `SUBMITTED`
- `RESUBMITTED`
- `ACKNOWLEDGED`
- `ACCEPTED`
- `REJECTED`
- `WITHDRAWN`
- `SUPERSEDED`

Each event freezes the filing fingerprint, occurrence time, actor, semantic authority reference and immutable authority identity.  Submission events additionally bind an exact `AccountingReportingSubmissionEvidence`.  Regulator acknowledgement/decision events require an exact external reference and external evidence identity.

Every event also locks the ID and fingerprint of the immediately preceding lifecycle event.  The result is an ordered tamper-evident semantic chain without making Accounting Core a regulator, transport or identity authority.

## Correction and supersession

A typical correction is:

```text
original snapshot V1
  -> approval V1
  -> submission V1
  -> ACKNOWLEDGED
  -> REJECTED

later accounting evidence discovered
  -> old snapshot becomes REPORT_POPULATION_STALE

corrected snapshot V2
  -> corrected filing V2 points to exact filing V1 fingerprint
  -> filing V1 receives SUPERSEDED event pointing to exact V2 fingerprint
  -> V2 receives RESUBMITTED event pointing to exact prior submission event
  -> ACKNOWLEDGED
  -> ACCEPTED
```

Nothing in that chain deletes or rewrites V1, its attestation, its submission receipt or the regulator's rejection evidence.

## Withdrawal

Withdrawal is another lifecycle event.  It does not delete the filing or mutate the original submission evidence.  If the report is subsequently re-filed, that is represented by another filing/submission observation according to the actual legal/regulatory facts.

## Authority boundary

The lifecycle records the authority that was asserted for each act using `authorityRef` plus immutable `authorityIdentity`.  Whether the actor truly possessed that authority is decided by Access/Permissions, Legal Effect, Institutional Policy or another external authority system.  Accounting Core only makes the asserted authority non-substitutable in the evidence chain.

## Compatibility

The contract is additive.  Existing consumers of `accounting.event/0.1`, `accounting.transaction/0.1`, `accounting.store/0.1`, `accounting.tax/0.1`, `accounting.settlement/0.1`, live reporting, snapshots, attestations and submissions do not need to adopt lifecycle APIs.

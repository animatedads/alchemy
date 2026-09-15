# Sealed reporting snapshot contract (`accounting.reporting.snapshot/0.1`)

`accounting.reporting/0.1` remains the live reporting-view API. v0.8 adds an additive evidential snapshot contract for regulatory, statutory and assessment workflows that need to prove exactly which immutable accounting population was assessed.

## Boundary

A sealed snapshot does **not** create journals, consolidate legal entities, perform eliminations, define regulator rules, or decide tax treatment. It freezes the output of an exact `AccountingReportingBoundary` over one or more existing `AccountingBook` instances.

Every selected reporting line retains:

- `legalEntityId`
- `bookId`
- `entryId` and exact entry fingerprint
- line number and exact line fingerprint
- posting date, account, currency, debit/credit minor units
- source event and correlation reference
- recursively detached journal dimensions

Every included source book contributes a source-state cutoff containing its legal entity, book, reporting basis, arithmetic profile, entry count and the exact ordered identity/fingerprint of every journal present when the report was sealed. This is deliberate: a regulator-facing snapshot must be able to distinguish “the book later advanced” from “the historical population changed”.

## Verification states

`AccountingReportingService~verifySnapshot()` returns:

- `VALID` — source journals exactly match the sealed source state.
- `VALID_SOURCE_ADVANCED` — the source book has appended journals, but none could have entered the sealed report population.
- `REPORT_POPULATION_STALE` — a later/appended journal falls inside the sealed date/boundary/selector population; the old report remains evidentially intact but is no longer complete for the current source state.

It also rejects a substituted boundary/policy identity, missing/truncated source books, changed historical entry fingerprints, or a changed in-boundary source-book set.

## Dimension aggregation

`totalsByDimensions()` is generic. A reporting/regulatory policy can group by standard dimensions such as:

- establishment
- tax registration/election
- regulatory registration
- client-money arrangement
- matter

or by company-specific dimensions. Currency remains part of every aggregation key, so GBP client money is never arithmetically merged with AUD client money.

## Signing / external evidence

The snapshot projection is deterministic and contains the snapshot fingerprint plus the exact boundary fingerprint and source-book cutoffs. Accounting Core does not mandate a signature technology. Crypto or another evidence layer may hash/sign the projection and place that identity in external evidence without changing accounting semantics.

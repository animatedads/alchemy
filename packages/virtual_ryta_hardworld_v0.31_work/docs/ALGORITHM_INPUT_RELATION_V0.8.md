# Algorithm Input Relation v0.8

## Purpose

v0.8 adds the reciprocal half of Algorithm-as-a-Relation:

```text
Algorithm -> relation -> SQL
SQL result -> frozen relation input -> Algorithm -> relation -> SQL
```

The generic input object is `AlgorithmInputRelationSnapshot`. It is independent of NoSQLServer. `NoSQLServerAlgorithmInputCapture` is the adapter which converts a successful NoSQLServer query result into that object.

## Identity and provenance

The snapshot separates content identity from provenance:

- `contentHash` hashes typed schema + bag/order semantics + complete row content.
- `sourceOid` is provenance. If omitted, it becomes `ALGREL-INPUT:<contentHash>`.
- `sourceQueryHash` records the producing query without changing `contentHash`.
- `sourceIdentity` records the producing subsystem without changing `contentHash`.

Two different queries/sources yielding the same typed relation therefore have the same content identity. If an algorithm needs source identity as a semantic input, it must receive it explicitly rather than obtaining it through a hidden hash side channel.

## Bag versus ordered relation semantics

`BAG_UNORDERED` is the default.

- row order is not part of identity;
- duplicate rows remain duplicates;
- rows are placed into deterministic canonical order before the provider observes them.

`ORDERED` preserves supplied row sequence and makes sequence part of content identity.

The v0.8 capture adapter treats ORDERED as an explicit caller contract. It does not yet prove that an arbitrary SQL statement establishes a stable ordering. That remains an attack item for review.

## Immutability

The builder copies source values before freeze. Frozen row views expose only read methods. Mutation of the source Directory/DatabaseRow or source database after capture cannot change the frozen relation.

A fresh capture after source mutation produces a different content hash when content differs.

## TableFeedDecisionProvider

`TABLE_FEED_DECIDER` is intentionally simple. It consumes rows:

```text
ROW_ID
LABEL
PREFERENCE_SCORE
UPSTREAM_DISPOSITION
```

and returns `TABLE_FEED_DECISIONS` plus `TABLE_FEED_TRACE`.

Preference scoring is subordinate to upstream authority:

- `PROHIBITED` -> never selected, regardless of positive score.
- `REQUIRED` -> selected, regardless of negative score.
- `SUPPRESSED` -> not selected.
- `REQUIRES_APPROVAL` -> not selected in this test provider.
- `PERMITTED` -> preference score may elect it.
- `UNRESOLVED` -> fails closed.

This is a plumbing/authority-propagation provider, not a claim that downstream systems should blindly inherit all upstream dispositions in production.

## v0.8 live pipeline

The stock NoSQLServer v0.68 test runs:

```text
Virtual RYTA
    -> RYTA_ACTION_DECISIONS
    -> SQL join with persisted toy_policy
    -> frozen AlgorithmInputRelationSnapshot
    -> TABLE_FEED_DECIDER
    -> TABLE_FEED_DECISIONS
    -> SQL join with persisted data again
```

The input deliberately contains:

```text
BIG_UPSELL  preference +1,000,000  upstream PROHIBITED
WARNING     preference -1,000,000  upstream REQUIRED
```

The downstream result remains respectively `PROHIBITED`/not selected and `REQUIRED`/selected.

The persisted BIG_UPSELL score is changed after capture. The downstream algorithm still observes the original frozen +1,000,000. A fresh later capture receives a different content hash.

## Execution counts

For the reference pipeline:

```text
Virtual RYTA provider (Algorithm A): 1
TABLE_FEED_DECIDER (Algorithm B):    1
```

Repeated downstream scans, trace reads, and joins do not change either count.

The MySQL-wire version preserves the same counts through msqlshim v0.08.

# Close-neighbour hashing — v0.1-dev8

## Purpose

Many systems need **near enough** rather than mathematically exhaustive nearest-neighbour search. Audio landmarks, fingerprints, feature vectors, repeated scene fragments, deduplication candidates and approximate retrieval all share the same requirement: reduce a large corpus to a small plausible candidate set without making "similar" mean "same hash or nothing".

`MLCloseNeighbour.cls` makes that a generic ooRexx ML facility.

## The core rule

This is not a cryptographic hash. It is a **distance-bearing ordered hash**:

```text
large / important difference  -> large hash difference
small difference              -> small hash difference
identical quantised values    -> zero hash difference
```

Each numeric feature has:

```text
name
minimum / maximum
number of ordered bins
integer significance weight
range policy = FAIL | CLAMP
```

A row is converted to an ordered coordinate vector. For two hashes, absolute per-dimension bin differences are multiplied by their significance weights, sorted largest-first, and packed into a mixed-radix integer.

For differences `[d1 >= d2 >= ... >= dn]` and base `B` greater than any possible weighted dimension difference:

```text
distance = (((d1 * B) + d2) * B + d3) ...
```

Therefore the largest discrepancy dominates every collection of smaller discrepancies. The next-largest discrepancy breaks ties, then the next, and so on.

This is effectively a lexicographic `L-infinity first` distance encoded as one sortable integer.

## Why not packed binary subtraction?

Packed binary or Morton-style integer differences have a nasty boundary property. Two adjacent values around a carry boundary can look far apart in the representation even though the source values differ by one tiny step.

The ooRexx ML hash stores ordered quantised coordinates and compares coordinate differences. Moving from bin 127 to 128 is therefore **one bin**, not a high-bit catastrophe.

## Significance weights

Weights are explicit integer policy. A temporal relation may be more important than a one-bin spectral shift; a safety-critical sensor may matter more than an auxiliary estimate. Increasing a dimension's weight makes a change in that dimension appear earlier in the significance ordering.

Weights are policy/evidence. They are not inferred silently.

## Multi-probe lookup

Exact bucket lookup is radius 0. Approximate lookup probes neighbouring coordinates:

```text
radius 0 -> exact bucket only
radius 1 -> immediate neighbouring cells
radius 2 -> two-cell neighbourhood
...
```

All cells within the requested hyper-rectangle are ordered by significance distance from the query before candidate retrieval. A declared `maxProbeBuckets` is a hard resource boundary. If the radius would exceed it, the query fails closed rather than silently truncating an arbitrary subset of buckets.

`maxCandidates` independently bounds how many indexed entries may be examined.

## Exact reranking

The hash may be the final metric (`mode=HASH`) when "good enough" is the desired answer. When original numeric vectors remain available, `mode=EXACT` uses the hash only for candidate generation and reranks the bounded candidate set by exact squared Euclidean distance.

The approximate index therefore separates:

```text
cheap candidate discovery
        from
optional exact ranking
```

## Measuring "good enough"

`MLExactNeighbourIndex` scans the corpus and is intentionally slow. It is an oracle for qualification.

`MLCloseNeighbourAssessment` compares approximate top-k results with exact top-k results and records:

```text
recall@k
average candidate fraction examined
number of queries
hit count
probe radius
```

A useful deployment statement can therefore be evidence such as:

```text
recall@5 = 0.97
candidateFraction = 0.08
```

rather than "the hash seems close enough".

## Historical-object semantics

`MLCloseNeighbourIndex` subclasses `MLDriveableObject`. Building or replacing an index creates journalled state. The fitted state can be rolled back, the old future retained, and alternative schemas/quantisations compared on branches just like models and GA populations.

The schema itself is explicit evidence: domain bounds, resolution, significance weights and range policy are all canonical.

## Audio landmark inheritance

The included regression models an 18-bit-like landmark space as three 6-bit ordered dimensions:

```text
delta-time : 6 bits / 64 bins
frequency1 : 6 bits / 64 bins
frequency2 : 6 bits / 64 bins
```

An exact hash lookup can miss a landmark whose frequency moved by one bin. A radius-1 multi-probe finds the adjacent-frequency landmarks without widening the persisted source index into every possible tolerant variant.

This is the generic replacement for application-private "try this bucket, then hand-code a few neighbouring buckets" logic.

## Fail-closed rules

- Out-of-domain values fail by default. `CLAMP` must be explicit.
- Sample ids must be unique.
- Probe-bucket budgets fail closed rather than truncating silently.
- Schema identity and dimensional width must match before hashes are compared.
- Exact reranking is never claimed unless original vectors are actually evaluated.

## Future providers

A native or Foreign Runtime provider may accelerate bucket construction, candidate lookup or vector reranking. It must preserve the same hash coordinates, significance distance, candidate/evidence identity, probe policy and deterministic ordering.

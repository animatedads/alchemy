# Polar pattern hashing — pattern, not number

## Why it exists

Many recognition problems do not care about the absolute value of a sequence.  They care about the **shape made by the values**.

A conventional numeric hash answers "are these values identical?".  A close-neighbour hash answers "are these coordinates near each other?".  Polar pattern hashing answers a different question:

> **Where else did something shaped like this happen?**

This is useful for time-series motifs, acoustic envelopes, spectral profiles, motion traces, cyclic sensor patterns, training curves, traffic/timing traces, and cryptanalytic pattern recognition where the recurring relationship between observations matters more than the actual magnitudes.

## Circular-grid model

The dev9 reference implementation follows the circular-grid construction requested by the Architect.

1. Treat the input sequence as one revolution around a circle.
2. The source minimum becomes the centre (`radius = 0`).
3. The source maximum becomes the outer normalized radius (`radius = 1`).
4. Source sample count is removed by linear resampling onto a fixed angular grid.
5. Optional rotation invariance removes the arbitrary choice of which source sample was called index zero.
6. Optional reversal invariance can make clockwise and anticlockwise traversal equivalent when the domain says they mean the same thing.

For angular bin `i` of `N`:

```text
angle(i) = 360 * (i-1) / N
radius(i) = (sample(i) - sourceMinimum) / (sourceMaximum - sourceMinimum)
```

Flat input is represented by the centre point at every angle.

The original minimum, maximum, sample count, and canonical rotation are retained as evidence on `MLPatternHash`; they are not silently discarded even though they do not define pattern identity.

## What is actually hashed

After angular resampling the normalized radii are quantized.  The hash retains three related descriptions of the curve:

```text
R   radial coordinate at each angle
D1  first circular difference (rise / fall geometry)
D2  second circular difference (bend / curvature geometry)
```

`MLPatternHashPolicy` gives those three levels explicit significance weights.  The default reference policy deliberately makes curvature more significant than slope, and slope more significant than residual radius:

```text
radialWeight    = 1
slopeWeight     = 4
curvatureWeight = 8
```

These are policy, not universal truth; domains may choose different significance.

## Difference is ordered by significance

Pattern distance is **not** the arithmetic difference between two opaque hash integers.

For every angle and every retained geometry level, the weighted absolute difference is computed.  All such differences are sorted largest-first and compared lexicographically.

Therefore:

```text
one large structural disagreement
          >
any collection of smaller disagreements
```

This is the same dominant-difference doctrine introduced by `MLCloseNeighbour`, but applied to a curve rather than to independent scalar coordinates.

`MLPatternHashDifference` exposes:

- `dominantDelta`
- complete ordered deltas
- total delta (secondary evidence only)
- maximum radial disagreement
- maximum slope disagreement
- maximum curvature disagreement
- fixed-width `rankKey` for durable ordering/evidence

## Invariances are explicit semantics

The reference pattern hash is inherently offset- and amplitude-invariant because the source minimum and maximum define the polar radius scale.

The schema additionally exposes:

- `rotationInvariant` — if true, circular phase/index zero is canonicalized;
- `reversalInvariant` — if true, forward and reversed traversal are canonicalized to the same representation.

Reversal invariance is **not** a default.  A rise-then-fall and fall-then-rise sequence can carry different meaning even if their unoriented geometry is identical.

## Indexing and historical state

`MLPatternCorpus` stores variable-length curves with stable sample identities. `MLPatternIndex` is an `MLDriveableObject`, so its fitted state participates in the same Journal Pointed State rollback/roll-forward and branch discipline as the rest of ooRexx ML.

The first reference index performs exact pattern-hash equality through buckets and nearest-pattern retrieval by significance-ordered hash difference.  It intentionally keeps the semantic reference implementation simple; a later accelerated index may prune candidates, but must return observationally equivalent ordering for the declared policy.

## The vital demo

Run:

```sh
rexx examples/pattern_hash_polar_demo.rex examples/pattern_hash_polar_demo.svg
```

The demo compares four inputs:

```text
base              0 .. 10
same shape         100 .. 200  (offset + amplitude change)
same-ish shape     small local deformation
different shape    altered turning structure / extra lobe
```

It also constructs the same base curve at twice the source sample density.

Expected evidence:

```text
scaled/offset      dominant=0 ...      exact same pattern hash
sample-density     dominant=0 ...      exact same pattern hash
small deformation  dominant=20 ...     close but not identical
different curve    dominant=110 ...    structurally much farther
```

The generated SVG is the important part of the demonstration.  The affine curve literally overlays the base on the circular plot despite using completely different numbers.  The changed-turn curve forms a visibly different lobe and receives the dominant hash disagreement.

## Cryptanalytic use

Pattern hashing does not "break encryption" and does not claim that similar shapes imply identical causes.  Its value in cryptanalytic and protocol-analysis work is more modest and often more useful: it can retrieve recurring **differential, timing, frequency, or distribution shapes** when absolute values, offsets, amplitudes, or phase origins differ.

It supports the question:

> "Where else did this behaviour recur?"

The returned pattern match is candidate evidence.  Domain-specific analysis remains responsible for deciding what the recurrence means.

# Cylindrical temporal pattern hashing — pattern through time

`MLTemporalPatternHash.cls` extends the dev9 polar pattern model with an independent time axis.

A temporal event sequence is mapped to a circular cylinder:

```text
angle  = normalized event progress around one revolution
radius = normalized channel value above that channel's minimum
height = event time above the base plane
```

For channel `c` and angular sample `i`:

```text
x = r(c,i) * cos(theta_i)
y = r(c,i) * sin(theta_i)
z = normalized_or_absolute_time_i
```

Adjacent points define a true 3-D direction vector.  The temporal hash retains:

- per-channel radial coordinates;
- elapsed-time gaps;
- planar bearing of each 3-D segment;
- vertical elevation angle of each segment;
- 3-D turn angle between consecutive segments.

The cylinder is open in time: the last event is **not** implicitly connected back to the first event in height.  Circularity belongs to the angular pattern plane; time remains directional.

## Pattern, not number — now with time

As in dev9, each channel is normalized independently so absolute offset and amplitude can remain evidence rather than identity.  Event count is also normalized by linear resampling onto the declared angular grid.  Time semantics are explicit policy:

- `timeShiftInvariant`: ignore absolute start time and compare elapsed timing;
- `timeScaleInvariant`: additionally normalize total duration so a globally faster/slower replay can remain the same timing shape;
- absolute timing mode retains the quantized time origin and gap sizes.

Time-scale invariance necessarily implies time-shift invariance and the policy fails closed on the contradictory combination.

A local delay is not erased by global time-scale normalization.  It changes time-gap/elevation/turn evidence.

## Vector-valued events

A temporal pattern can carry multiple named channels with independent significance weights.  They are **not** compressed into one scalar before hashing.

For a market example a series might retain:

```text
PRICE
RELATIVE
FX
VOL
```

All channels share the same event times and angular progress while contributing their own radial and direction signatures.  A price-lookalike can therefore be far away because FX, relative performance, or volatility turns differently.

Channel weights are declared domain policy.  They do not imply causal truth or investment value.

## Significance-ordered difference

Temporal pattern distance follows the dev8/dev9 doctrine.  Weighted local disagreements are sorted largest-first and compared lexicographically.  The largest declared structural disagreement dominates any collection of smaller ones.

The evidence reports the dominant kind and channel, plus maxima for:

- radius;
- time;
- bearing;
- elevation;
- 3-D turn.

The result is therefore more useful than an opaque scalar distance.  A caller can see *why* two trajectories were considered different.

## Direction-vector interpretation

Each segment exposes:

```text
dx, dy, dz
bearingDegrees
 elevationDegrees
length
```

Bearing is the direction in the circular plane.  Elevation is the temporal pitch of the segment above that plane.  A timing shock can therefore manifest as a large elevation disagreement even when the radial market shape is unchanged.

## Demo

Run:

```sh
rexx examples/cylindrical_market_pattern_demo.rex examples/cylindrical_market_pattern_demo.svg
```

The demo deliberately creates a cognitive trap using illustrative synthetic market data:

1. A and B have nearly identical nominal-price lines.
2. Their cylindrical economic trajectories separate because relative performance, FX and volatility differ.
3. C has completely different numerical levels and a globally stretched clock, but every channel has the same relative trajectory; with declared offset/scale invariance its temporal hash is exactly A's.
4. D retains A's channel shapes but delays one local event; timing/elevation evidence separates it.

The point is not finance-specific.  The same representation applies to audio landmarks, protocol timing, cryptanalytic side-channel traces, sensor events, behavioural sequences, camera activity profiles and other domains where the useful question is:

> Where else did behaviour shaped *and timed* like this occur?

A pattern match is evidence for further analysis, not a causal, cryptanalytic or investment conclusion.

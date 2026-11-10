# F11 Room-F refinement evidence — dev50

Dev50 turns the dev49 batch transport into a reverse-search seam.

## Authoritative refinement window

`F11AcousticRefinementPlans~roomF` generates the current viable Room-F window:

- x = 4.50 .. 6.00 m
- y = 4.25 .. 4.75 m
- step = 0.25 m
- RTL and LTR vehicle passes
- 20 ms trajectory sampling
- 4.36 s trajectory duration

That is 21 physical source positions and 42 whole-trajectory Cluster tasks. The supplied example plan assigns them deterministically across three members, 14 tasks each.

## Compact feature evidence

`physics.f11.candidate-summary/3` retains curve references from v2 and adds compact descriptors for static FD-FC delay, static overlap, FC/FD pitch ratio, FC/FD cadence ratio, FC/FD vehicle power change, FC/FD reflection delay, overlap lag during the vehicle event, and rear-path power.

The heavy curves, PCM and spectral state remain destination-local.

## Matching

`F11AcousticObservedEvidence` contains only measurements that actually exist, each with an explicit tolerance. `F11AcousticEvidenceMatcher` compares only supplied dimensions and returns the mean tolerance-normalised residual, maximum residual and a fail-closed compatibility flag.

No statistical probability or hidden weighting is claimed. A missing candidate descriptor causes the match to fail rather than being silently imputed.

The `rear_path_power_db` dimension is included specifically so the new rear hard terrain reflector/stairwell aperture family can participate in candidate rejection when that path is measured.

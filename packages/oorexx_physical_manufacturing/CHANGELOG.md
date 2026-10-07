# dev9
- Standards repair: removed banned `+ 0` coercion idioms.
- Corrected reversal detection so it never relies on `&` short-circuit semantics.
- Expanded growth test loop to make its mutation boundary explicit to static review.
- Reviewed object responsibilities against the supplied `family.rex` example; retained behavior with domain objects rather than adding controller type switches.
- Added Claude standards-enforcer normal/strict runs to acceptance evidence.

# Changelog

## 0.1-dev7
- Rebases the peer Physics qualification target from dev23 to dev26; no aircraft-specific Physics is copied into Manufacturing.
- Adds `SegmentedDeposition.cls` so a finite extrusion retains material-bearing path elements instead of only a bead centroid.
- Each element retains actual start/end coordinate and time, deposited mass, explicit nominal feed increment, material identity and optional deposition temperature.
- Adds resolved actual/nominal path length, local stretch ratio, line density, direction and path-reversal evidence. These are observations, not print-quality labels.
- Zero-motion extrusion remains explicit: line density is unresolved (`.nil`) rather than division by zero or an invented finite value.
- The current mechanics bridge still commits one reduced-order thermal section at the resolved bead centroid. Element-level deformable mechanics is deliberately not claimed yet.

## 0.1-dev6
- Adds finite-duration deposition and retained physical bead paths.
- Material placement samples actual nozzle/workpiece relative position while the machine continues to move.
- Retains deposited mass and mass-weighted physical bead centroid.

## v0.1-dev8
- Removes the dev7 single-centroid mechanical commit from the new element-resolved deposition path.
- Adds `ElementResolvedDepositionProcess`: every retained deposition interval is committed as an independent Physics mechanics body and thermal node.
- Preserves local mass, actual path, commanded feed evidence, reversal and deposition temperature per element.
- Refreshes Physics World target to dev38 and optional Rexx-tronics peer to dev21.
- Records Parts Research Factory dev3 as candidate/provenance input only; no candidate is silently promoted to catalogue authority.
- Adds runtime qualification gates for element history and element-resolved commit structure.

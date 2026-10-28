# Media Methodology Qualification

A methodology specification is incomplete without a way to discover when it fails.

The catalogue therefore includes qualification methodologies as first-class entries.

## Required baseline controls

For experimental or reconstructive methods, prefer the following controls whenever applicable:

- source preservation and cryptographic identity;
- synthetic/controlled ground truth;
- matched quiet/static or target-absent windows;
- before/after A-B comparison on identical evidence;
- parameter sensitivity sweeps;
- resolution invariance;
- codec/container invariance;
- clock perturbation for cross-modal work;
- holdout windows that remain blind during tuning;
- explicit camera/visibility/authority gating tests;
- bootstrap or other uncertainty estimation;
- forward-model reprojection;
- time-reversal controls for directional temporal methods;
- cross-method disagreement preservation.

## Reconstruction acceptance

A reconstruction may be useful without being “correct.” Qualification should therefore report an operating envelope rather than a binary universal pass.

A reconstruction candidate should be considered stronger when:

1. its assumptions are satisfied;
2. it is stable across a reasonable parameter neighbourhood;
3. forward reprojection predicts the source observations;
4. independent methods recover compatible constrained structure;
5. negative/null controls do not produce the same apparent structure;
6. uncertainty is localized rather than hidden;
7. unsupported areas remain unresolved or explicitly synthetic.

## Experimental methods

Experimental methods must be easy to select *and* easy to exclude by policy. The runtime catalogue exposes both behaviours.

An experimental failure is not a package failure if the method reports that its assumptions were not satisfied and refrains from emitting overconfident output.

## Negative evidence

“No event” is only valid when the method had observation authority. Occlusion, camera motion, clipping, missing packets, missing calibration, unresolved registration or unavailable high-resolution source material must produce unavailable/withheld evidence, not a zero measurement masquerading as a negative observation.

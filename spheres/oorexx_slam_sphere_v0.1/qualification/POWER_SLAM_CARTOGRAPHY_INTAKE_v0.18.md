# Power SLAM Harbour v0.18 — two-image cartography evidence intake

Architecture: Tom Dyer; implementation: ChatGPT GPT-6; 2026-11-02.
Rasen Falcon component: power-slam-harbour; Claude Top Rope SLAM is a potential producer, its implementation/contract not yet confirmed.

## Scope
Power SLAM gains a standalone native ooRexx consumer adapter, `SlamHarbourCartographyIntake.cls`, that will accept image-reader output for two overlapping Google Maps screenshots with differing pixel zoom. It takes *separate* input image hashes, 3 fit + >=1 independent holdout ground controls, each map's independent affine 2D pixel->local metric transform, and closed water polygon rings in source pixels. `reconcile` checks common geographic control identity and consistency; `geographicOutlines` attaches registration status and source hash to transformed polygon arrays.

Explicit local tangent approximation around (-33.85,151.2) is not a survey-level CRS transform. Test threshold 3m is a software rejection policy for synthetic controls, not achieved real-world accuracy. This is a data-contract and algorithmic demo only.

## Critical admission boundary
Unsourced geography and coastline extracted from map screenshots are *unqualified*. Even if a producer claims surveyed geocontrol and surveyed boundary, the adapter returns SURVEY_CLAIM_UNVERIFIED because no authority verification is implemented. `METRIC_WATER_MASK_ALLOWED` is always false. In particular, **unknown and outside water are NOT verified land**. No sampled map, stationary camera location, zoom scale or ferry world position has been accepted as metric truth from this adapter.

Input validation checks two independent sources, SHA hex, CRS, pixel bounds, duplicate IDs, independent holdout, collinearity, holdout residual, polygon closure, area, strict self-intersections, zero-length edges, coordinate ranges and common-control conflicts. Collinear overlapping edges, curved map projections across large areas, source digital signatures, shoreline topology and actual map-pixel segmentation remain outside v0.18.

## Native qualification
ooRexx 5.3.0 r13196:
- 42/42 native synthetic cartography contract checks PASS, two **fictional** 300x300 image sets with different 2:1 scales, matched geographic control IDs and identical projected outline.
- Previously published native PTZ zoom regression 13/13 PASS.
- Exact repository-layout runner reproduced: `sh packages/oorexx_slam_v0.1/bin/run_cartography_intake.sh` with ooRexx installed.

No real Google map screenshot used as geometric source; no real Sydney Harbour water polygon claimed. User screenshot of Claude's pending mapping exercise is not spatial training data. No water imagery or PTZ video distributed.

## Coordination
Rasen Falcon `REQ-00002975` requests Top Rope's exact Git branch, package, CRS/source-hash schema, map controls and uncertainty. The pending Claude map-work remains Claude's. This implementation only prepares the Power SLAM consumer gate and leaves Top Rope owning OCR/raster/polygon extraction. Tombstone Vision retains ferry detection.

# Sydney Harbour V5V / ELVIS GitHub recovery audit — 2026-11-02

Branch: `tombstone-sydney-vision-v07`. Pull request: https://github.com/animatedads/alchemy/pull/106

## Recovered and pushed in this pass

**21 previously missing original files**, committed using GitHub's contents API and independently checked against the historical released ZIP files by exact Git blob SHA-1, not by renamed or reconstructed filenames:

| Release | Previous state | Files newly added | Result |
| --- | --- | ---: | --- |
| v0.36 ELVIS terrain | Adapter, README, tests and CLI already committed; fixture/negative runner/loader/replay absent | 4 | **Complete 9-file release contract on Git** |
| v0.21 full-cadence V5V | Qualification README only | 7 | **Complete 8-file source/qualification contract on Git** |
| v0.24 tripwire follow | Qualification README only | 10 | **Complete 11-file source, gates and mask contract on Git** |

In particular:
- `examples/tombstone_sydney_elvis_terrain_v0.36/`: adapter `HarbourHeightWords.cls`, 120-row sample fixture, loader/negative/qualification scripts, two tests, MGA56 query CLI and README. The **raw user-supplied DEM-derived word file is intentionally not committed** pending redistribution/attribution review; reproducibility requires the unchanged user-uploaded file, SHA-256 `3243f644556f084bf8f524b6b080f8b539fdf5986622b4b207a3a690c32a102e`.
- `examples/tombstone_sydney_v5v_full_cadence_v0.21/`: original source, including ooRexx V5V producer, native packed five-bit encoder, native temporal-structure evaluator, conservative mask generator, frame-series verifier, isolated SLAM sidecar class and `QUALIFICATION.json`. **`SlamVisionFrameIngress.cls` was syntax-checked only**, not authorized for production SQL/TESTED graph admission.
- `examples/tombstone_sydney_v5v_tripwire_v0.24/`: original native 80x45 line-band scanner, ooRexx `V5VTripwireFollow` predictor, original follow/score/verifier scripts, fail-closed qualification and 11-case negative shell tests, provisional line gates and water-only motion mask.

**Verification:** independently fetched all 17 original v0.21/v0.24 GitHub blob SHAs and compared with the actual source ZIP bytes, 17/17 exact; independently fetched and verified the four v0.36 recovered Git blobs, 4/4 exact. Historical full-video qualification counts in the release READMEs are inherited from their original recorded executions, not newly rerun against source media as part of this GitHub recovery pass.

## Other prior release gaps — not falsely marked synced

Some other release branches within this same PR still have report/qualification-only commits while additional runnable source remains in previously delivered conversation ZIPs:
- v0.25 Camera 2: bitmap-native V5V codec and line scanner, standalone capture/qualification scripts and camera-specific water-mask provider
- v0.26 dual camera: two-source video replay, pixel-exact original-resolution lookup and bitmap V5V source/qualification suite
- v0.28 cruise ship: code and source receipts mainly in delivered release archive; report committed
- v0.29 normal harbour traffic: executable three-camera replay and masks/gates mainly in delivered release archive
- v0.30 and v0.31: core native C and ooRexx source published, some original replay/negative shell scripts still in archive

Those are **known repository gaps**, not a claim of all-archive completion. They should be recovered from the original release ZIP contents, excluding raw videos, pixels, private inputs and third-party data unless publication is explicitly authorised.

## Safety and provenance

- All video motion/evidence is `OBSERVED_UNTESTED` unless separately qualified in the SLAM source owner.
- Source-image masks are provisional and no camera pose/world ferry location is implied.
- The ELVIS bare-earth grid is not bridge-deck height, and a high near-water DEM sample does not prove dry land.
- No PR merge or production deployment is authorised by this source-recovery update.

# Sydney Harbour Power SLAM / V5V v0.35 — source-pixel bridge landmark controls

Architecture: user. Executable implementation: GPT-6, 2026-11-02. All image observations remain `OBSERVED_UNTESTED` and model-space positions are `BLOCKED_NO_QUALIFIED_TRANSFORM`.

## Real experiment

Two original user-uploaded Café Sydney 640×360 H.264 recordings (actually MPEG transport streams named `.mkv`):

- Cruise: `stream3_20261102T055436Z.mkv`, SHA-256 `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e`.
- Normal traffic: `stream3_20261102T062311Z.mkv`, SHA-256 `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d`.

Each video has its own original timestamps. The second was captured **28 minutes 35 seconds later**. This is a *retrospective* comparison of the same fixed-camera source pixels, not information available to the original live tracker.

`run_qualification.sh` verifies both complete source SHA-256 digests, validates 640×360 at 30fps, and extracts *exact* original source frames 150, 450, 750, 900, 1050, 1350 and 1650, using FFmpeg only as a decode adapter (no OpenCV or inferred 3D coordinates). It compiles the native standalone C pixel-difference operator. The C operator searches all offsets dx,dy∈[-3,+3] against **three a priori selected, apparently static image regions** (left bridge tower, arch crown, city background). The chosen offset minimizes combined absolute luminance difference. It then measures source-pixel differences in three candidate regions including the bridge right-hand tower.

Native ooRexx `qualify_image_landmarks.rex` consumes those receipts and registers the two V5V source identities through the existing v0.34 `CrossSlamEvidence.cls`. It validates original source identities, every frame, pixel shifts, numeric limits, status and method. It emits only **image-coordinate mismatch candidates**, not a 3D Power SLAM ray or vessel identity.

### Results actually measured (seven source-frame pairs)

| Measurement | Observed range |
|---|---|
| Best source-image translation (all seven pairs) | dx=0, dy=0 |
| Mean luminance difference of stable image controls | 9.73–10.84 (0..255) |
| Stable control pixels with luminance difference >35 | 0.13–1.56% |
| Right bridge-tower pixels with difference >35 | 46.60–60.95% |
| Image-discrepancy review gate | 7/7 admitted **as unverified observations** |
| Model/world camera pose | BLOCKED_NO_QUALIFIED_TRANSFORM |
| Physical vessel identity / causal tracking | UNVERIFIED / NOT RUN |

**Important:** This is a fixed manually selected scene region, not a blind fully automated vessel detector. The later baseline shows the otherwise occluded right-hand tower. A true online classifier cannot consult the later video. Lighting, shadow, object motion and baseline weather also vary between captures; the method does *not* independently identify what caused the occlusion. Right-hand pylon classification by an individual model feature remains provisional. The Power SLAM arch-crown model is a structural proxy, not a surveyed curved-arch control.

The original `CrossSlamEvidence.cls` is copied verbatim from the native v0.34 integration as a frozen dependency. `landmark_controls.psv` explicitly distinguishes 640×360 source pixel rectangles from approximate 80×45 V5V cells (8 source pixels per V5V cell). Model feature names are **candidates**, not admitted 3D correspondences.

### Reproduction

```sh
export PATH=/path/to/oorexx/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/path/to/oorexx/usr/local/lib
export REXX_BIN=/path/to/oorexx/usr/local/bin/rexx
sh run_qualification.sh /path/to/stream3_20261102T055436Z.mkv /path/to/stream3_20261102T062311Z.mkv /tmp/sydney-v035-run
sh qualify_negative.sh
cmp anchor_receipts.psv /tmp/sydney-v035-run/anchor_receipts.psv
cmp occlusion_candidate.psv /tmp/sydney-v035-run/occlusion_candidate.psv
```

**Qualification:** Native standalone C feature operator exact replay of seven source-frame pairs, ooRexx 7/7 valid source-bound records, 17/17 deliberate altered/forged evidence rows rejected, one synthetic low-contrast abstention, native C input-failure checks 5/5 rejected, byte-identical full replay for both receipt outputs. The synthetic abstention deliberately alters a fixture and is not used as real-world observation.

### Next boundary

The evidence identifies stable photographic image controls and a conspicuous candidate foreground occlusion. To map the right-hand tower to Sammy's *georeferenced* 3D model, independently verify pylon identification/corner pixels, camera optical centre/intrinsics and uncertainties against holdout landmarks. Never use the cyan segmentation screenshot or pan sweep directly as an image-to-world transform. Power SLAM v0.21 already has native `HarbourRayOcclusion` methods, but they must not infer a real viewing ray before pose admission.

**Scope:** No raw video republished; `diagnostic_photo.png` is a derived, user-viewable local comparison only and is not appropriate for third-party broadcast. The archive includes source C/Rexx, 7×2 exact RGB source-frame samples, source/hash verification and numeric evidence, not the original full videos.

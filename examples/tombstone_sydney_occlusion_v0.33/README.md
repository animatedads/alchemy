# Sydney Harbour V5V v0.33 — causal occlusion / fixed-bridge temporal evidence

**Architecture:** user. **Implementation:** ChatGPT GPT-6, 2 November 2026.
**Authority:** `OBSERVED_UNTESTED`; no ferry/ship identity, camera world position or canonical SLAM `TESTED` weight.

## The implementation increment

The original five-bit V5V temporal index and the **same 28 unclassified grouped AOIs from v0.32** direct small original-source RGB24 lookups. Each AOI is evaluated **against the same camera five seconds earlier in the SAME recording**, not against the 29-minute-later empty-harbour recording. The control region provides a brightness-change reference, and all pixels in the full V5V source surface are retained. No prior source labels, later frames, or real 3D geometry enter the foreground evidence extraction.

This is a specific test of the challenging condition **ship moving in front of the stationary Harbour Bridge**. The ship may overlap a provisional landmark polygon; it is never deleted for that reason.

`source/v5v_occlusion_temporal_v033.c`:
- Validates each matching source-hash-linked v0.32 group and all original source-pixel box bounds, and consumes exact RGB24 source frames at t and t-5sec.
- Uses independent, source-image-plane **provisional static-control rectangles** (not commissioned Power SLAM projections): Camera 2 x850..979,y300..394; Camera 3 x35..169,y82..125.
- Computes the control's 95th percentile of mean absolute RGB differences; chooses change threshold `max(20, control_p95+6)`. In these 12 frame pairs, control p95 was 5..11, so the 20-level minimum was operative.
- Measures changed pixels **separately inside/outside the existing 80×45 provisional water-motion mask**. The mask is a tag, not an eraser. Reports 8×8 original-pixel tile connectedness (>=4 changed pixels per active tile) via native four-neighbour graph, keeping uncertain clusters in evidence.
- Reports only `SPATIALLY_COHERENT_IMAGE_CHANGE` versus `WEAK_OR_FRAGMENTED_CHANGE`, not a classified vessel. For both statuses, world position remains `IMAGE_PLANE_ONLY_UNCALIBRATED` and evidence stays `OBSERVED_UNTESTED`.

## Original sources (SHA-256 verified)

| Camera | Scene | Original source SHA-256 |
|---|---|---|
| Bridge-right Stream 2 | Cruise | `6b180a1d9779a22dd770b8081a29d40c477b3b2e1f99e9b233b38be804838830` |
| Bridge-right Stream 2 | Normal traffic | `bf0dcef14da41b17b6b1214589e2a29067b58a85d4899078ccc51f9f0b700de0` |
| Café Sydney Stream 3 | Cruise | `c3bea629be6f054bafe08d50d03e259f894a97ddeae089dd69d77da0985cae7e` |
| Café Sydney Stream 3 | Normal traffic | `58616633e8239ec1f6a0699231f1466279af794d622090086babbc4af01c100d` |

All four sources have 30fps. Original frame pairs evaluated: (300,450), (750,900), (1200,1350). 4 source videos × 3 pairs = **12 independent processing calls**, each using the original video PTS/frame ordering. 28 v0.32 AOIs: Camera 2 cruise 9, Camera 2 normal 6, Camera 3 cruise 4, Camera 3 normal 9.

## Results and strict interpretation

| Camera/source | AOIs | AOIs with >5% source pixel differences | Four-neighbour tile clusters flagging structured change |
|---|---:|---:|---:|
| Camera 2, cruise ship | 9 | 0 | 9 |
| Camera 2, normal traffic | 6 | 0 | 5 |
| Camera 3, cruise ship | 4 | 4 | 4 |
| Camera 3, normal traffic | 9 | 0 | 2 |

**Café Sydney**: all four selected cruise regions have 8.58–9.99% source-pixel change; the nine ordinary-traffic regions have 0–0.53%. This is a strong *within-these-recordings* distinction. The >5% threshold was used in the preceding v0.31 experiments; it is **not** fresh independent classifier certification.

**Bridge-right**: the nine cruise regions show only 2.41–4.79% change, while ordinary-traffic regions reach 3.70%. Coherent changes occur around ship, water, wakes and bridge-adjacent traffic in both periods. Accordingly **ABSTAIN**, not `LARGE_SHIP_DETECTED`, for this camera. The new algorithm has not solved cross-camera identity or the bridge occlusion problem by itself. No truth labels enter the native selector.

## Reproduction / qualification

The shipped source and 28-row receipt are the actual executed versions. Run:

```
REXX_BIN=/path/to/rexx sh source/qualify_v033.sh
sh source/qualify_native_v033.sh
REXX_BIN=/path/to/rexx sh source/replay_v033.sh /path/to/original/uploads /tmp/v033-replay
```

- Native C compiled with `gcc -std=c11 -O2 -Wall -Wextra -Werror`; a sample case also ran with AddressSanitizer + UndefinedBehaviorSanitizer after fixing an initial queue-mask allocation bug. This is a useful source-level test, **not** a full-suite sanitizer certification.
- **28/28** linked evidence rows accepted by independent ooRexx 5.3.0 r13196 checks; exact original v0.32 rectangles, counts, per-water-mask conservation, receipt authority and timing expected.
- **18/18** deliberately forged ooRexx receipt cases rejected (source, camera, frame, group, bounds, pixel sums, fractions, geometry/identity/TESTED, duplication/truncation).
- **5/5** native input corruptions rejected (oversize/truncated RGB, forged mask status, forged group class, absent group source).
- Full four-source re-extraction of 12 pairs yielded **28/28 byte-identical** evidence rows to the first run, with SHA256 of each original file verified first.

The ZIP contains `source/` implementation/validators/runners, the 28-row `results/` PSV and logs, v0.32 source-linked group and mask PSV, diagnostic comparison image and checksum manifest. The original video files, extracted full RGB24 frames and private interpreter binary are excluded.

**Next work:** qualify a real Power SLAM camera pose and its uncertainties; add causal region-to-region displacement/appearance correspondence to distinguish static bridge pixels, wind/wake and a moving superstructure in the Bridge-right view. Until then `WORLD=BLOCKED_UNCALIBRATED`, ship identity unverified, and no SLAM `TESTED` edges.
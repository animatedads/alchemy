# Power SLAM v0.41 — Sydney Harbour Bridge arch

Architecture: Tom Dyer
Coding: Claude (Opus 5.5) (this increment); Power SLAM base: ChatGPT GPT-6
Written by: Claude (Opus 5.5), 2026-11-03

## Why

Up to v0.40 the scene held the bridge `DECK`, the four `PYLON_TOWER_PHOTO` solids and the two
abutments, but not the arch. Aircraft in SLAM 450 could fly straight through where the arch steel
is, and nothing ever had to choose to go over or under. That was reported as the "lack of graceful
arch between the pylons".

## What

`src/SlamHarbourBridgeArch.cls` → `.HarbourBridgeArch~apply(scene)` appends the arch as oriented
cuboids in the scene's own frame and returns how many it added (86). Its axis is derived from the
existing `DECK` solid: the midpoints of the deck's two short ends, 566 m apart. So the arch follows
the deck if the deck is ever revised.

| Parameter | Value | Note |
|---|---|---|
| Span between bearings | 503 m | centred on the deck midpoint |
| Upper chord | parabola, 134 m crown, 69 m at bearings | |
| Lower chord | parabola, 116 m crown, 12 m at bearings | truss 18 m deep at crown, 57 m at ends |
| Ribs | centre lines ±15 m from the axis, 4 m wide | |
| Panels | 28 × 503/28 m | each solid 0.2 m longer than its panel (no zero-width seams) |
| Hangers | 1.5 m, deck top (49 m) to lower chord, both rib planes, at interior panel points | only where the lower chord clears the deck |

Each panel is the envelope of the true profile over that panel, from the lowest lower chord to the
highest upper chord, so a solid is never smaller than the arch:
- **Where the lower chord is above the deck:** the two ribs and their lateral bracing form one block
  34 m across. You can't fly between the ribs inside the truss.
- **Near the ends, where the lower chord passes below the deck:** the ribs are separate 4 m slabs,
  joined only by a 6 m top-bracing block, so the road passage between them stays open.

**Open by design:** the traffic passage above the deck, under the lower chord and between the hanger
planes; and everything outside the ribs.

**Standing:** the figures are public, rounded values. These are model solids, not survey and not
AHD-qualified, with the same standing as the v0.21+ bridge, berm and wharf solids.

## Opt-in

`HarbourOcclusionPanorama~configure` is unchanged in v0.41, so every earlier Power SLAM
qualification and render is untouched. A consumer calls `.HarbourBridgeArch~apply(model~scene)`;
SLAM 450 v0.92 does so. Switching it on inside `configure` is a one-line follow-up for the Power SLAM
lane, which would also refresh its renders.

## Qualification

`tests/test_bridge_arch_v041.rex`: 15/15 PASS on ooRexx 5.3.0 r13196 + rxmath.
- Chord constants; the axis derived from `DECK`; `apply` appends exactly what it reports; `configure`
  alone adds no arch.
- The crown is solid on the axis, and above the crown is clear.
- The traffic passage above the deck is clear at mid-span, and an 80 m flight along the axis ±110 m
  under the arch is clear. The same flight 15 m to the side is blocked by hangers.
- Crossing the truss sideways near the crown is blocked.
- 204/204 sampled points on both chords of both ribs lie inside a solid.

Regression, with the new class present:
- `test_blues_pt_corner_v040.rex`: 10/10.
- `bin/qualify_harbour_terrain.sh`: terrain visibility 29/29 and mosaic 19/19.
- **Already failing on main at 004ecc6f, unrelated to the arch:** the same script's
  `tests/test_occlusion.rex` asserts `scene~boxes~items==27` ("preexisting quay solids"). Later
  versions added solids, so the count no longer matches. It fails identically with the arch files
  removed. Left for the Power SLAM lane to re-baseline.

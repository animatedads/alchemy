# Sydney CBD buildings from LiDAR, for Power SLAM

Architecture: Tom Dyer
Coding: Claude (Opus 5.5) — LiDAR tools, blocks, loader, checks. ChatGPT — the Power SLAM scene these blocks are added to (v0.39 Cahill and station placement included).
Written by: Claude (Opus 5.5)

LiDAR: NSW Government (DCCEEW Marine LiDAR, August 2018), CC BY 4.0. Ground: NSW Spatial Services.
Aerials and maps used for street lines: NSW Government (Spatial Services, Planning Portal).
Put the LiDAR line on every picture drawn from these blocks.

## What is here

| File | What it is |
|---|---|
| `cbd_scene_blocks.words` | 4,263 blocks in Power SLAM scene metres, the Bridge cut out. Load this one. |
| `blocks_cbd.words` | All 4,333 measured blocks in GDA2020 MGA zone 56 (the LiDAR's own frame), the Bridge still in. Do not load it into a scene. |
| `../../../src/SlamHarbourCbdBlocks.cls` | The loader: `.HarbourCbdBlocks~apply(scene, file, minHeight)`. |
| `cbd_blocks_check.rex` | Check: no block inside a named solid or on the Bridge, the scene's own solids unchanged, with and without the arch; known-answer tests. |
| `cbd_blocks_cut_bridge.rex` | Takes every block touching the Bridge zone out of the block file. |
| `tower_check.rex`, `towers.words` | LiDAR heights against 15 published towers. |
| `render_view.rex` | Draws the scene and blocks from a camera (SVG). |
| `cbd_blocks_scene.rex` | MGA blocks to scene blocks (uses `harbour_frame.cls`). |
| `streets_to_grid.rex`, `streets_to_mga.rex` | Street lines from the lined aerials to a street mask on the LiDAR grid. |
| `probe_cells.rex`, `mosaic_pgm.rex` | Diagnostics: the LiDAR cells round a place; the tops as a picture. |
| `resect_view.rex`, `photo_points.words` | Camera from known points in a photo. Not solved for Tom's Quay photo (see Limits). |

The LiDAR tools are in `oorexx_slam_toprope_v0.1/src`: `las_grid.rex`, `lidar_mosaic.rex`, `lidar_blocks.rex`, `top_rope_lines_diff.rex`, and the changed `stitch.cls`, `stitch.rex`, `stitch_lessons.txt`.
`tools/laz2las.py` only unpacks LAZ to LAS (laspy + lazrs), as ImageMagick unpacks a picture. Every decision is made in ooRexx.
`tools/make_test_las.py` writes synthetic tiles with known answers.

## A block line

```
block 1 scene 90.9 -2075.1 size 38 by 23 bearing 62.9 base 26.5 top 53.0 height 26.5 area 384
```

- `scene x y`: middle of the block, metres east and north of -33.852, 151.210.
- `size L by W`: the box, L along `bearing` (degrees clockwise from true north).
- `base`: ground under the block, metres AHD. `top` = base + height.
- `height`: the 90th of 100 roof heights in the block, so masts are left out.

## How to load

```
scene = pano~scene
r = .HarbourCbdBlocks~apply(scene, "cbd_scene_blocks.words", 20)
```

Call it after the scene is built. Each block becomes a cuboid named `CBD_<id>`.
## The Harbour Bridge is never LiDAR

The deck, arch, pylons and abutments are the scene's own model. Seen from above, LiDAR cannot tell a deck or an arch from a roof, so its blocks there were boxes from the water up to the deck or arch: solid walls under the deck, and copies of the pylons. The first file had 70 of them, among them a 481 by 12 m wall from 1 m to 61 m (block 441), both pylon pairs (blocks 14 and 147) and the southern approach.

- The Bridge zone (`.HarbourCbdBlocks~bridgeZone(scene)`) is taken from the scene's own ABUTMENT_S and ABUTMENT_N. It runs from abutment to abutment, carried 40 m past each one, and is the wider of abutment and deck plus 15 m each side: 644 by 88 m on the v0.41 scene. It holds the deck, all four pylons, both abutments and every arch solid.
- `cbd_blocks_cut_bridge.rex` took the 70 blocks touching it out of `cbd_scene_blocks.words`; their ids are listed at the head of the file.
- The loader applies the same zone again, so an older block file cannot put LiDAR on the Bridge. It stops if the scene has no abutments.
- `cbd_blocks_check.rex` fails if any CBD block touches the zone or any arch solid, or if any of the scene's own solids changed.

## Other blocks left out

A block is left out when it is lower than minHeight (default 3 m), or when it duplicates a solid already in the scene. A duplicate means the block's middle is inside that solid's footprint, or that solid's middle is inside the block's. The named solid wins, so the landmark tops stay as the scene gives them.

Returned directory: `BLOCKS`, `SKIPPED`, `BRIDGE_ZONE`, `INSIDE_NAMED`, `NAMED_HITS` (solid name -> count), `SOURCE`, `STATUS`.

Counts with the v0.41 scene (125 named solids): 4,219 added, 44 duplicates left out (16 in OPERA, 13 under the Cahill berm, 2 in SALESFORCE, the rest in the wharves, the station and the Cahill east extension), none on the Bridge. With the arch loaded (86 arch solids) the counts are the same.
By height, in the file: 3,435 blocks are 10 m or more, 1,709 are 20 m or more, 596 are 50 m or more, 221 are 100 m or more.


## How to run the checks

Set REXX_PATH to this folder, `oorexx_slam_v0.1/src` and `oorexx_slam_toprope_v0.1/src`, then run:

```
rexx cbd_blocks_check.rex cbd_scene_blocks.words
rexx tower_check.rex towers.words blocks_cbd.words mosaic_cbd.words
```

The first must end with `PASS no CBD block inside a named solid or on the Bridge`.
The second needs the mosaic (about 60 MB, not committed; build it with the steps below).

## How the blocks were made

1. `las_grid.rex` reads each 1 km LAS tile into 2 m cells: top return, ground (class 2), water, and a kind letter per cell.
2. `lidar_mosaic.rex` joins the 15 tiles (E 333218 to 336000, N 6249000 to 6253000).
3. `lidar_blocks.rex` makes the blocks.
   - A building cell is a structure 3 m or more above ground. Class 6 counts as a structure, and so does class 1, because the 2018 survey leaves its tallest towers unclassified.
   - Six of the tiles are only sorted into ground, noise and class 1, so their trees are class 1 too. A roof stops the laser; a tree or a wire lets returns through. So a class 1 cell with a ground return of its own is not a roof, unless it is one ring round a roof within 5 m of its top.
   - Cells join where roofs step by 5 m or less and stay within 6 m of the block's mean.
   - Pieces under 150 m2 join their longest-border neighbour.
   - Street lines from the aerials split blocks, but only under 15 m above ground: the aerials are renders in which towers lean over the streets.
4. `cbd_blocks_scene.rex` moves the blocks to the scene frame.
5. `cbd_blocks_cut_bridge.rex` takes the Bridge out.

Rebuild commands:

```
python3 tools/laz2las.py tile.laz tile.las
rexx las_grid.rex tile.las grid_tile.words
rexx lidar_mosaic.rex mosaic_cbd.words grid_*.words
BLOCKS_STREETS=streets_mask.words rexx lidar_blocks.rex blocks_cbd.words mosaic_cbd.words
rexx cbd_blocks_scene.rex harbour_heights.words blocks_cbd.words cbd_scene_all.words
rexx cbd_blocks_cut_bridge.rex cbd_scene_all.words cbd_scene_blocks.words
```

`lidar_blocks.rex` takes about 15 minutes and 2.9 GB on the whole CBD.

## Tower check (published heights, Wikipedia)

Each tower is taken to stand on the highest LiDAR return within 90 m of its published point. Some published points are 50 to 80 m off the tower.

- Peaks match the published top within 11 m for Governor Phillip, Chifley, MLC, Sydney Tower, World Tower, Citigroup and Gateway.
- Australia Square and Aurora Place read 20 m high.
- Deutsche Bank Place takes Chifley's peak: the 90 m search is too wide where towers stand close.

## Limits

- The survey is August 2018. Crown Sydney, Quay Quarter Tower and Greenland Centre are missing or part-built. A crane at the QQT site reads about 258 m.
- Each block is a box. An L-shaped or irregular building is drawn bigger than it is.
- One block covers more than 2 ha: a 12.8 m roof at Darling Harbour, not yet checked.
- Off the Bridge, a block that only partly overlaps a named solid (middle outside it, and the solid's middle outside the block) is kept.
- Some small blocks stand at water level (base under 1.8 m AHD): boats and pontoons, the largest 79 by 37 m at 5.6 m high. Not yet sorted out.
- Other elevated roads (the Western Distributor over Darling Harbour, for one) are boxes down to the ground, as the Bridge was.
- Ground under roofs is copied from the nearest ground cells. The NSW 5 m DEM would be better and is the next step.
- The camera for Tom's Circular Quay photo is not solved. The photo is 3:1 and is probably stitched, so a single pinhole camera does not fit it (best 28 px rms, at an impossible place).

## ooRexx pitfalls met here

- Names are not case-sensitive: `t` and `T`, `nc` and `NC` are the same variable. Four bugs today came from this.
- `.array~new(n, 0)` makes a 2-D array, not an array of zeros.
- `**` needs a whole-number power: use RxCalcSqrt for a square root.
- An internal routine shares the caller's variables unless it uses `procedure`.

Self-score: 7/10. Heights and the duplicate check are measured and tested; the photo comparison is not done.

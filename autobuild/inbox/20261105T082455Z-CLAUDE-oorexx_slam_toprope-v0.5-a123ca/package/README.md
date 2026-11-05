# oorexx_slam_toprope v0.5 — SLAM draws, sees, reads and maps, and says who can see what

Architecture: Tom Dyer. Code: Claude (Opus 5.5). This README: Claude (Opus 5.5).

Part of the SLAM family (BodySlam, Piledriver, Moonsault, Boston Crab, ...). Simple controlled words plus
deterministic ooRexx tools, in place of a large language model guessing at pictures.

Tools used: ooRexx 5.3.0 with rxmath; ImageMagick (reads pictures to PPM, draws check pictures
where SLAM says); rsvg-convert (SVG to PNG; renders training glyphs); GDAL 3.8.4 (cut and converted the Balaklava
grid from Copernicus GeoTIFF, and drew its relief picture). No Python in the package.

New in v0.2: the sight line (`src/height_grid.cls`, `src/sight_line.cls`, `src/sight_line.rex`).
Boston Crab's order checker and SLAM 450 ask it who can see what.

## The parts

| Part | Program | What it does | State |
|---|---|---|---|
| SLAM Draw | `src/slam_draw.rex`, `src/pictures.words` | draws from simple words (box, band, star, circle, shape, write) to SVG | working |
| SLAM Space | `src/slam_space.rex`, `src/space_words.md` | reads a described room ("4 metre hallway ...") into a plan | working |
| Top Rope Slam | `src/top_rope.rex`, `src/master.cls` | looks at a picture and says how to draw it in SLAM Draw words (stars, circles, boxes, bands, writing); checks itself with Tom's V5V codec (low resolution, then detail) | working |
| Reader (OCR) | `src/glyphs.cls`, `src/glyphs.txt`, `src/word_hint.rex` | 6 fonts, 76 characters; a word hint that tips close glyph choices, never forces | working |
| Chart reader | `src/top_rope_chart.rex` | flow chart to logic steps | in progress: one step box not yet found; the last change (paper found by colour) is untested |
| Map reader | `src/top_rope_map.rex` | two Google map screenshots: water shapes, fitted (zoom, place), merged, put on the earth | working |
| Stitch tools | `src/stitch.cls`, `src/stitch.rex`, `docs/stitch_words.md` | SLAM stitches pictures of one place by itself: island shape prints, kappa checks, lessons | working (10 of 12 satellite pictures joined) |
| Read map | `src/read_map.rex` | layers: at a place, the layer with the most detail that saw it answers | written; not yet run end to end |
| Height map | `src/height_map.rex`, `src/mga.cls` | ELVIS / NSW DEM to a height layer, "how high is this place", rough 3D model in SLAM Draw words | working |
| Height grid | `src/height_grid.cls` | one height layer read once, asked many times: an ESRI ASCII grid in degrees (Copernicus, SRTM) or Top Rope height words (MGA) | working; tested |
| Sight line | `src/sight_line.cls`, `src/sight_line.rex` | can A see B over the ground: curve of the earth with refraction, eye height above ground or above datum, where the line is blocked; "within" for places known only roughly | working; tested (`tests/test_sight_line.rex`, 26 checks; `tests/test_elvis_parity.rex`, 120 cells) |

## Run

Draw a flag from words:

```
rexx src/slam_draw.rex examples/flags/za_flag.words za.svg
```

See a picture and say it in words:

```
rexx src/top_rope.rex examples/flags/boxes.png boxes_seen.words
```

Stitch pictures (Google screenshots carry 16 rows of small print at the foot):

```
rexx src/stitch.rex sky.words bottom 16 s01.png s02.png s03.png
```

Height layer and 3D model from an ELVIS grid (north lat, west lon, south lat, east lon, step m):

```
rexx src/height_map.rex make Sydney-DEM-AHD_56_5m.asc heights.words harbour_3d.words -33.795 151.170 -33.885 151.290 50
rexx src/slam_draw.rex harbour_3d.words harbour_3d.svg
```

How high is a place:

```
rexx src/height_map.rex at examples/harbour/harbour_heights.words -33.8597 151.2045
```

`TOPROPE_DEBUG` (time, read, chart, map, stitch, height) shows the working.

## Teaching

SLAM is taught in its own small words, so a small model can follow: `docs/stitch_words.md`,
`src/space_words.md`. What SLAM learned is kept beside the programs: `src/stitch_lessons.txt`
(zooms that were right), `src/top_rope_lessons.txt` (turns that read writing best).

## Examples

- `examples/flags` — words and drawings (Australia, US, South Africa, boxes)
- `examples/hallway` — a described hallway and the plan SLAM Space made
- `examples/harbour/harbour_heights.words` — Sydney Harbour heights, 50 m grid, with fixed places.
  Source: NSW Government, NSW Spatial Services 5 m DEM via ELVIS (AHD71, GDA94 MGA zone 56, +/-0.9 m at 95%), © State of New South Wales, CC BY 4.0.
  Anything made from it (height words, the 3D model, sight-line answers) carries that credit.
- `examples/harbour/satellite_stitch.words` — where SLAM put 13 satellite pictures (names and places only)

Not in the repo, on purpose: Google map and satellite screenshots and anything traced from them
(their terms do not allow it in a public repo), the user's own photos, and the 790 MB DEM.
The commands above remake the outputs locally.

## Known limits

- Rexx symbols ignore case: `w`/`W`, `r`/`R`, `n`/`N`, `e`/`E` have each broken a routine here once.
- The DEM alone can not say where water is (round Fort Denison it holds water at 2.5 to 3.3 m);
  the 3D model takes water from a map layer where one saw it, else under 1 m.
- Stitch: the Middle Harbour pair is not joined (best kappa 0.52; its confirm 0.446 is under 0.5).

## Sight line (v0.2)

Who can see what, from a height layer. Ask it in a program:

```rexx
g  = .HeightGrid~new('examples/balaklava/north_valley.asc', 'Copernicus GLO-30 surface model')
sl = .SightLine~new(g)
a = .directory~new; a['LAT'] = 44.5400; a['LON'] = 33.6070; a['EYE'] = 2.5
b = .directory~new; b['LAT'] = 44.5295; b['LON'] = 33.6250; b['EYE'] = 1.5
d = sl~look(a, b)      /* d['SEES'] is 1, 0 or "UNKNOWN"; d['CLEAR'] metres; d['BLOCK_FROM'] metres */
r = sl~spread(a, 300, b, 150)  /* r['VERDICT'] SEES / CANNOT / SOMETIMES; r['SEEN'] of r['TRIED'] */
::requires 'sight_line.cls'
```

Give a place `ASL` (metres above the datum) in place of `EYE` for something in the air, such as a SLAM 450 aircraft. Read the grid once and ask it many times: a look over 2 km on a 30 m grid takes about 11 ms here, and a spread (225 looks) about 2.5 seconds. Loading the Balaklava grid takes under a second.

Or from the command line, from a places file (see `examples/balaklava/places.words`):

```
rexx src/sight_line.rex examples/balaklava/north_valley.asc examples/balaklava/places.words
```

Add `words` at the end for one line per look (`sight <from> <to> SEES|CANNOT|SOMETIMES|UNKNOWN <seen> <tried>`). That is what Boston Crab reads.

Rules it keeps:
- The line is walked in steps of half a grid cell.
- The earth's curve is allowed for, with refraction k = 0.13. The test pins it: two 2 m eyes over flat sea see each other at 10 km and not at 12 km.
- Any part of the line off the grid, or with no data, gives UNKNOWN. It is never guessed.
- Every answer carries the grid's source string. Say in it whether the grid is bare earth (ELVIS DEM) or a surface model with today's trees and buildings (Copernicus).

### The harbour words and the ELVIS provider (v0.4)

`examples/tombstone_sydney_elvis_terrain_v0.36` holds ChatGPT GPT-6's qualified, read-only provider for the same harbour words (`HarbourHeightWords.cls`, nearest grid word, fail-closed). Top Rope reads the same file. `tests/test_elvis_parity.rex` checks that the two agree on that provider's own 120-cell fixture (`tests/fixtures/elvis_grid_sample_120.psv`, 20 of the cells NoData). At every grid point Top Rope's height is exactly the source word, and every NoData cell comes back as no height.

The parity test found two faults in v0.3, now fixed:
- a point on the last column had no height;
- a point beside a NoData cell had no height, though it is a grid point with its own word.

Notes for that provider's owners:
- The `mga.cls` its README says was not supplied is in this package (`src/mga.cls`, Snyder's Transverse Mercator on GRS80). Its lat/lon to MGA 56 gives the six fixed places' recorded heights.
- The file on GitHub is byte-identical to the one that provider qualified (SHA-256 `3243f644…a102e`).
- Publication is confirmed. Tom Dyer has checked that the words are NSW Government data, free to publish with a credit to the NSW Government. This package gives that credit in the README, in every height or 3D file `height_map.rex` writes, and, through `harbour_heights.credit`, in every sight-line answer. The provider's rule of holding the words back until permission is confirmed is answered.

Water: the grid's water is flattened near 0 m, and its lowest words go down to −14.5 m (that provider's count). Something on the water should be given `ASL` (height above the datum), not `EYE`. An `EYE` there would be measured from a height that is not the water's surface.

### Credits travel with the data (v0.5)

A `.credit` file beside a grid, with the same name, is read by `HeightGrid` and said with the source in every answer: `examples/harbour/harbour_heights.credit` (NSW Government) and `examples/balaklava/north_valley.credit` (the Copernicus notice). The grid files themselves are unchanged, so the harbour words keep the SHA-256 the ELVIS provider qualified. `tests/test_sight_line.rex` checks that both credits reach the answers.

### Buildings: what a bare-earth grid does not hold (v0.3)

The ELVIS grid is bare earth, so it has no CBD. Give the sight line an occluder: any object with `blocks(a, b)`, where a and b are directories with LAT, LON and ASL (eye height above the datum). It returns "" or the name of what is in the way. When terrain does not block, `look` asks the occluder. `d['BLOCKED_BY']` is then that name; when terrain blocks, it is `ground`.

- `.BoxOccluders` is one occluder: upright boxes in the grid's plane, each with a centre, half width east, half depth north, a turn clockwise from north, and base and top above the datum. It reads them from words (`box <name> <lat> <lon> <half east> <half north> <turn> <base> <top>`), or from a `boxes <file>` line in a places file. A watcher or target in or on a box is not hidden by that box, so a camera in a tower sees out.
- For SLAM 450's CBD model, write a small adapter class whose `blocks(a, b)` turns a and b into the scene's coordinates and calls the scene's own ray test (`HarbourRayOcclusion~firstHit`). Then pass it with `sl~setOccluder(adapter)`. The terrain and the CBD are then checked on one line of sight. Top Rope does not copy the scene's buildings.

### For SLAM 450 testers

Run these from the package folder. Each command goes on one line.

1. Set the class path:
```
export REXX_PATH=$PWD/src
```
2. Run the tests. All 26 sight-line checks and all 120 parity cells must pass:
```
rexx tests/test_sight_line.rex
```
```
rexx tests/test_elvis_parity.rex
```
3. Run the Balaklava example. Compare with `examples/balaklava/sight_results.txt`:
```
rexx src/sight_line.rex examples/balaklava/north_valley.asc examples/balaklava/places.words
```
4. For the harbour, use `.HeightGrid~new('examples/harbour/harbour_heights.words', 'ELVIS DEM, bare earth, 50 m grid')`. Give the aircraft `ASL` and the watcher `EYE`. The heights are AHD on a bare-earth grid, so buildings do not block. That is said with every answer.

### Balaklava example

`examples/balaklava/north_valley.asc` is cut from the Copernicus GLO-30 tile N44 E033, supplied by Tom Dyer, with GDAL. It covers 33.565–33.665 E, 44.518–44.552 N. The places are Claude (Opus 5.5)'s reading of the relief against the written accounts (see `places.words`), so every look is made "within" a distance. On this grid, from every position tried within 300 m of the Light Brigade's start line, the reverse slope of the Causeway Heights is hidden: 0 of 225 for both the middle and the east of the ridge. That matches the accounts of the captured guns being out of sight behind the ridge. Lucan's and Raglan's views depend on where exactly they stood: "sometimes", with counts.

Produced using Copernicus WorldDEM-30 © DLR e.V. 2010-2014 and © Airbus Defence and Space GmbH 2014-2018 provided under COPERNICUS by the European Union and ESA; all rights reserved. The organisations in charge of the Copernicus programme by law or by delegation do not incur any liability for any use of the Copernicus WorldDEM-30.

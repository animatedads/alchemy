# oorexx_slam_toprope v0.1 — SLAM draws, sees, reads and maps

Architecture: Tom Dyer. Code: Claude (Opus 5.5). This README: Claude (Opus 5.5).

Part of the SLAM family (BodySlam, Piledriver, Moonsault, ...). Simple controlled words plus
deterministic ooRexx tools, in place of a large language model guessing at pictures.

Tools used: ooRexx 5.3.0 with rxmath; ImageMagick (reads pictures to PPM, draws check pictures
where SLAM says); rsvg-convert (SVG to PNG; renders training glyphs). No Python in the package.

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
  Source: NSW Spatial Services 5 m DEM via ELVIS (AHD71, GDA94 MGA zone 56, +/-0.9 m at 95%), CC BY 4.0.
- `examples/harbour/satellite_stitch.words` — where SLAM put 13 satellite pictures (names and places only)

Not in the repo, on purpose: Google map and satellite screenshots and anything traced from them
(their terms do not allow it in a public repo), the user's own photos, and the 790 MB DEM.
The commands above remake the outputs locally.

## Known limits

- Rexx symbols ignore case: `w`/`W`, `r`/`R`, `n`/`N`, `e`/`E` have each broken a routine here once.
- The DEM alone can not say where water is (round Fort Denison it holds water at 2.5 to 3.3 m);
  the 3D model takes water from a map layer where one saw it, else under 1 m.
- Stitch: the Middle Harbour pair is not joined (best kappa 0.52; its confirm 0.446 is under 0.5).

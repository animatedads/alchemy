# Sydney Harbour classified water grid — derived Power SLAM dataset

**File:** `harbour_water.words`  
**SHA-256:** `dd6c0bad02b96a444b108c3094a56111a758aa087ad28b838235222f1f436ec7`  
**Git blob SHA:** `b4cc85b9d1c61a52c483d06a40f6aec3749d5585`  
**Created:** 2026-11-02 (derived output supplied by Tom Dyer / Claude Opus 5.5).

## Scope and provenance

The dataset is **derived classification data** constructed from Tom Dyer's manually aligned and stitched Sydney Harbour map layers, painted land/water corrections and NSW Spatial Services elevation information obtained through the ELVIS Elevation and Depth platform. The derived output was produced using the native ooRexx `harbour_water.rex` workflow by Claude (Opus 5.5), under Tom Dyer's architecture and map alignment.

- Underlying elevation: NSW Spatial Services 5 m DEM via ELVIS, processed into the accompanying 50 m `harbour_heights.words` grid (GDA94 / MGA zone 56; AHD71 vertical datum).
- **Attribution:** © State of New South Wales (Spatial Services). Underlying NSW Spatial Services source dataset; see https://www.spatial.nsw.gov.au/copyright and https://www.nsw.gov.au/environment-land-and-water/spatial-data-and-mapping/foundation-spatial-data-framework/elevation-and-depth.
- Spatial Services generally licenses its published material under **CC BY 4.0 unless otherwise stated**; refer to the dataset-specific terms for the particular extraction. This project does not imply NSW Government endorsement.
- The actual source extraction date and ELVIS order/tile identifiers were not supplied in the handover, so this file does **not** assert an invented source extraction date. The derivative was delivered on 2026-11-02.
- Further derived data and corrections: map registration, manual water/land decisions and stitching by Tom Dyer; native output constructed by Claude (Opus 5.5).
- Changes from the original DEM: source heights resampled from 5 m to 50 m, water and land classified independently using corrected map geography, water propagation, protected structure footprints and pier/quay decisions. This is not a redistributed copy of the original full-resolution DEM or raster map imagery.

## Machine-readable contract

The first `grid mga 56 top left 330586.9 6259261.5 step 50 across 226 down 204` declares **grid-cell centres**: 226 columns eastward, 204 rows southward, 50 m spacing. All 204 `row` records have exactly 226 letters.

| Letter | Count | Interpretation |
| --- | ---: | --- |
| `W` | 15,669 | Classified water; use modelled sea level |
| `L` | 29,496 | Classified land; height from `harbour_heights.words` |
| `X` | 939 | Missing height; do not assume land or water |

To connect to Power SLAM, load each W/L letter into the existing `HarbourWordsRoleEvidence~setCell(column,row,letter)`, then pass the resulting role evidence to `HarbourWordsSceneTile~new(heightWords,0.9,roleEvidence)`. Preserve `X` as unknown/no-fly. Do not use a universal numeric height threshold as a replacement for this derived classification.

## Qualification

This is a **50 m derived classification grid**, not a survey-grade shoreline, navigation chart or full-resolution raster mask. It does not certify camera location, structure height or shoreline location to sub-cell accuracy. The map layer and terrain are independent evidence, and the native collision/visibility tracer should fail closed outside the classified coverage.

The original `harbour_water.words` was committed **byte-for-byte** from `power_slam_water_map.zip`, including its original header and `end` marker; no data cells were edited.

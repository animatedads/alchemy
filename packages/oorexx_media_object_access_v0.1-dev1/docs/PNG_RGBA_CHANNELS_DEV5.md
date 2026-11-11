# Media Object Access dev5 — native PNG pixels and independent channel planes

## Implemented (9 November 2026)

**Architecture:** ooRexx owns byte-source identity, bounded source reads,
container sniffing, PNG frame object, per-pixel access, output filenames and
binary file writes. In-process native `moa_png` uses libpng to decompress
compressed PNG bytes supplied by ooRexx, without reading any file or invoking
an executable. A separate, codec-independent `moa_raster` native package
performs bounded raster byte permutations; it has **no dependency on libpng or
H.264**, so the existing H.264 RGB24 frame class can share channel export
without acquiring a PNG codec dependency.

All frames are row-major unpremultiplied `RGBA32`, 8 bits/channel. PNG's
palette, greyscale and 16-bit inputs normalize to 8-bit RGBA through libpng.
RGB24 video frames keep their original format; the raster package synthesizes
an **opaque (255) A plane** for those because H.264 RGB24 has no alpha.

## Output API

```
source = .MediaLocalByteSource~new('sky.png')
image = .MediaFileProbe~open(source)
frame = image~decode
pix = frame~pixelAt(100,200) /* [R,G,B,A], 0..255 */
plane = frame~channelPlane('A') /* exact width*height bytes */
outputs = frame~saveSplit('sky')
frame~savePpm('sky.rgb.ppm')
frame~savePam('sky.rgba.pam')
source~close
```

- `sky.r.pgm`, `sky.g.pgm`, `sky.b.pgm`, `sky.a.pgm` are **P5** binary greyscale (8-bit); exact original alpha preserved in `A`.
- `sky.rgb.ppm` is **P6** binary RGB (discarding alpha, by explicit choice).
- `sky.rgba.pam` is **P7 PAM** with `DEPTH 4`, `TUPLTYPE RGB_ALPHA`, preserving alpha.
- `~channelPlane` returns raw bytes, not a PGM header; outputs are zero-based pixel-major row order.
- The shared `MediaRgbFrame` (H.264) has the same saveSplit/savePam/channelPlane methods, with synthesized alpha=255.

`MediaFileProbe~detect` recognizes the PNG signature before checking MPEG-TS
and MP4; `.MediaFile~open(source)` uses this probe. Extensions are ignored.
The existing TS/MP4 classes remain unchanged.

## Safety limits

- Compressed PNG up to 32 MiB; source reads capped at 64 KiB per request.
- Max dimensions 8192×8192 and max decoded pixel count 12,000,000;
  native output budget 64 MiB, including packet header.
- IHDR dimensions verified against decoded result and bytes checked exactly.
- `sourceIdentity` and size rechecked before and after PNG read.
- `MediaLocalByteSource` identities are explicitly `LOCAL_ONLY` and not
  adequate for a distributed immutable-version cache; use authoritative
  `MediaStorageRangeSource` identity for Storage Fabric.

## Native tests executed under ooRexx 5.3.0 r13196

`make -f Makefile.png` builds `libmoa_png.so` and `libmoa_raster.so`; both
compiled with `g++ -std=c++17 -O2 -Wall -Wextra -Werror` against supplied
r13196 headers, libpng 1.6.48.

- `test_png_channels.rex` PASS: 2×2 RGBA fixture with A=255,128,0,64,
  including nonzero RGB beneath A=0. All R/G/B/A plane bytes exact;
  P5/P6/P7 headers validated.
- `test_h264_rgb_planes.rex` PASS: RGB24 frame split into R/G/B, alpha
  deliberately 255, PGM and PAM exports.
- `test_sydney_png_rgba.rex` PASS: **five actual Sydney screenshot PNGs**,
  1920×1080 RGBA32, 8,294,400 decoded bytes each, source signature sniff;
  full four-plane PGM, PPM and RGBA PAM outputs tested for 20:32:17 frame.

User-provided screenshot pixels and broadcast overlays are NOT committed to
Git. Test scripts accept local root directory and may be skipped in CI unless
real files have been made available.
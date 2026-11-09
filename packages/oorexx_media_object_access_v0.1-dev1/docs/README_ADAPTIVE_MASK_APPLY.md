# Alchemy Media Object Access — dev6 absolute temporal subtraction

This is a **source delta** against PR #138 / `packages/oorexx_media_object_access_v0.1-dev1`.
Add `src/MediaRasterOps.cls`, `src/MediaTemporalMask.cls`, and `native/moa_raster_ops.cpp` / `native/Makefile`. Update the supplied `MediaPngFile.cls`, `MediaH264Frames.cls`, `MediaFileProbe.cls` and add the native `MediaJpegFile.cls`/`moa_jpeg_codec.cpp` if not already present in the base branch. Original MP4/TS seek-code remains unchanged.

See `docs/ADAPTIVE_ABSOLUTE_SUBTRACTION_DEV6.md` for all semantics and authority gates.

Build from `native/` with `OOREXX_ROOT` pointing to ooRexx 5.3 and `make`; the prebuilt `.so` binaries in this archive are **Linux build artefacts for the test host, not portable SDK binaries**. JPEG/libpng/shared-raster providers are existing Media Object Access dependencies and must be present in the library path. Rebuild each according to its own source on the target ABI. Source video, original JPEG photographs and screenshots are intentionally excluded.

Example:

```sh
cd native && OOREXX_ROOT=/path/to/oorexx make
cd ..
LD_LIBRARY_PATH=/path/to/oorexx/lib:$PWD/native REXX=/path/to/oorexx/bin/rexx SYDNEY_JPEG_ROOT=/mnt/data ./tests/run_native_dev6.sh
```

The script will skip real JPEGs unless the named source files are in `SYDNEY_JPEG_ROOT`. The synthetic native tests are independent of those user media. Tests and all five real JPEG comparisons **passed** using the supplied ooRexx r13196.

Limitations: integer translational registration only, single scale per processed image, <=16 aligned frames and <=2,000,000 pixels per mask. False bright regions from clouds are intentionally **not** classified as stars. Alpha remains independently exportable and is not silently flattened in PNG; JPEG/H264 alpha is synthetic opaque. Provenance and webcam clock selection remain with ooRexx/Moonsault.
# Media Object Access — Gopher Sphere v0.1 (source continuity)

Component lane: `media-object-access`. Canonical source: `packages/oorexx_media_object_access_v0.1-dev1` in `animatedads/alchemy`, draft PR #138. This sphere is a retrieval document; it does not fork the executable media classes or claim production deployment.

## Current baseline

- Identify actual file container by magic bytes (user-supplied `.mkv` files were MPEG-TS); support MP4, MPEG-TS, PNG, JPEG.
- ooRexx owns container/index/PES/sample mapping, native codec providers only decompress, and MediaRasterOps produces crop/resize/plane and signed/absolute temporal differences.
- MP4 and TS require source-identity-fenced persistent seek indexes, bounded Storage Fabric reads, and no linear full-file reads on every seek.
- Native H.264 pixel decoding through in-process codec-only provider (no libavformat demultiplexer or Python video path).
- Native PNG RGBA split R/G/B/A planes and alpha-preserving PAM, JPEG and adaptive 50% temporal subtraction.
- Native scale-aware registration uses independent landmark validation and refuses unqualified or cloud-contaminated astronomical observations.

## Caveats

Existing MP4 native 1080p random seek qualification used a standalone test-only flat parser for two recordings. The production adapter consuming the main MP4 sample/edit-list model still requires complete runtime integration. Site-specific tests must not be reported as all-codec compatibility. Original camera recordings are not Git deliverables.

On 11 Nov Rasen Falcon `sphere_check` for package names returned `UNKNOWN_SPHERE`; publishing this GitHub artifact does not prove Gopher runtime registration.
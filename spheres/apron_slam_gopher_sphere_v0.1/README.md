# Apron SLAM — engineering continuity sphere v0.1 (candidate)

**Runtime lane:** Rasen Falcon `apron-slam` (alias `anpr-slam`).
**Canonical source:** `packages/oorexx_apron_slam_v0.1/` in Alchemy.
**Status:** authored documentation / Gopher pack candidate. This Git directory
is **not** itself a Gopher sphere registration or an accepted runtime sphere.

Apron SLAM generates source-bound 3D projections of a vehicle cuboid and its
blank plate plane on a road, then compares alternative camera/vehicle models.
It is research-grade ANPR evidence modelling, not a service certified to read
real registrations or identify people. Read the articles in the `apron-slam`
pack and the qualification document.

## Ownership

- Apron SLAM: plate plane semantics, vehicle box, camera hypothesis, per-glyph
  exposure projections, relative candidate scores and sampling gates.
- Maths: 3D geometry arithmetic, trigonometry and precision/providers.
- SLAM family: evidence graph and contract/admission learning, not ANPR identity.
- Vision and Motion Control: frame-local observations and ephemeral motion tracks.
- Media Object Access: source-bound MP4/TS indexes and codec frame extraction.
- Python/ML providers: specialist computation only via Foreign Runtime or
  Python Macrospace, with ooRexx retaining orchestration/authority.

## Privacy and licensing

No provided private video, frame, image, extracted plate or registration text is
included. User-provided `UKNumberPlate.ttf` is *not* distributed and may only be
used according to its owner's terms; no commercial licence is presumed.

## Qualification

`python3 -m unittest discover -s tests -v` runs static sphere-contract tests.
Native ooRexx test counts are reported independently in the runtime package.
A Gopher import, registration or `sphere_check` is still required before
claiming an operational sphere.

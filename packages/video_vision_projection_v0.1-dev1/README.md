# Video Vision Projection v0.1-dev1

A non-invasive integration seam between the sealed FC Vehicle Motion worker and
ooRexx Vision `vision/0.1`.

The FC detector remains authoritative for decoding, camera-state gating, road
geometry and observational `CAR_MOTION` admission. This package consumes only
its already-admitted TSV evidence and projects moving observations into Vision
TRACK coordinates. It therefore adds no new vehicle event and cannot bypass FC
camera authority.

The first FC observation centroid defines a canonical TRACK coordinate. Each
later sample carries its own WORLD-to-TRACK translation, so motion evidence can
be accumulated without pretending observations at different timestamps were
simultaneous. Timestamp, confidence and source event identity are retained.

The package embeds the exact `oorexx_vision_v0.1-dev5-repaired1.zip` used for
qualification. The upstream dev5 architecture is promising for the video lane,
but the exact uploaded dev5 required small ooRexx-runtime repairs before its own
tests passed under r13196.

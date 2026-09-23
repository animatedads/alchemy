# Wire3D 0.1-dev5 — Claim / Evidence / Qualification

Dev5 generalises the frontier DEM lesson into a renderer-neutral evidence model.

## Founding distinction

A measurement made *about* an inferred object does not make the underlying object observed.
Wire3D therefore keeps three independent concepts:

- **Claim** — what a source declares about an object or property.
- **Evidence** — material/observations offered in support, retaining their own classification and provenance reference.
- **Qualification** — the result of an identified evaluator applying a method to a claim using identified evidence.

`SHOW EVIDENCE` is represented by `Wire3DSpatialObject~showEvidence`. It returns a passive projection receipt. It grants no authority and invokes no action on the projected domain object.

The optional `fixtures/terrain_qualification.py` is the first qualification fixture. It deliberately leaves the generated DEM `INFERRED` while classifying the directional delta audit itself as `MEASURED`. Exact 100.000 m endpoints are sampled using bilinear interpolation. No real-world CRS is assigned to the synthetic terrain.

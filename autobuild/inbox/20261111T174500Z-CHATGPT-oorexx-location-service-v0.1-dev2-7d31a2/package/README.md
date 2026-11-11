# Alchemy Location Service v0.1-dev2 — initial spatial fixture slice

Architecture: Tom Dyer. Coding and documentation: ChatGPT GPT-6.

A small native ooRexx prototype for explicitly CRS-bound spatial bounds, time-versioned jurisdiction overlays, operator/provenance references and fail-closed queries. This is a synthetic test seam, not operational GIS coverage.

Run: `sh run_spatial.sh` with ooRexx 5.3 r13196 and a working `rexx` binary.

The broader WorldModel and journey prototype are in a separate local dev2 test artifact and have not been integrated in this autobuild slice. Do not claim this package provides country coverage, a postcode geocoder, real boundary data, durable storage, SLAM integration or IntentionService registration. A query with missing time or inconsistent CRS must not silently claim a precise fix.

Source integration contract uses `alchemy.autobuild.integration/0.3`, and versioned publication `packages/oorexx_location_service_v0.1-dev2`.

Storage: capability-driven adapter planned. NoSQLServer v0.92-dev1's writable SQLite full-snapshot cost is unsuitable to assert as best for indexed reads; indexed Rexx/SQL evidence must be benchmarked against representative workloads. Storage Fabric and MI workers remain required for operational implementation.

See Rasen Falcon location-service lane and Location Service sphere for architecture, provenance, acceptance checklist and known limitations.

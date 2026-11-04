# ooRexx D-Bus native connector — qualification

This is an **independent qualification package**, not a replacement D-Bus implementation.

## Authority

- The existing native `dbusoorexx` package and its `dbus.cls` API are the compatibility baseline.
- An April 2026 `dbusoorexx.zip` addition to ooRexx upstream SVN has been reported but **its content has not been compared** with the 2015 release.
- No native C++ patch, interpreter execution, or source compatibility qualification is claimed by this repository folder.
- Preserve independence from BSF4ooRexx, Alchemy, ConnectSelector, Queue Fabric and RPC; integration adapters belong in separate projects.

## Verify archive(s)

```sh
python3 tools/audit_archive.py /path/to/dbusoorexx.zip
python3 -m unittest discover -s tests -v
```

The audit checks ZIP integrity, dangerous paths, duplicate normalized paths, encrypted members, Unix symlinks, and decompression ratios. It is **not** a malware scanner or a guarantee of safe execution.

## Engineering acceptance boundary

Before touching native source: retrieve exact upstream archives, record SHA-256 and repository revision, inspect the native API surface, build against a specified ooRexx runtime and libdbus, capture ABI and interpreter/callback tests, and preserve historical proxy/service/signal APIs.

## Publication lineage

This GitHub source increment follows the earlier local qualification packages v0.1–v0.4. It deliberately publishes a small reproducible auditor rather than asserting that the original native implementation has already been repaired.

## 23 October 2026 increment — v0.5

The ZIP auditor now enforces path safety and metadata size/ratio/member limits **before** CRC decompression; accepted entries are subsequently read in bounded chunks. It reports `integrity: NOT_RUN` for metadata rejections. Local regression tests: **14 PASS**; GitHub CI has not been run. This is archive screening, not proof that native C++ or ooRexx bindings compile or work.

Knowledge sphere: [ooRexx D-Bus Gopher sphere v0.1](../../spheres/oorexx_dbus_connector_gopher_sphere_v0.1/SPHERE_OOREXX_DBUS.md). It records the standalone package invariant and source-authority/qualification gates. No native C++ source is claimed as obtained or modified.

## 29 October 2026 increment — v0.6

Two new reusable, independent Python analysis tools are published:

```sh
python3 tools/compare_upstream.py historical.zip candidate.zip --out source-diff.json
python3 tools/api_inventory.py /tmp/candidate-src --compare-to /tmp/historical-src --strict
python3 -m unittest discover -s tests -v
```

The comparison checks ZIP metadata/security and CRC integrity before hashing individual files. The static ooRexx API inventory extracts declarations of classes, methods, attributes, routines and `::requires`, and flags removed public signatures. Both tools are analysis instruments, **not a replacement native D-Bus connector**; the source API scanner is not a complete language parser, and neither tool proves native ABI compatibility.

29/29 local synthetic-fixture tests PASSED (14 archive, 11 API, 4 upstream diff). The source archives have still not been obtained, so no historical-vs-candidate comparison occurred. Original native C++ and ooRexx execution are NOT_RUN. Autobuilder is NOT_RUNNING and GitHub CI is NOT_RUN. A host `dbus-run-session`/`dbus-send` smoke PASS is not the native ooRexx binding.

Gopher continuity: [D-Bus sphere v0.2](../../spheres/oorexx_dbus_connector_gopher_sphere_v0.1/SPHERE_OOREXX_DBUS.md). Coordination: Rasen Falcon lane `oorexx-dbus`, request REQ-00001903 to CLAUDE.

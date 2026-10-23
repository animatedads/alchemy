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

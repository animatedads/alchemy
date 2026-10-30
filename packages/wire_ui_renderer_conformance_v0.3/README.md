# Wire UI Renderer Conformance v0.3

Executable semantic-conformance kit for Web, Swing, GTK/Direct Linux and Android.

v0.3 adds **real-head evidence** instead of documentation-only alignment. The canonical v0.2 transcript remains the target contract; v0.3 measures current renderer heads against its ten required semantics and refuses to call partial support full conformance.

## Executed heads — 2026-10-29

- Swing `wire_ui_swing_v0.2-dev12.zip` SHA-256 `142dbb54adb9d0c2b88a3af043166894354cdb58d600cbd6f5f506b08f03d499`: 61/61 renderer tests PASS here.
- GTK/Direct Linux `wire_direct_linux_v0.1-dev41.zip` SHA-256 `2c93462bf5c2746eca4c3c235ae07e956680e8016a998cfe849dd3dd95461845`: native C core/loader/filter tests and all dev41 Python authority/static tests PASS here; QuickJS and GTK4 native compilation are SKIP because development libraries are absent.

Current result: Swing satisfies 8/10 shared gates; Direct Linux satisfies 3/10. Neither is falsely marked full PASS. See `qualification/REAL_RENDERER_HEADS_20261029.json`.

## Website/runtime gate

`qualification/RASENFALCON_RUNTIME_READINESS_20261029.json` consumes the current Rasen Falcon v0.4.4 source candidate, HTTPS v0.4.8 validation, LDAP dev22 validation and Wire Application Deployment candidate3 qualification. It reports `NOT_READY`: review staging exists, but release admission, exact modified HTTPS runtime/live TLS, LDAP installation/live LDAPS and live browser semantic roundtrip remain unproved.

## Rule

A renderer is full PASS only when all ten semantic gates are evidenced by the real renderer/access-point implementation. Upstream package tests are necessary but do not waive missing cross-renderer semantics.

Run the self-tests:

```sh
python3 -m unittest discover -s tests -v
```

Run the external head probe when the source trees are available:

```sh
python3 tools/probe_real_heads.py --help
```

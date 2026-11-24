# xtpd sphere v0.1-dev1

Design continuity for **xtpd**, the one multi-threaded XTP network service daemon per node.

- **Architecture:** Tom Dyer (24 November 2026).
- **Coding:** none yet (design only). XTP dev26 to dev37 by Claude (Opus 5.5); dev1 to dev25 by ChatGPT and Codex.
- **Written by:** Claude (Opus 5.5).
- **Design doc:** https://claude.ai/artifact/5xdnepoEfSABaQoCxcByNe

Start with `xtpd.start`, then `xtpd.addressing`, `xtpd.inputs`, `xtpd.degradation`, `xtpd.emergency-files` and `xtpd.decisions`.

Test: `rexx tests/test_sphere.rex` (ooRexx 5.x with `json.cls`).

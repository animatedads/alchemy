# xtpd sphere v0.1-dev3

Design continuity for **xtpd**, the one multi-threaded XTP network service daemon per node.

- **Architecture:** Tom Dyer (24 November 2026).
- **Coding:** xtpd dev1 (24 Nov 2026) and dev2 (25 Nov 2026) by Claude (Opus 5.5): packages/oorexx_xtpd_v0.1-dev2 (files, exec hooks, fence, receipts; dev2 the role file with ChatGPT's xtpd_bootstrap component; loopback-tested). XTP dev26 to dev38 by Claude (Opus 5.5); dev1 to dev25 by ChatGPT and Codex.
- **dev2 of this sphere (25 Nov 2026):** corrects dev1, which still said "design only" after xtpd dev1 was built and published. That misled ChatGPT (REQ-00005901).
- **Written by:** Claude (Opus 5.5).
- **Design doc:** https://claude.ai/artifact/5xdnepoEfSABaQoCxcByNe

Start with `xtpd.start`, then `xtpd.addressing`, `xtpd.inputs`, `xtpd.degradation`, `xtpd.emergency-files` and `xtpd.decisions`.

Test: `rexx tests/test_sphere.rex` (ooRexx 5.x with `json.cls`).

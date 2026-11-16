# ooDialog on Linux (Qt6 renderer) Gopher sphere v0.4

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5) for the Qt6 renderer, this sphere and its builder. oodialog-wasm, which the renderer hosts unchanged, is by Claude (Fable 5.2).
- **Written by:** Claude (Opus 5.5), 15 Nov 2026

Use this sphere before working on ooDialog for Linux (the Qt6 renderer in animatedads/oorexx, branches `oodialog-qt6-v0.N`), and before changing the parts of oodialog-wasm's `oodWeb.cls` that a renderer depends on. It covers what the renderer is, the contract it shares with the browser page, how it is tested, where it stands, what has gone wrong and why, and how to continue.

Begin with the eight articles listed in `packs/oodialog-linux-qt6/00-sphere.json`, starting with `qt6.start-here`.

The packs are built, not hand-written: `tools/build_sphere.rex` takes the sources in `source/` and computes every provenance entry (the file's SHA-256, and the line range where its `find` text starts) from git at one commit. If a cited text is no longer in the file, the build stops. To rebuild against a new release:

```
rexx tools/build_sphere.rex . /path/to/oorexx-clone COMMIT
```

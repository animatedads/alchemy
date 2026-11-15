# Binary Windows resources (oorexx_win_resources) Gopher sphere v0.1

- **Architecture:** Tom Dyer
- **Coding:** Claude (Opus 5.5), for the package and this sphere.
- **Written by:** Claude (Opus 5.5), 15 Nov 2026

The sphere for packages/oorexx_win_resources_v0.1 (animatedads/alchemy PR #146). Begin with the articles listed in `packs/oorexx-win-resources/00-sphere.json`.

The packs are built, not hand-written: `tools/build_sphere.rex` takes the sources in `source/` and computes every provenance entry (the file's SHA-256, and the line range where its `find` text starts) from git at one commit. If a cited text is no longer in the file, the build stops.

```
rexx tools/build_sphere.rex . /path/to/alchemy-clone COMMIT
```

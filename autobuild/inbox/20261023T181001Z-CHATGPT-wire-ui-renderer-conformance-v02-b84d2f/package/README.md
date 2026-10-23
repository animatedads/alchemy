# Wire UI Renderer Conformance v0.2

Executable semantic-conformance kit for the four first-class Wire UI renderer families: **Web, Swing, GTK/Direct Linux and Android**.

This package defines no new application model. It defines one canonical semantic input and one normalized transcript all renderers must match. Native layout, toolkit objects and styling are deliberately excluded.

## v0.2 adds

- bounded `RangeRequested(start,count)` demand semantics;
- event-time `renderedRevision` plus exact opaque `workspaceContext` for workspace-bound actions;
- exact published ResourceRef with cryptographic content address and no URL/copy escape;
- semantic activation;
- positive-list observations;
- committed-view definition deauthorisation must block actions and request resynchronisation;
- machine-readable capability/status matrix.

## Evidence heads

- Web: application-integration evidence at Alchemy Wire UI JS v0.4-dev6; a separately qualified dev7 lineage exists but is not silently substituted.
- Swing: Wire UI Swing v0.2-dev11; dev11 presentation refinement over retained dev10 semantic baseline.
- GTK/Direct Linux: `wire_direct_linux_v0.1-dev38.zip`; package metadata has known internal version/header drift which this kit does not repair.
- Android: renderer semantic checkpoint dev7; native resident ooRexx host tooling separately reached dev16. Host version is not renderer version.

## Rule

A renderer is **not PASS** until a real adapter produces the canonical transcript and `tools/compare_transcript.py` passes. The reference adapter only tests the kit itself.

Run:

```sh
python3 -m unittest discover -s tests -v
```
# Changelog

## 0.4 — 2026-11-16

- Renderer v0.10.0 (animatedads/oorexx branch `oodialog-qt6-v0.10`, commit `a67adba`), on and tested against oodialog-wasm `ee4b515` (v0.19.0): 50 of 50 offscreen and on xcb; sweep 84 of 122.
- Updated: current state, renderer contract (pagedTab, tab.outer, minimum tab width, pushed buttons), oodWeb proposals (v0.19.0 took tab_calcRect; the other three in a v0.19.0 patch).

## 0.3 — 2026-11-15

- Renderer v0.9.0 (animatedads/oorexx branch `oodialog-qt6-v0.9`, commit `cebff2e`), on and tested against oodialog-wasm `71f3590` (v0.18.0): 48 of 48 offscreen and on xcb; sweep 83 of 122.
- Updated: current state, renderer contract (tool tips, tv.hit, tv.rect), testing (tip expects, output checks), failure modes (v0.9.0 lessons), continuation (Linux ooDialog ownership; tool tips).

## 0.2 — 2026-11-15

- Added `profiles/oodialog-linux-qt6.json`, which the Gopher index needs: without it the sphere was merged (PR #147) but never listed.

- Renderer v0.8.0 (animatedads/oorexx branch `oodialog-qt6-v0.8`, commit `4aedf18`), on and tested against oodialog-wasm `2423db8` (v0.17.0): 45 of 45 offscreen and on xcb; sweep 81 of 122.
- Updated: current state, renderer contract (month calendar, ResizingAdmin, editable combo), testing (STEPS NOT FINISHED, the new Qt dialect), failure modes (v0.8.0 lessons), continuation (the Fluent controls lane).

## 0.1 — 2026-11-15

- Created the sphere for the Qt6 renderer, at renderer v0.7.0 (animatedads/oorexx branch `oodialog-qt6-v0.7`), tested against oodialog-wasm `fc16dfb` (v0.15.0).
- Eight articles: start here, current state, architecture, renderer contract, testing, oodWeb proposals, failure modes, continuation.
- Provenance computed by `tools/build_sphere.rex` from git, not typed.
- Written late. Until now, renderer v0.1.0 to v0.7.0 were documented only in the branches and in STATUS mail to TOM.

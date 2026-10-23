# ooRexx Font Manager Gopher sphere v0.1

Use this sphere for continuity of the shared font/typography service boundary across PDF, Wire UI, web output and application packaging.

The key rule is simple: **font discovery, semantic purpose selection, metrics, glyph planning, subsetting and coverage/fallback belong to FontManager, not to any renderer.**

Begin with the six objects listed by `packs/font-manager/00-sphere.json`.

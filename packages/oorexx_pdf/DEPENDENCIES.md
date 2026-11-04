# Dependencies

Runtime:
- Open Object Rexx 5.3.0 r13196 qualification baseline.
- `oorexx_font_manager` v0.1-dev4 for managed-font/fallback mode.

Optional provider tools used by the qualified managed-font path:
- Fontconfig (`fc-list`, `fc-match`).
- Python fontTools helper for SFNT glyph/metrics inspection.
- `pyftsubset` for subset creation.

The legacy Helvetica path remains available without FontManager.
No font binary is bundled by this package.

# Dependencies

Runtime core:

- Open Object Rexx 5.3.0 r13196 qualification baseline.
- No font files are bundled.

Optional providers:

- Fontconfig (`fc-match`) for host font discovery/matching.
- Python fontTools for exact SFNT metrics/glyph inspection.
- `pyftsubset` for subset and WOFF/WOFF2 packaging.

Intentions integration:

- `oorexx_intention_service` is an independent sibling Alchemy package. The release archive carries a qualification copy under `vendor/intention`; the GitHub source publication deliberately omits that embedded copy and resolves the sibling package through `INTENTION_SERVICE_ROOT`/`REXX_PATH`.

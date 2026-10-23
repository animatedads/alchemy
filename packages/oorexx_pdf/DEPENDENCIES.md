# Dependencies

Runtime core:

- Open Object Rexx 5.3.0 r13196 qualification baseline.
- `PdfDeflate.cls` remains the native ooRexx RFC 1950/RFC 1951 content-stream compressor.

Managed-font path:

- `oorexx_font_manager` v0.1-dev2 is the renderer-neutral font authority used by PDF dev5 for semantic font selection, glyph plans, exact advances and subsetting.
- Fontconfig and Python fontTools/`pyftsubset` are optional provider backends of Font Manager, not PDF-owned dependencies.

The release archive carries a qualification copy under `vendor/font_manager`; the GitHub source publication deliberately omits that embedded copy and resolves the independently published sibling package through `FONT_MANAGER_ROOT`/`REXX_PATH`.

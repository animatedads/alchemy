# ooRexx PDF v0.1-dev6

A native ooRexx PDF 1.4 writer and flowed report renderer. Runtime PDF generation does not shell out to a PDF library or compressor.

## Core

- byte-accurate PDF objects, xref and `startxref`
- PDF literal string escaping
- compressed content streams using native ooRexx RFC 1950 zlib framing over the existing RFC 1951 fixed-Huffman DEFLATE implementation
- A4 page tree, Helvetica and Helvetica-Bold resources
- legacy `PdfReport` field API retained

## Flow/report layer

`PdfFlowReport` supports:

- automatic page creation and page numbering
- flowed paragraphs and field/value blocks
- any number of interleaved paragraphs and tables
- `PdfTable` rows supplied directly as ooRexx `Array` objects
- multiple tables in one report
- caller-supplied relative column widths
- word wrapping within cells
- repeated table headers after page breaks
- alternating row shading
- rows taller than a page split safely over multiple pages
- explicit newlines and overlong words

Example:

```rexx
headers = .Array~of("TPS", "Owner", "Description", "State")
widths = .Array~of(70, 90, 270, 70)
rows = .Array~new
rows~append(.Array~of("TPS-001", "Alice", "Collected", "DONE"))

t = .PdfTable~new(headers, widths)
t~title = "TPS Reports"
t~addRows(rows)

r = .PdfFlowReport~new
r~title = "TPS Register"
r~addParagraph("Quarterly collection report")
r~addTable(t)
r~render("tps-register.pdf")
```

## Qualification

`tests/test_flow_tables.rex` intentionally creates a six-page document with 86 rows across two tables, an oversized row which must continue onto another page, repeated headers, row shading, wrapped cells and narrative between tables.

`tools/run_environment_test.sh` executes the native ooRexx tests and, when present, uses `pdfinfo` and `pdftotext` as independent consumers.

## dev3 additions

- `PdfCell` for optional cell metadata without changing ordinary Array-fed rows.
- Horizontal cell spanning (`span`) with correct grid suppression across the spanned columns.
- Per-cell left/center/right alignment and bold cells.
- Table column alignment metadata via `setAlignments(Array)`.
- Table column type metadata via `setColumnTypes(Array)`; numeric types default to right alignment.
- `decimal2`, `money2`, `percent`, and `percent2` presentation types.
- A4 landscape reports via `report~landscape` (portrait remains the default).
- Explicit flow page breaks via `report~addPageBreak`.
- Backward compatibility: dev2 plain Arrays, multi-page row continuation and repeated headers remain unchanged.

The advanced qualification deliberately combines 72 numeric detail rows, Array-sourced data, full-row colspans, repeated headers, landscape geometry and a forced management-section page break.

## dev4 additions

- `addSection(text[, level])` emits a visible heading and a PDF outline/bookmark destination.
- A catalog `/Outlines` tree is generated from section destinations after pagination, so bookmarks target the final page positions rather than guessed pages.
- `addLink(text, uri[, size])` emits underlined link text plus a real `/Link` annotation with a `/URI` action.
- `addJpeg(path[, displayWidth[, caption]])` embeds JPEG bytes directly as `/DCTDecode` image XObjects; no image conversion program is required at runtime.
- JPEG dimensions and colour component count are read natively in ooRexx from SOF markers.
- `headerText` adds a reusable page header while the existing footer and `Page N of M` footer remain intact.
- Images, links, paragraphs and Array-fed tables can be interleaved in the same flow and continue through normal automatic pagination.

`tests/test_rich_document.rex` combines all of these with a multi-page TPS table. The generated PDF is also structurally checked for `/Outlines`, `/Link`, and `/Image` objects.

## dev5 additions - shared Font Manager integration

`PdfFlowReport` can now consume an injected `FontManager` with `setFontManager(manager[, tempDir])`. PDF does not search for fonts or calculate SFNT metrics itself.

When a manager is supplied:

- `PRINT_BODY` and `HEADING` semantic purposes select the body and bold/heading faces;
- the report preflights its complete visible text corpus before pagination;
- Font Manager creates TrueType subsets and a renderer-neutral glyph plan;
- line wrapping, cell alignment and link geometry use real glyph advances from that plan;
- subsets are embedded as CID TrueType fonts with `/Identity-H` encoding;
- PDF creates `/CIDToGIDMap` and `/ToUnicode` streams so rendered text and extracted text agree;
- UTF-16BE document strings are used for Unicode metadata and outline titles;
- font programs are stored without the native ooRexx DEFLATE pass, avoiding an unnecessary pure-Rexx compression cost on already compact subset fonts.

The default legacy Helvetica path remains available when no Font Manager is injected.

The bundled `vendor/font_manager` directory is a qualification snapshot of the independent `oorexx_font_manager_v0.1-dev2` package. No font binaries are bundled in either source package.

`tests/test_managed_unicode_fonts.rex` creates a multipage Array-fed TPS report containing Latin diacritics, Greek, Cyrillic, punctuation and currency symbols. Independent qualification requires `pdffonts` to report embedded/subset/Unicode CID TrueType fonts and `pdftotext` to reproduce the multilingual text exactly.

## GitHub source layout

PDF dev5 consumes the independently published `oorexx_font_manager` package. The standalone release archive contains a qualification copy under `vendor/font_manager`; the Alchemy GitHub source tree deliberately omits that embedded copy. `tools/run_environment_test.sh` resolves sibling `packages/oorexx_font_manager` by default; set `FONT_MANAGER_ROOT` to override it.


## dev6 — mixed-script FontRunPlan consumption

- `PdfManagedFontSet` pre-plans the report corpus through Font Manager and embeds one subset per face actually used.
- Text width and drawing use the precomputed character-to-face assignment; wrapping does not redo host discovery.
- PDF currently requires TrueType because its descendant emitter is CIDFontType2; OpenType/CFF is rejected rather than mislabeled.
- PDF metadata and outline strings use direct UTF-16BE independently of page-font fallback.

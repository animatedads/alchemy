# ooRexx PDF v0.1-dev4

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

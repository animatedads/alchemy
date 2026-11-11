# DOCY -> PDF and OpenDocument Text: provider integration v0.2a

**Architecture:** Tom Dyer's DOCY shared graph.  **Adapters:** ooRexx; format components supplied by existing Alchemy packages.  **Status:** local adapter-contract candidate, not yet end-to-end provider qualification.

## Repository inventory inspected 2026-11-08

- `packages/oorexx_pdf/README.md` reports native PDF 1.4 writer `oorexx_pdf` v0.1-dev6. `src/PdfCore.cls` exports `PdfFlowReport` and `PdfTable` with `addSection`, `addParagraph`, `addTable`, `addRows` and `render`. Tables, pagination, bookmarks and JPEG are available. The optional Font Manager enables Unicode subsets, but its external tool boundary must be documented and approved separately.
- `packages/oorexx_odt/README.md` reports ODT access v0.1-dev1. `src/OdtAccess.cls`, `src/OdtModel.cls`, `src/OdtOpenFormat.cls` expose `OdtAccess~create`, `~open`, `~save`, and `OdtDocument~addHeading/~addParagraph/~addTable`; `OdtTable~addValues`. The writer emits OpenDocument 1.3 XML, a ZIP package with uncompressed first `mimetype` entry. **Not fully ooRexx-only at present:** it shells out to `mkdir`, `rm`, `zip`, and `unzip`, and its semantic model currently covers only headings, paragraphs and tables. Imports of richer ODT documents cannot be assumed lossless.
- Both are **publication projections**, not DOCY stores. Never infer changes in shared source facts from an externally edited PDF or ODT without a separately validated import-and-propose process.

GitHub sources (exact Git blob SHA at inspection):

- PDF `src/PdfCore.cls`: `3c14365ae43b31079aea73bc5b7bc7ff9e9a4a78`
- ODT `src/OdtAccess.cls`: `d5f7d98ffaf4fa99260eb1bda9bd874660deb879`
- ODT `src/OdtModel.cls`: `725ccfe74f8e315becb13f8740e9551eee199eee`
- ODT `src/OdtOpenFormat.cls`: `54e20b012bc27321aa73454c5293e669b0d7356e`

## DOCY adapter implementation

`docy_office.cls` has two public entrypoints:

- `.DocyOfficePublisher~publishPdf(graph, docKey, path, providers)`
- `.DocyOfficePublisher~publishOdt(graph, docKey, path, providers[, creator])`

`providers` is a `.Directory` containing the class references `pdf.flow`, `pdf.table`, `odt.access`, and `odt.table`. This avoids embedding path-specific `::requires` directives or duplicating the providers in DOCY. All source binding and overrides resolve directly from the DOCY graph. Each DOCY node owns `renderPdf` and `renderOdt`; the common publisher makes **no central type-name select**. Format sinks insulate node classes from Alchemy PDF and ODT implementation details.

Validation runs first; STOP blocks the publish. The result includes `path`, `format`, and a `.DocyReport` with `STOP/WARN/INFO`. It does not imply a durable publish receipt, transaction or cryptographic event, which remain TODO.

### Mapping

| DOCY type | PDF dev6 | ODT dev1 | Known fidelity issue |
| --- | --- | --- | --- |
| section | `addSection` (outline/bookmark) | `addHeading` | Heading level fixed to 2 by current DOCY section model |
| text, factfield | `addParagraph` | `addParagraph` | Inline rich text/semantic tags not yet modeled |
| table | `PdfTable` with Arrays | `OdtTable` with Arrays | Widths currently equal; no cell spanning/style preservation |
| toc | Printed list + PDF heading/bookmarks | Printed list of headings | Not a live Writer TOC field; no page numbers |
| credits | Heading + explicit roles | Heading + explicit roles | DOCY validation still mandatory |
| command | Paragraph with `$` prefix | Paragraph | Explicit WARN: code style is not monospace yet |
| svg | Visible omission marker | Visible omission marker | Explicit WARN; asset embedding and secure SVG rendering required |
| custom type | Node's override | Node's override | Missing renderer creates WARN, never silent output |

The PDF backend could add native JPEG nodes now; ODT image embedding requires expansion of ODT's model/manifest/package writer. SVG should be rendered through the existing approved Alchemy asset/vision/geometry pipeline before passing an accepted image to each provider, not by opaque ungoverned converters.

## Run with actual Alchemy providers

```sh
# From this package directory; put real providers on the class path
export REXX_PATH="$PWD:$PWD/ooRexx-pdf/src:$PWD/ooRexx-odt/src:/path/to/ooRexx/usr/local/bin"
export LD_LIBRARY_PATH="/path/to/ooRexx/usr/local/lib"
/path/to/ooRexx/usr/local/bin/rexx publish_office_demo.rex alchemy_shared_graph.docy
```

`publish_office_demo.rex` explicitly requires the two real packages. **It was not executed with those packages here**, so PDF/ODT binary export is not yet claimed as qualified.

### Verification performed in this environment

- ooRexx 5.3.0 r13196 from the supplied Debian package.
- DOCY v0.2 existing regression: **44 PASS**.
- Independently registered DOCY node type: **2 PASS**.
- DOCY PDF/ODT **provider-interface test doubles**: **24 PASS**. Tests cover layered title, inherited placements, typed fact value inside tables, credits, warnings for unsupported SVG, provider-absence STOP, invalid-doc STOP, nonmutating publication and updating a shared fact before regeneration.
- Office destination registration / graph impact planning: **1 PASS**. An address-fact update now reaches six registered paths across three documents, including the PDF and ODT outputs.
- Total **71 passing assertions/checks**, with **zero failing checks**. The 24 contract tests do not replace integration tests against the real Alchemy PDF and ODT packages. The `register_office_formats.rex` bootstrap currently modifies output registrations directly; registration itself is not yet an event transaction.

## Required before release qualification

1. Stage the **exact** four upstream ODT/PDF sources and run real `PdfFlowReport` and `OdtAccess` against `alchemy_shared_graph.docy`; independently read output with `pdfinfo`/`pdftotext`, ODT archive validation, and LibreOffice Writer opening. Render PDF pages and inspect them visually.
2. Replace ODT command-line `zip/unzip` and temporary file management with a native Alchemy Archive/Storage Fabric package service, with ZIP path traversal protection and integrity checks.
3. Provide semantic ODT text styles, page structure, images and actual Writer TOC; add a true PDF/SVG asset path. Preserve ordered TOC and robust table layout.
4. Pin source data revisions and source-of-truth dependencies in publication receipts; include document key, graph revision, source revisions, output hash and diagnostic report.
5. Define a guarded import route for edited ODT: read a snapshot, compare DOCY keys and placements, propose an event impact plan, never blindly overwrite the graph from an office file.
6. Finalize event-only graph mutation and Storage Fabric cryptographic history before treating generated outputs as operational records.

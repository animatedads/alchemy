# Architecture

The package has three layers.

1. **PdfWriter / PdfPageCanvas** own PDF syntax, object numbering, byte offsets, content streams and primitive drawing commands.
2. **PdfFlowReport / PdfTable** own pagination and report layout. They deal only in logical blocks and ooRexx Arrays; they do not know xref offsets or compression framing.
3. **Adapters** such as `PdfNotNotesRenderer` translate application objects into report blocks without duplicating the application's authoritative data model.

Table layout is streaming by row. Cells are wrapped into logical line Arrays. A row is emitted in one or more page-sized slices. If a slice crosses a page boundary, a fresh page is opened and the table header is repeated before the remaining row lines are emitted. This means one pathological row cannot overflow the media box.

Column widths are interpreted proportionally and scaled to the printable width. The current built-in Helvetica renderer uses a conservative character-width estimate rather than embedded font metrics. That is intentionally separated from the PDF container layer so richer font metrics can be added later without changing report semantics.


## dev3 table metadata boundary

Rows remain ordinary ooRexx Arrays. A caller only constructs a `PdfCell` when a cell needs metadata such as span, alignment, or bold rendering. This preserves the zero-adapter path for existing Array tabular sources while allowing richer report layout. Column presentation metadata belongs to `PdfTable`; the low-level `PdfWriter` remains unaware of tables and flow layout.


## dev6 — renderer consumes font runs

The managed-font adapter consumes Font Manager run planning instead of forcing one face per semantic role. `PdfManagedFontSet` pre-plans the corpus, creates one subset per used face and records the character-to-face assignment. PDF retains CID/resource encoding authority. The current emitter constrains planning to TrueType because it emits CIDFontType2/FontFile2; CFF requires a real CIDFontType0/OpenType implementation.

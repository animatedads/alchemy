# Design

`OdtDocument` is the semantic authority inside this library. `OdtPackageReader` and `OdtPackageWriter` project that model to/from the OpenDocument package. The package validates the ODT MIME type and preserves document order for headings, paragraphs and tables.

The intention-facing surface is deliberately small and dynamic: available read intentions are derived from the blocks actually present in the opened document.

NotNotes or another domain application remains authoritative for its own business objects; an ODT produced from those objects is an interchange projection, not a new source of business truth.

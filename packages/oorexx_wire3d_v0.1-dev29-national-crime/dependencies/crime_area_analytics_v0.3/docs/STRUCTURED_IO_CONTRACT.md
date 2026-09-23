# Structured I/O Contract

Crime Area Analytics does not implement CSV or JSON syntax.

## CSV

The only CSV parser/writer authority is the ooRexx distribution class:

```rexx
::requires "csvStream.cls"
```

and `.CsvStream`.

Application code may:

- choose whether a source has a header;
- validate decoded header names;
- map decoded columns to domain attributes;
- consume the `.CsvStream~csvLineIn` returned Array;
- consume `.CsvStream~values` when header-keyed access is useful;
- write Arrays/collections through `.CsvStream~csvLineOut`.

The rule covers police source files, LSOA references, derived snapshots, category shards and manifests, denominator relations, and GIS-derived neighbour relations.

Application code must not:

- split records on commas;
- implement quote state;
- unescape doubled quotes;
- reconstruct multiline records;
- hand-escape CSV output;
- use ordinary `linein`/`lineout` as a CSV parser/writer.

`CsvStream` therefore remains authoritative for commas inside quoted fields, embedded quotes,
multiline fields, BOM handling and physical/logical record boundaries.

## JSON

The only JSON syntax authority in this package is the ooRexx distribution class:

```rexx
::requires "json.cls"
```

and `.json`.

Use:

```rexx
doc = .json~fromJsonFile(path)
.json~toJsonFile(path, value, .true)
```

No package-local JSON lexer, tokenizer, string escaper or parser is permitted.

The current crime package uses `json.cls` to load the generated public filter catalogue.
GeoJSON geometry itself belongs to the NoSQLServer/GIS boundary rather than being reparsed in
the crime-domain model.

## Why this is a hard contract

CSV and JSON escaping have enough edge cases that a second implementation creates unnecessary
semantic and evidential risk. The ooRexx-supplied classes are part of the selected runtime and
are therefore the common parsing authority for this project.

## Sparse derived relations

A structured-I/O rule does not require inefficient relation production.  Category shards are
sparse: one `CsvStream` is opened per published category and existing non-zero frame/category
cells are routed to it in one frame traversal.  No alternate CSV encoder is introduced for
that optimization.

Readers must also tolerate omitted trailing empty CSV fields as decoded by the platform class.
For example, an LSOA catalogue row with no `geometry_ref` is still a valid area row; it is not
silently discarded merely because the decoded Array has no fourth item.

# ooRexx Spreadsheet + Intentions v0.1-dev4

First native ooRexx spreadsheet package slice for open spreadsheet files, with a dynamic Intention Service v0.1-dev9 bridge.

## What the package does

- opens `.xlsx` OOXML packages directly;
- opens `.ods` ODF spreadsheet packages directly;
- preserves stored cell type, raw value, display/text value, formula text, cached formula result, style index and number-format metadata separately;
- discovers table-like relations conservatively from sheet structure;
- infers fields, likely keys, mixed stored types, numeric-looking text and formula-bearing columns;
- exposes read-only spreadsheet intentions through the existing Intention Service architecture;
- supports ordinary natural requests and explicit `using spreadsheet ...` sphere requests;
- includes a complete environment qualification script and deliberately nasty XLSX/ODS fixtures.

## Deliberate semantic boundary

This package is **not** an Excel or LibreOffice calculation engine. It never claims that an OOXML/ODF formula has been independently evaluated. Formula text and the package's cached result are retained separately.

That distinction is intentional. A visible `$1,000` may be:

- numeric `1000` plus a currency number format; or
- literal text such as `$1000`.

The model preserves that distinction and the relation layer reports suspicious coercion boundaries rather than quietly normalising them.

## Objects

```text
SpreadsheetWorkbook
  SpreadsheetSheet
    SpreadsheetCell

SpreadsheetCatalog
  SpreadsheetRelation
    SpreadsheetField

SpreadsheetIntentEnvironment
  IntentionService v0.1-dev9
  SpreadsheetIntentionProvider
  SpreadsheetIntentRuntime
```

## Current intentions

Examples:

```text
what sheets are in this workbook
describe customers
show customers
show customers in Rochdale
show customers named smith
show customers credit limit > 800
count customers by city
total credit limit customers
find formulas
find type hazards
using spreadsheet show customers in Rochdale
```

Available relations and fields are discovered from the current workbook. They are not compiled into a permanent action catalogue. Re-running `SpreadsheetIntentEnvironment~refresh` rebuilds the intention surface from current workbook evidence.

## Read-only through dev4

Mutation remains intentionally outside the package through dev4. Spreadsheet writes need a preservation contract for package relationships, formulas, shared strings, styles, named ranges, tables, validation, hidden content and application-specific extensions. Pretending that changing one XML node is sufficient would recreate the exact class of spreadsheet corruption this package is intended to avoid.

The intention plans therefore declare `READ_ONLY`.

## Qualification

Against a supplied ooRexx Debian package:

```bash
tools/test_environment.sh --deb /path/to/oorexx-5.3.0-13196....deb
```

Or against an installed interpreter:

```bash
tools/test_environment.sh --rexx /path/to/rexx
```

The harness regenerates fixtures, runs reader/relation/intention contract tests, then executes end-to-end XLSX and ODS conversational probes.

## Runtime dependencies

- ooRexx 5.3.0-compatible runtime
- `unzip` for ZIP-package extraction
- Python 3 only for regenerating the deterministic test fixtures; runtime library use does not require Python

## Pinned dependency

The package carries the exact `oorexx_intention_service_v0.1-dev9.zip` under `deps/`. The qualification harness extracts that pinned archive into an isolated runtime directory, so it does not accidentally bind to another Intention Service revision on `REXX_PATH`.

## dev2 repair

Real LibreOffice-style ODS files may encode the unused tail of a sheet as very large repeated blank rows and columns (for example 1,048,474 blank rows and 1,024 blank cells). dev1 expanded those repetitions literally and could stall on an otherwise small workbook. dev2 recognizes structurally blank repeated ODS rows/cells and advances coordinates without materializing them. Nonblank repeated cells retain ordinary expansion semantics. The regression fixture now includes the large blank-tail pattern.


## dev3 — discovered cross-sheet relationships

The catalog now discovers conservative relationship evidence between table-like sheets. A relationship is executable only when a source ID-like field matches a probable unique key on another relation and at least 80% of observed nonblank source values are present in the target key. Relationship evidence retains confidence and observed coverage.

New intentions include `list relationships` and related-record traversal such as `show orders for customers in Rochdale`. The traversal is built from the current workbook catalog on refresh; there is no permanent Customers/Orders mapping. Ambiguous or unsupported joins are not guessed.

## dev4 — multiple relations per physical sheet

A worksheet is no longer assumed to contain one table. The discovery layer segments table-like regions by header evidence, contiguous columns and blank structural boundaries. Multiple vertical or side-by-side regions may therefore become independent `SpreadsheetRelation` objects while retaining their physical sheet/row/column coordinates.

When more than one region is discovered, relation names are derived conservatively from ID-like headers where possible (`Customer ID` -> `Customers`, `Order ID` -> `Orders`). Otherwise a stable sheet/region name is used. `what tables` / `list relations` exposes the discovered regions and their physical bounds.

Summary-like rows (`TOTAL`, `SUBTOTAL`, `GRAND TOTAL`, or formula-majority summary rows) are excluded from both returned records and field type inference. The audit surface reports `MULTIPLE_TABLE_REGIONS` and `SUMMARY_ROW_EXCLUDED` evidence so that these decisions are visible instead of silently rewriting the workbook's meaning.

Cross-region relationship discovery uses the same conservative key/coverage rules as cross-sheet discovery, so two accidental tables on the same sheet can participate in a read-only traversal without being physically separated into worksheets.

## dev5 — declared OOXML tables are authority

Large publication workbooks frequently contain explicit Excel table definitions under `xl/tables/`. dev5 reads those declarations before attempting heuristic table discovery. Declared table name, display name, worksheet, range and column names are retained as workbook metadata and their range is used as authoritative region evidence.

For large `.xlsx` publications, callers may avoid materialising unrelated cover, notes and report sheets:

```rexx
tables = .SpreadsheetReader~declaredTables(path)
workbook = .SpreadsheetReader~openDeclaredTable(path, "table_8")
```

`openDeclaredTable` builds a workbook containing only the requested table range and then exposes the ordinary dynamic spreadsheet intention environment over that scoped workbook. Heuristic relation discovery remains the fallback for spreadsheets without declared tables and for ODS.

Field aliases now strip trailing `[note ...]` annotations and line breaks, while the original header text remains authoritative. This allows natural requests such as `age group = 16 to 24` against publication headers like `Age group\n[note 4]` without rewriting the source schema.


## dev6 — safe interchange and new-workbook creation

Adds an object-first `SpreadsheetTableData` interchange contract plus XLSX, ODS, CSV and TSV writers and CSV/TSV readers. `SpreadsheetTableData~fromRelation` preserves the originating relation and sheet as provenance objects. Export creates a new workbook; dev6 deliberately does not mutate arbitrary existing workbooks. Text values are always written as text even when they begin with spreadsheet formula sigils such as `=` or `@`; formula creation remains an explicit future capability. This is the intended seam for NotNotes and other object systems: adapt authoritative objects to ordered columns + Rexx row objects, then publish them without flattening the source authority into application-specific glue.

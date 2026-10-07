# Design notes

## 1. Spreadsheet storage is not spreadsheet execution

OOXML and ODF make workbook storage inspectable, but they do not make Excel, Calc and other engines semantically identical. `SpreadsheetCell` therefore separates:

- `storageType`
- `valueType`
- `rawValue`
- `textValue`
- `formula`
- `cachedValue`
- style / number-format metadata

No layer is allowed to manufacture a numeric value from currency-looking text merely because a human might read it as money.

## 2. Discovery is dynamic evidence

A sheet is not automatically a table. `SpreadsheetRelationDiscoverer` looks for a plausible header row, builds field evidence from actual stored cell types, scores the discovered relation, and emits diagnostics for ambiguity.

This follows the Intention Service rule that available purposes should be re-evaluated as context/evidence changes. `SpreadsheetIntentEnvironment~refresh` rebuilds the catalog and registration evidence instead of treating a first scan as permanent truth.

## 3. Database-like use is supported without pretending it is a database

`SpreadsheetRelation` offers records, conservative filters, grouped counts and numeric sums over genuinely numeric stored values. Numeric-looking text is not included in numeric aggregation.

That means a column containing numeric `1000` and text `"$1000"` remains semantically dirty. The package reports the problem rather than silently picking an Excel/Calc coercion rule.

## 4. Intentions are plans, not direct cell tricks

The spreadsheet provider proposes meanings into ordinary Intention Service arbitration. Read operations get conditional `READ_ONLY` plans. The provider cannot dispatch around service policy.

Current read intentions cover:

- workbook/sheet inventory;
- relation description;
- record search;
- equality, containment and simple numeric comparison;
- grouped count;
- numeric sum;
- formula inventory;
- type/coercion hazard audit.

## 5. Future write boundary

A future writable package should introduce a transaction/edit model rather than exposing arbitrary XML replacement. Before save it should validate at least:

- package part/relationship preservation;
- shared strings and inline strings;
- styles and number formats;
- formulas and cached-value invalidation;
- named ranges / table definitions;
- merged cells;
- validation rules;
- hidden rows, columns and sheets;
- calc/recalculation flags;
- application extension parts;
- round-trip invariants.

Write intentions should then declare mutation side effects and authority requirements through the Intention Service plan contract.


## Cross-sheet relationship evidence (dev3)

Relationship discovery is evidence, not declared schema. Exact field-name alignment with a probable target key plus observed value coverage is required for the first slice. The intention layer may traverse a relationship only when exactly one discovered link connects the requested result and filter relations. This deliberately prefers UNKNOWN over a plausible but ungrounded join.

## 6. Physical sheet and semantic relation are separate (dev4)

A worksheet is a storage surface, not a relational boundary. Discovery now scans for independent header/data regions and records explicit `headerRow`, `startColumn`, `endColumn` and `dataEndRow` bounds on each relation. This allows two or more accidental tables to coexist on one physical sheet without being merged into one false schema.

Region segmentation is intentionally conservative. A candidate header requires at least two contiguous populated cells with a text majority and a structural boundary above it. Data extends until the first blank row across that region's column span. This is evidence-based discovery, not a claim that every visually formatted block is a table.

Summary rows are a separate semantic category. Rows labelled TOTAL/SUBTOTAL/GRAND TOTAL, and rows dominated by formulas, are not allowed to contaminate record materialization or field-type inference. Every exclusion is emitted as audit evidence.

The consequence for intentions is important: natural-language requests bind to discovered relations, not worksheet names. A single sheet may therefore expose `Customers` and `Orders`, and the intention layer can traverse a discovered relationship between them while retaining the original physical coordinates for provenance.

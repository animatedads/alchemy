# Reference consumer: ONS spreadsheet scientific report

The ONS spreadsheet qualification is the reference usage shape for this provider:

```text
SpreadsheetRelation objects
        |
        v
IntentionService
        |
        v
ScientificSolverDirective
        |
        v
ScientificSolverProvider
        |
        +-- dynamically selects ONS_SPREADSHEET_ANALYSIS
        |
        v
OnsScientificAnalysis (native object)
        |
        +-- MLGraph
        +-- source SpreadsheetRelation evidence
        +-- original spreadsheet-record evidence on graph points
        |
        v
SVG / PDF presentation
```

The example matters because the consumer supplies its own deterministic specialist
rather than requiring the solver to understand ONS tables. The specialist receives
the original spreadsheet-domain object, composes MLGraph, and returns a native
analysis object. Source records and relations remain attached as evidence.

This is the intended extension pattern for other components: register expertise at
the seam instead of adding consumer semantics to `ScientificSolverProvider`.

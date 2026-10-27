# Architecture — ooRexx String Template v0.1-dev3

The package treats template source as parsed data, not executable Rexx.

```text
caller formatter registry --snapshot--> sealed template registry
                                      |
source -> TemplateParser -> segments -+-> StringTemplate
                                      |       |
                                      |       +-- requirements / missing bindings
                                      |       `-- withFormatters -> new StringTemplate
context ------------------------------+-> render / renderTo
                                      |
render policy ------------------------+
```

The caller owns data authority. Domain libraries own domain formatters. Render policy owns output escaping. StringTemplate owns parsing, substitution and the stability of formatter-name bindings once captured.

## Deterministic formatter binding

Dev2 retained the caller's live registry. A later `register` call could therefore change the meaning of an existing template. Dev3 removes that temporal coupling: construction snapshots the registry and seals the snapshot.

The snapshot is a binding snapshot, not a deep clone of formatter objects. A formatter object may deliberately carry state; that state remains owned by the formatter implementation.

## Inspection before binding

Requirement inspection must remain useful before domain authorities are present. A template may therefore reference an unavailable formatter and still be parsed and inspected. `missingFormatterNames` reports the unsatisfied names without invoking formatter code. `validateBindings`, `render` and `renderTo` fail closed before rendering if any formatter remains absent.

Explicit rebinding creates a new object through `withFormatters(registry)`. Existing compiled templates never change meaning because a shared registry was later mutated.

## Non-execution boundary

No template expression is sent to `INTERPRET`. No object message is derived directly from template text. `TemplateObjectView` remains the explicit allowlisted bridge to ordinary ooRexx objects. Requirement inspection does not resolve values or invoke formatters.

The language remains interpolation-only: no loops, conditions, macros or arbitrary expressions.

# Changelog

## v0.1-dev2 — 2026-10-23

Continuation of the qualified dev1 template language; syntax is unchanged.

- Added `TemplateRequirements`, `StringTemplate~formatterNames` and `StringTemplate~requirements` for non-executing compile-time requirement inspection.
- Added `StringTemplate~renderTo` for segment-by-segment output to caller-owned `charOut` sinks.
- Completed JSON string-content escaping for all `00`x..`1f`x control bytes.
- Made `TemplateContext~putObject` enforce the same non-blank root-name contract as `put`.
- Added qualification fixtures for requirement inventory, streaming equivalence, JSON control escaping and blank object-context rejection.

## v0.1-dev1

First executable cut.

- Compiled `${path}` interpolation.
- Nested Directory traversal.
- Explicit allowlisted ooRexx object projection through `TemplateObjectView`.
- Registered formatter objects and formatter arguments.
- Strict and keep-missing policies.
- Plain, HTML and JSON-string-content render policies.
- `$${...}` literal placeholder escape.
- Inspectable unique variable/path inventory.
- No `INTERPRET`, arbitrary expression execution, loops or conditionals.

# Changelog

## v0.1-dev3 — 2026-10-27

- Added sealed formatter registries with `seal`, `isSealed` and `snapshot`.
- `StringTemplate` now captures a sealed formatter-registry snapshot at construction, so caller registry mutation cannot silently alter an existing template.
- Preserved dev2's pre-binding requirement-inspection workflow: unavailable domain formatters do not prevent parsing or inspection.
- Added `missingFormatterNames` and `validateBindings` for explicit binding-state inspection and fail-closed validation.
- `render` and `renderTo` validate all formatter bindings before resolving values or emitting output.
- Added `withFormatters(registry)` to create an explicitly rebound template without mutating an existing one.
- Consolidated context normalization so `render` and `renderTo` share the same conversion path.
- Added `test_formatter_binding.rex` covering registry isolation, sealed mutation rejection, unbound requirement inspection, render-time fail-closed behaviour and explicit rebinding.
- Template syntax is unchanged.
- Corrected the JSON-policy fixture expectation to match ooRexx literal semantics; the JSON escaper implementation itself was unchanged.
- Fresh ooRexx 5.3.0 r13196 qualification on 2026-10-29: `rexxc` PASS and 7/7 runtime fixtures PASS.

## v0.1-dev2 — 2026-10-23

- Added `TemplateRequirements`, formatter requirement inspection and `renderTo`.
- Completed JSON control-byte escaping and blank object-context rejection.

## v0.1-dev1

- First executable cut: safe compiled interpolation, controlled traversal, registered formatters, render policies and no `INTERPRET`.

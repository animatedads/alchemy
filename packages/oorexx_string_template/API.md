# API — ooRexx String Template v0.1-dev3

## StringTemplate

`StringTemplate~new(source [, formatterRegistry])` parses source once and captures a sealed snapshot of the supplied formatter registry.

Public methods include `source`, `segments`, `variables`, `formatterNames`, `requirements`, `formatters`, `missingFormatterNames`, `validateBindings`, `withFormatters(registry)`, `render(context [, policy])`, and `renderTo(sink, context [, policy])`.

`formatters` returns the captured sealed registry. Mutating the registry originally passed by the caller does not change an existing template.

`missingFormatterNames` returns referenced formatter names absent from the captured registry. This is non-executing and allows a caller to inspect a template before domain formatters are supplied.

`validateBindings` fails closed if any referenced formatter is absent. `render` and `renderTo` invoke this validation before resolving context or writing output, so an unbound formatter cannot cause a partial streamed render.

`withFormatters(registry)` returns a new `StringTemplate` over the same source with a new captured formatter snapshot. Existing templates are never rebound in place.

Both render methods accept a `TemplateContext` or `Directory` and use strict/plain policy by default.

## TemplateFormatterRegistry

- `default` — mutable registry containing the built-ins.
- `register(name, formatter)` — register or replace while mutable; fails when sealed.
- `has(name)` / `formatter(name)` — lookup.
- `snapshot` — detached sealed registry containing the current name-to-formatter bindings.
- `seal` — prevent later registration and return self.
- `isSealed` — report seal state.

A snapshot freezes registry membership, not arbitrary internal state of formatter objects.

## Other public surfaces

`TemplateRequirements`, `TemplateContext`, `TemplateObjectView`, `TemplateFormatter`, `TemplateRenderPolicy`, `TemplateParser`, and segment classes retain their dev2 contracts. Requirement inspection remains non-executing. Object traversal remains restricted to `Directory` and explicit `TemplateObjectView` projections.

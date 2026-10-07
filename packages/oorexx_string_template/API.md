# API — ooRexx String Template v0.1-dev1

## StringTemplate

`StringTemplate~new(source [, formatterRegistry])`

Parses and compiles the source once.

- `source` — original source text.
- `segments` — copy of compiled segment array.
- `variables` — unique referenced paths, first-use order.
- `formatters` — formatter registry.
- `render(context [, policy])` — renders from a `TemplateContext` or `Directory`.

## TemplateContext

- `put(name, value)`
- `putObject(name, object, propertyMap)`
- `resolve(path)`

Nested traversal is allowed only through `.Directory` and `.TemplateObjectView`.

## TemplateObjectView

`TemplateObjectView~new(object)` creates an explicit projection over an ooRexx object.

- `allow(propertyName, messageName)` adds a zero-argument getter to the allowlist.
- `property(propertyName)` resolves only allowlisted names.

## TemplateFormatterRegistry

- `default` creates a registry with dev1 built-ins.
- `register(name, formatter)`
- `has(name)`
- `formatter(name)`

A formatter subclasses `TemplateFormatter` and implements `format(value, argument)`.

## TemplateRenderPolicy

Construct with `TemplateRenderPolicy~new(missingMode, escapeMode)`.

Missing modes: `ERROR`, `KEEP`.

Escape modes: `PLAIN`, `HTML`, `JSON`.

Convenience constructors: `strictPlain`, `permissivePlain`, `strictHtml`, `strictJson`.

# API — ooRexx String Template v0.1-dev2

## StringTemplate

`StringTemplate~new(source [, formatterRegistry])`

Parses the source once.

- `source` — original source text.
- `segments` — copy of compiled segment array.
- `variables` — unique referenced paths, first-use order.
- `formatterNames` — unique formatter names, first-use order; plain `${value}` requires `identity`.
- `requirements` — a detached `TemplateRequirements` snapshot.
- `formatters` — formatter registry.
- `render(context [, policy])` — renders to and returns a String.
- `renderTo(sink, context [, policy])` — writes each rendered segment to `sink~charOut(text)` and returns the number of characters submitted. The caller owns sink lifecycle.

Both render methods accept a `TemplateContext` or `Directory` and use strict/plain policy by default.

## TemplateRequirements

A detached inventory produced from the compiled template.

- `variables` — copy of unique variable/path requirements.
- `formatters` — copy of unique formatter-name requirements.

Reading requirements does not resolve context values, invoke object getters or call formatters.

## TemplateContext

- `put(name, value)`
- `putObject(name, object, propertyMap)`
- `resolve(path)`

`put` and `putObject` both reject blank context names. Nested traversal is allowed only through `.Directory` and `.TemplateObjectView`.

## TemplateObjectView

`TemplateObjectView~new(object)` creates an explicit projection over an ooRexx object.

- `allow(propertyName, messageName)` adds a zero-argument getter to the allowlist.
- `property(propertyName)` resolves only allowlisted names.

## TemplateFormatterRegistry

- `default` creates a registry with built-ins.
- `register(name, formatter)`
- `has(name)`
- `formatter(name)`

A formatter subclasses `TemplateFormatter` and implements `format(value, argument)`.

## TemplateRenderPolicy

Construct with `TemplateRenderPolicy~new(missingMode, escapeMode)`.

Missing modes: `ERROR`, `KEEP`.

Escape modes: `PLAIN`, `HTML`, `JSON`.

Convenience constructors: `strictPlain`, `permissivePlain`, `strictHtml`, `strictJson`.

The JSON policy escapes substituted **JSON string content**. It does not construct or validate a complete JSON document.

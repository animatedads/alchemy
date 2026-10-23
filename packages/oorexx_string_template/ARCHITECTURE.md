# Architecture — ooRexx String Template v0.1-dev2

The package deliberately treats template source as data, not executable Rexx.

```text
StringTemplate
   |
   +-- TemplateParser
   |     `-- compiled TemplateSegment objects
   |
   +-- TemplateRequirements
   |     +-- variable/path inventory
   |     `-- formatter inventory
   |
   +-- TemplateContext
   |     +-- Directory values
   |     `-- TemplateObjectView allowlisted projections
   |
   +-- TemplateFormatterRegistry
   |     `-- TemplateFormatter objects
   |
   +-- TemplateRenderPolicy
   |     +-- missing-value policy
   |     `-- escaping policy
   |
   `-- render / renderTo
         +-- String result
         `-- caller-owned charOut sink
```

## Authority boundaries

The template owns parsing, substitution and template-requirement semantics. The caller owns data authority. Domain libraries own domain formatters. Render policy owns output escaping. The caller owns the lifecycle and semantics of a streaming output sink.

No template expression is sent to `INTERPRET`. No object message is derived directly from untrusted template text. `TemplateObjectView` is the only arbitrary-object bridge, and the application explicitly maps public template property names to zero-argument messages.

## Compile-time introspection is observation, not execution

`variables`, `formatterNames` and `requirements` are computed from parsed segments. They do not inspect the caller's object graph, resolve values or run formatter code. This lets a report, message, prompt or document pipeline determine what a template requires before supplying data.

## Streaming output

`renderTo` does not create a second rendering model. Every segment is resolved and escaped through the same objects used by `render`; only the destination differs. The sink is intentionally duck-typed around `charOut` so ordinary ooRexx streams and application-owned sinks can be used without a hard package dependency. StringTemplate never closes or flushes a sink it does not own.

## Why no loops or conditionals

Adding template conditionals, loops, macros or arbitrary expressions would create another programming language. Composition belongs in ordinary ooRexx objects and collections. This package stays a string interpolation facility.

## Object preservation

Values remain ooRexx objects until their selected formatter converts them to textual output. Contexts do not flatten object graphs into JSON or Python-like structures.

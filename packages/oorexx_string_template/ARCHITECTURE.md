# Architecture — ooRexx String Template v0.1-dev1

The package deliberately treats template source as data, not executable Rexx.

```text
StringTemplate
   |
   +-- TemplateParser
   |     `-- compiled TemplateSegment objects
   |
   +-- TemplateContext
   |     +-- Directory values
   |     `-- TemplateObjectView allowlisted projections
   |
   +-- TemplateFormatterRegistry
   |     `-- TemplateFormatter objects
   |
   `-- TemplateRenderPolicy
         +-- missing-value policy
         `-- escaping policy
```

## Authority boundaries

The template owns parsing and substitution semantics. The caller owns data authority. Domain libraries own domain formatters. Render policy owns output escaping.

No template expression is sent to `INTERPRET`. No object message is derived directly from untrusted template text. `TemplateObjectView` is the only arbitrary-object bridge in dev1, and the application explicitly maps public template property names to zero-argument messages.

## Why no loops or conditionals

Adding `{% if %}`, loops, macros or arbitrary expressions would create another programming language. Composition belongs in ordinary ooRexx objects and collections. This package stays a string interpolation facility.

## Object preservation

Values remain ooRexx objects until their selected formatter converts them to textual output. Contexts do not flatten object graphs into JSON or Python-like structures.

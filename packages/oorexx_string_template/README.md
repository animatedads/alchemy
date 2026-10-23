# ooRexx String Template v0.1-dev2

A small, safe, compiled string-template library for ooRexx.

The package fills a practical gap without inventing a second programming language inside Rexx. Template source is parsed once into segment objects and later rendered against an explicit context. Values remain ooRexx objects until a formatter produces text.

```rexx
context = .Directory~of("name", "Fred", "count", 7)
t = .StringTemplate~new("Hello ${name}. You have ${count} messages.")
say t~render(context)
```

Supported syntax remains deliberately small:

- `${name}` — named value.
- `${customer.address.city}` — controlled path traversal through `Directory` and `TemplateObjectView` objects.
- `${name|upper}` — registered formatter.
- `${code|prefix:ID-}` — formatter argument.
- `$${name}` — literal `${name}`.

There are no template expressions, loops, conditionals, macros or implicit method calls.

## dev2

Dev2 adds introspection and large-output support without changing template syntax:

- `formatterNames` returns the unique formatter names in first-use order, including `identity` for unformatted substitutions.
- `requirements` returns a `TemplateRequirements` object containing copies of the variable and formatter inventories.
- `renderTo(sink, context [, policy])` renders segment-by-segment to a caller-supplied object supporting `charOut`. The template does not own, flush or close the sink.
- JSON string-content escaping now covers every control byte from `00`x through `1f`x, using the standard short escapes where applicable and `\u00XX` otherwise.
- `TemplateContext~putObject` now applies the same non-blank context-name rule as `put`.

`render` remains the convenient string-returning API and is semantically equivalent to `renderTo` for the same context and policy.

## Object safety

Ordinary ooRexx objects are not traversed from template text. To expose object properties, the caller wraps an object in `TemplateObjectView` or uses `TemplateContext~putObject`, supplying an explicit property-to-message allowlist.

The template cannot invoke arbitrary methods, provide arguments, or use `INTERPRET`.

## Policies

`TemplateRenderPolicy` separates rendering policy from template syntax. The package supplies strict/permissive missing-value handling and PLAIN, HTML and JSON-string-content escaping.

## Formatters

Built-ins are `identity`, `upper`, `lower`, `trim`, `prefix` and `suffix`. Applications register additional formatter objects by subclassing `TemplateFormatter`; domain libraries therefore remain responsible for domain formatting.

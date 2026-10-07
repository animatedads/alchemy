# ooRexx String Template v0.1-dev1

A small, safe, compiled string-template library for ooRexx.

The package fills a practical gap without inventing a second programming language inside Rexx. Template source is parsed once into immutable-style segment objects and later rendered against an explicit context.

```rexx
context = .Directory~of("name", "Fred", "count", 7)
t = .StringTemplate~new("Hello ${name}. You have ${count} messages.")
say t~render(context)
```

Supported dev1 syntax:

- `${name}` — named value.
- `${customer.address.city}` — controlled path traversal through `Directory` and `TemplateObjectView` objects.
- `${name|upper}` — registered formatter.
- `${code|prefix:ID-}` — formatter argument.
- `$${name}` — literal `${name}`.

`StringTemplate~variables` returns the unique required paths in first-use order.

## Object safety

Ordinary ooRexx objects are not traversed from template text. To expose object properties, the caller wraps an object in `TemplateObjectView` or uses `TemplateContext~putObject`, supplying an explicit property-to-message allowlist.

The template cannot invoke arbitrary methods, provide arguments, or use `INTERPRET`.

## Policies

`TemplateRenderPolicy` separates rendering policy from template syntax. dev1 supplies strict/permissive missing-value handling and PLAIN, HTML and JSON-string-content escaping.

## Formatters

Built-ins are `identity`, `upper`, `lower`, `trim`, `prefix` and `suffix`. Applications register additional formatter objects by subclassing `TemplateFormatter`; domain libraries therefore remain responsible for domain formatting.

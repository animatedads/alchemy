# ooRexx String Template v0.1-dev3

A small, safe, compiled string-template library for ooRexx. Template source is data, never executable Rexx.

```rexx
context = .Directory~of("name", "Fred", "count", 7)
t = .StringTemplate~new("Hello ${name}. You have ${count} messages.")
say t~render(context)
```

Syntax remains deliberately small: `${name}`, controlled dotted paths, one registered formatter with optional argument, and `$${...}` for a literal placeholder. There are no template expressions, loops, conditionals, macros or implicit object method calls.

## dev3

Dev3 makes formatter binding deterministic without breaking compile-time requirement inspection.

A `StringTemplate` captures a sealed snapshot of the supplied `TemplateFormatterRegistry`. Later changes to the caller-owned registry therefore cannot silently change an already-compiled template. The snapshot freezes registry membership; formatter objects themselves remain the formatter authority and may retain deliberate state.

A template may still be parsed before its domain formatters are available. `missingFormatterNames` reports unsatisfied formatter requirements and `requirements` remains non-executing. `validateBindings`, `render` and `renderTo` fail closed when a referenced formatter is not bound. `withFormatters(registry)` creates a new template over the same source with an explicit new binding snapshot.

This preserves the useful dev2 workflow:

```rexx
t = .StringTemplate~new("At ${time|iso}, ${sensor} measured ${value|unit:lux}.")
say t~requirements~formatters~toString("l", ", ")

registry = .TemplateFormatterRegistry~default
registry~register("iso", isoFormatter)
registry~register("unit", unitFormatter)
t = t~withFormatters(registry)
say t~render(context)
```

The template language itself is unchanged from dev2.

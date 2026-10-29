# Security notes

- Template text is never evaluated with `INTERPRET`.
- Template paths cannot call arbitrary methods.
- Ordinary objects require an explicit `TemplateObjectView` property allowlist.
- Formatters are registered by application code, never instantiated from template input.
- Each template captures a sealed snapshot of formatter-name bindings; caller registry mutation cannot silently retarget an existing compiled template.
- Missing formatter bindings may be inspected without execution, but `validateBindings`, `render` and `renderTo` fail closed before rendering when a binding is absent.
- `renderTo` validates formatter bindings before emitting the first segment, avoiding partial output caused by a late unknown formatter.
- `withFormatters` creates a new template; it never mutates an existing template's binding authority.
- The registry snapshot is intentionally shallow: mutable state inside an explicitly supplied formatter remains that formatter's authority.
- Missing values fail closed by default.
- HTML and JSON escaping remain explicit render policies.
- Requirement introspection never resolves values or invokes getters/formatters.
- `renderTo` invokes only the caller-supplied sink's `charOut` method and does not close or flush the sink.

# Security notes

- Template text is never evaluated with `INTERPRET`.
- Template paths cannot call arbitrary methods.
- Ordinary objects require an explicit `TemplateObjectView` property allowlist.
- Formatters are registered by application code, never named into existence by template input.
- Unknown formatters fail closed.
- Missing values fail closed by default.
- `put` and `putObject` reject blank context names.
- HTML and JSON escaping are explicit render policies; plain rendering makes no escaping claim.
- JSON policy escapes all control bytes `00`x..`1f`x in substituted string content, plus quote and backslash. It does not claim to construct or validate a complete JSON document.
- Requirement introspection never resolves values or invokes getters/formatters.
- `renderTo` invokes only the caller-supplied sink's `charOut` method and does not close or flush the sink.

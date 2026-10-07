# Security notes

- Template text is never evaluated with `INTERPRET`.
- Template paths cannot call arbitrary methods.
- Ordinary objects require an explicit `TemplateObjectView` property allowlist.
- Formatters are registered by application code, never named into existence by template input.
- Unknown formatters fail closed.
- Missing values fail closed by default.
- HTML and JSON escaping are explicit render policies; plain rendering makes no escaping claim.
- dev1 JSON policy escapes substituted string content; it does not claim to construct or validate a complete JSON document.

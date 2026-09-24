# ooRexx Parts Research Factory v0.1-dev1

Provider-neutral, validation-first candidate pipeline for Common Parts and Materials.

The factory treats model output as untrusted candidate data. It validates the fixed
`parts.research/0.1` envelope, resolves material IDs supplied by the caller, checks
units/provenance/duplicates, and only then renders deterministic ooRexx source.
Azure, Grok, local models, and offline fixtures can all use the same envelope.

The current qualification authority is Parts v0.1-dev10 and Materials v0.1-dev5.
The built-in ooRexx `JSON` class is used through `json.cls`; no JSON implementation
is vendored here. The default budget is a GBP 70 ceiling with a GBP 68 stop point,
and the acceptance tests consume no provider credit.

This increment is deliberately offline by default. It contains no provider key and
does not make network calls. Use `PartResearchFactory` with a provider callback or
replay a cached response before enabling a paid transport.

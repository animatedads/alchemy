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

The validator includes a bounded normalizer for common model shape drift such as
`candidates[0]`, `partCandidate`, property maps, and material maps. Normalization is
reported as warnings; it does not invent engineering values or permit unresolved
material IDs.

The configured Azure Foundry text route is GPT-4.1-mini, deployment
`parts-research-gpt41-mini`, with GPT-4o reserved for future image or diagram
requests. The planning prices and deployment metadata are kept in
`config/azure-foundry-gpt41-mini.json`; they are estimates, not billing authority.

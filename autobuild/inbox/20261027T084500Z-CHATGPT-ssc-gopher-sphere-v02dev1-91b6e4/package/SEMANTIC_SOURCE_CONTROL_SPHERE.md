# Semantic Source Control Gopher Sphere v0.2-dev1

This sphere teaches an LLM how to operate around ooRexx Semantic Source Control while preserving SSC as the historical/semantic authority.

Core rule: **Gopher/Finder is the bounded operational interface; SSC is the authority.**

v0.2-dev1 closes the read-only adapter gap. `source.semantic.status`, `identify`, `compare`, `impact`, `source`, and `proposals` are published as executable services backed by `semantic.source.control.machine/0.1` through `llm.gopher.ssc.adapter/0.1`. The adapter must obtain an authorised ServiceProxy before invoking the machine protocol.

`source.semantic.accept` and `source.semantic.proposal.decide` remain deliberately non-executable here. Validation, tests, package readiness, or a read result never imply acceptance.

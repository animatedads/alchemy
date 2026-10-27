# LLM Gopher SSC Adapter v0.1-dev1

Companion adapter that makes the read-only Semantic Source Control machine protocol usable through the existing LLM Gopher v0.21 Finder/ServiceProxy authority model without forking Gopher's engine.

`gopher-ssc` passes ordinary commands to the configured Gopher unchanged. For the six `source.semantic.*` read capabilities it first asks Gopher Finder for an authorised service in the requested sphere, then invokes the fixed `semantic.source.control.machine/0.1` command with an argv vector. No arbitrary shell command or `osc` flag surface is exposed.

Supported capabilities: `status`, `identify`, `compare`, `impact`, `source`, and `proposals`. Acceptance and proposal decisions are deliberately absent.

Runtime discovery accepts `LLM_GOPHER_BASE` / `LLM_GOPHER_ROOT` for Gopher and `SSC_MACHINE` / `OOREXX_SEMANTIC_SOURCE_CONTROL_MACHINE_ROOT` for the machine protocol.

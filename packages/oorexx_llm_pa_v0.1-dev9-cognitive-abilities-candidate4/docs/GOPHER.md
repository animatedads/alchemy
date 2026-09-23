# Gemma / LLM Gopher read-only integration

The PA exposes LLM Gopher to Gemma only as project evidence. `LlmPaGopherTool` is declared `READ_ONLY`, `mutating=false`, `eventable=true`, `authority_class=EVIDENCE_ONLY`.

## Routing

`deps/gopher_catalog.tsv` is generated from the exact bundled sphere collection. A user question is scored locally against that catalogue. The selected sphere is activated from the exact known archive; Gopher context supplies valid article ids; the PA locally selects one article and asks Gopher to open only that id. User text is never appended as an arbitrary Gopher command line.

## Exposed behavior

- explicit `gopher` / `gopher_read` command for direct evidence
- fallback grounding for `ask` / `message` when durable memory and local knowledge do not cover a question
- optional grounding for an Alarm-fired PA turn under the same rule
- detached sphere/article summary, invariants and provenance

Not exposed: Gopher exec, source editing, sphere editing, package staging, or any mutating service.

## Authority

Gopher output is documentation/provenance. It does not establish current machine state, grant credentials, approve a tool call, or authorize execution. A model reply that consumed Gopher evidence reports `gopher_used=true`, `gopher_sphere`, and optionally `gopher_article_id`.

## Eventability

`eventable=true` means a future one-shot Alarm may wake Gemma and Gemma may consult Gopher during that fresh PA turn. The Alarm has already ended when it fires. If another future check is needed, Gemma must explicitly arm a new Alarm.

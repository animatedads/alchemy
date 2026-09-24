# API

`PartResearchRequest~new(requestId, task, family, description)` creates a request.
Use `~addProperty`, `~addMaterialRole`, `~addGeometry`, and `~toJSON`.

`PartResearchResponse~fromJSON(text)` parses a provider response.
`PartResearchValidator~validate(response, request, existingPartIds)` returns a
directory containing `OK` and an `ERRORS` array.

`PartResearchGenerator~render(response~candidate)` renders a validated candidate
into deterministic ooRexx source. It never evaluates model-provided source text.

`PartResearchCache~put(key, requestJSON, responseJSON, disposition)` and `~get(key)`
provide a replayable JSON-lines ledger. `PartResearchBudget` is a conservative
fail-closed GBP ledger.

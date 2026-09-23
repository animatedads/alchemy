# Cognitive Continuity MCP tools — dev2-exp1

Protocol target: MCP `2026-07-28`.

The authenticated transport supplies principal identity. No tool accepts actor, authority, origin, epistemic or verification state from the model.

Tools:

- `cognitive.effects.propose`
- `cognitive.records.query`
- `cognitive.continuity.query`
- `cognitive.context.project`
- `cognitive.context.export`
- `cognitive.context.explain`
- `cognitive.classification.explain`
- `cognitive.learning.delta`

`cognitive.context.export` is intentionally the dog-food tool: it reveals the exact model-facing payload and the selection trace used to construct it.

# Dog-food plan: observe exactly what the model is fed

The key experimental surface is `cognitive.context.export`.

It returns:

- `modelInput`: the detached provider-neutral context object;
- `modelInputJson`: the exact JSON serialization suitable for injection into a ChatGPT/Codex turn;
- `projectionTrace`: every considered durable record and why it was included or excluded;
- `projectionId`: an identity usable with `cognitive.context.explain`.

## Experiment

1. Run normal LLMPA/Codex work and write typed effects into a project scope.
2. Export context before a model call.
3. Save both exact model input and projection trace.
4. Give exactly `modelInputJson` to ChatGPT/Codex as one bounded context object.
5. Record the resulting Structured Response/tool episodes.
6. Compare useful/missing/irrelevant context against the trace.
7. Feed classification/projection misses into the hourly learning lane.

A retrieval miss is not forgetting and must not mutate durable cognitive state.

`examples/dogfood_seed.rex` creates a small demonstration corpus. `tools/cognitive_context_export.rex` exports an existing JSONL corpus.

## ChatGPT / Codex via MCP

`optional/CognitiveMcpHttpsRoute.cls` binds the same semantic service to the existing ooRexx HTTPS Server v0.4.4 pattern. `examples/embed_cognitive_mcp.rex` shows composition. A trusted authentication layer must place the verified principal in `request.context['mcp.principal']`; MCP client metadata is never authority.

Expose `/cognitive-mcp`, allow the client to discover tools, then use `cognitive.context.export` before/alongside task execution. The exported `modelInputJson` is the inspectable baseline for what the memory service selected; client-internal system/developer prompt material remains outside this service's authority and observability.

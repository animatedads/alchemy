# ooRexx LLM Personal Assistant candidate9 learning-results

Current qualified LLMPA cognitive-integration head.

Qualified artifact:
- `oorexx_llm_pa_v0.1-dev9-cognitive-abilities-candidate9-learning-results-qualified.zip`
- SHA-256: `86e67d0e1b47265fa6752ac5d9848737b0bd0a4f40bd478a6dfaa9139f7e89da`
- qualification: 37/37 deterministic suites PASS under ooRexx 5.3.0 r13196 in the hostile clean-room gate.

Key behaviour:
- ordinary PA asks consume task-scoped Cognitive Continuity;
- request-correlated reply retrieval avoids FIFO cross-task replies;
- exact model-feed projection receipts are retained as measurement evidence;
- hourly Queue Fabric learning is asynchronous;
- a dedicated `cognitive:learner` actor records validated Qwen learning results as measurement-only evidence;
- model actor cannot record learning results;
- Qwen proposals remain `PROPOSALS_ONLY_NOT_ADMITTED`.

Dependencies:
- Cognitive Continuity v0.1-dev6-exp1
- Cognitive Qwen Space Worker v0.1-dev2 for the nearline Qwen consumer path
- Queue Fabric / API Client / Foreign Runtime / provider stack as recorded by the qualified delivery.

## Direct-main publication

The Architect explicitly authorized a direct `main` update because the normal PC release path was unavailable.

The qualified LLMPA archive contains a multi-megabyte clean-room dependency closure. That vendored closure is intentionally **not** published as source owned by LLMPA. The earlier `oorexx_llm_pa_v0.1-dev9-candidate1` source tree remains historical, not a substitute for candidate9. This directory is the authoritative Git head record for the candidate9 qualified package and its cross-component contracts.

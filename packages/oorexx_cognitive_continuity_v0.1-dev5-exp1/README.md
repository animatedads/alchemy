# ooRexx Cognitive Continuity v0.1-dev5-exp1

## dev4 task-aware projection

- `COGNITIVE.CONTEXT.PROJECT/EXPORT` now applies the supplied `task` instead of treating it as descriptive metadata only.
- Durable records remain stored, but records with no distinctive overlap with the active task are omitted from the inference projection and recorded in the selection trace as `TASK_FILTER_MISMATCH`.
- Each eligible/ineligible trace row carries a deterministic `taskRelevanceScore` for dog-food inspection.
- An explicit broad projection remains available by omitting `task`; continuity rendering can therefore inspect the whole scope without weakening ordinary request isolation.
- Regression coverage reproduces the observed Safety29/QueueRexx cross-task leak and proves the QueueRexx decision is retained but excluded from the Safety29 model feed.


Experimental executable cut of the AI Cognitive Continuity / Memory Fabric v0.5 architecture.

This cut is intended to be **dog-fooded with LLMPA, ChatGPT and Codex**. It focuses on making the cognitive boundary observable before adding expensive ML behaviour.

Implemented:

- typed cognitive proposals instead of generic text memory;
- server-derived origin, epistemic state and decision authority;
- invocation evidence-manifest binding for `basisRefs`;
- append-only JSONL reference journal;
- deterministic baseline multidimensional record classification;
- reason-traced, bounded disposable context projection;
- exact provider-neutral `cognitive.model-context/0.1` export showing what an LLM is fed;
- MCP `2026-07-28` tools using the same semantic service;
- LLMPA native adapter;
- Queue Fabric compatible hourly learning-bundle/request adapter, including projection receipts and outcomes;
- proposal-only `cognitive.learning.result/2` contract for HF/Colab/local/LLM workers;
- separate durable measurement journal for exact feed receipts and model outcome feedback;
- v2 learning bundles combine cognitive corpus deltas with projection-quality evidence without making measurements cognitive authority.

Not yet implemented:

- automatic Observation/Qualification evidence promotion;
- full concept DAG/generalisation engine;
- automatic classifier/generalisation admission from nearline worker proposals;
- learned skill qualification/promotion;
- automatic tool generation;
- the estate's final standalone Structured Response implementation (not identifiable in the supplied API roll-up; see `docs/STRUCTURED_RESPONSE_COMPAT.md`).

The package intentionally keeps remote ML out of the online correctness path.

Run: `./run_tests.sh`

Dog-food demonstration: `rexx examples/dogfood_seed.rex`


## Real dog-food observation lane (dev5)

`COGNITIVE.DOGFOOD.OBSERVE` imports bounded, evidence-bound observations from ChatGPT/Codex runs that occurred outside the instrumented projector. These events live only in the measurement journal and are explicitly non-authoritative. The hourly learning bundle exposes them as `dogfoodObservations` so Qwen can propose classification, projection, lesson, procedure, and tool findings without rewriting the causal history. See `examples/safety29_codex_dogfood.rex`.

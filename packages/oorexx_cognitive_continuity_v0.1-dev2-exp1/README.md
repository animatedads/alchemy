# ooRexx Cognitive Continuity v0.1-dev2-exp1

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
- Queue Fabric compatible hourly learning-delta/request adapter;
- proposal-only `cognitive.learning.result/1` contract for HF/Colab/local/LLM workers.

Not yet implemented:

- automatic Observation/Qualification evidence promotion;
- full concept DAG/generalisation engine;
- real HF/Colab classifier worker;
- learned skill qualification/promotion;
- automatic tool generation;
- the estate's final standalone Structured Response implementation (not identifiable in the supplied API roll-up; see `docs/STRUCTURED_RESPONSE_COMPAT.md`).

The package intentionally keeps remote ML out of the online correctness path.

Run: `./run_tests.sh`

Dog-food demonstration: `rexx examples/dogfood_seed.rex`

# LLM Containment Gopher sphere v0.1

An LLM-focused knowledge sphere for keeping an LLM correct AND contained when it is
wired into a larger system as a live actor, observer, or assistant.

It adds only:
- `packs/llm-containment/` (sphere manifest, access policy, articles, corpus, rules)
- `profiles/llm-containment.json`
- `tests/run_llm_containment_sphere.sh`
- LLM Containment qualification/manifest files

It does not replace `engine/gopher.py`, and it layers `packs/core + packs/llm-containment`.

Start with:

    ./gopher --profile llm-containment context llm-containment
    ./gopher --profile llm-containment help llm-containment --text
    ./gopher --profile llm-containment open llm-containment.boundary.no-private-state-in-prompt --sphere llm-containment
    ./gopher --profile llm-containment search 'unknown token' --sphere llm-containment
    ./gopher --profile llm-containment lookup topic=observer --sphere llm-containment
    ./gopher --profile llm-containment rules check ... --language any

Design discipline: articles and corpus records carry the boundary discipline that
depends on judgement or trust in a contract. A small rule set is included only where a
reliable bounded trigger exists (reserved hidden-state references in emitted prompts,
raw secret material in snapshots/history/logs, mutation-shaped verbs on an observation
stream), mirroring the oorexx-llm-pitfalls no-false-positive rule scope.

Grounding lives in the psychic-poker prompt-boundary audit, the FlyLo/Grok legal-effect
model, and the Observation / Virtual-Browser fail-closed contracts.

Qualification (data-only, no ooRexx runtime required):

    ./tests/run_llm_containment_sphere.sh

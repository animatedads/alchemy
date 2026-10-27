# ooRexx Semantic Source Control Machine Protocol v0.1-dev1

A read-only machine projection over the accepted **Semantic Source Control v0.2.3** engine.

API: \`semantic.source.control.machine/0.1\`.

This package exists so LLM Gopher and other bounded tools can consume SSC without scraping human CLI text and without acquiring acceptance authority. It vendors the exact sealed SSC v0.2.3 implementation for reproducibility; the vendored files are byte-identical to the accepted package and are not an independently modified semantic engine.

## Commands

\`\`\`text
ssc-machine status COMPONENT --repo REPO
ssc-machine identify COMPONENT TARGET --repo REPO [--level N]
ssc-machine compare COMPONENT PATH --repo REPO
ssc-machine impact COMPONENT PATH --repo REPO [--against WORKTREE]
ssc-machine source COMPONENT TARGET --repo REPO [--level N]
ssc-machine proposals --repo REPO
\`\`\`

Every response is one JSON object with schema \`semantic.source.control.machine/0.1\`, \`tool_status\`, \`operation_status\`, \`operation\`, \`result\`, and \`diagnostics\`.

Semantic negative results are successful observations: \`NOT_FOUND\`, \`UNCHANGED\`, \`REVIEW_REQUIRED\`, and \`AMBIGUOUS\` use \`tool_status=OK\`. This is deliberate so Gopher does not fall back merely because SSC found no entity or found a review condition.

## Authority boundary

This cut is read-only. It does **not** expose baseline acceptance, external-operation proposal decisions, repository mutation, export, or arbitrary \`osc\` execution. Those require separate reviewer/admin authority and stale-fenced mutation contracts.

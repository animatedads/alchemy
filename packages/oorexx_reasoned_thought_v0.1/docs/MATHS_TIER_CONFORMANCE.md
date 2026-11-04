# Maths evidence-tier conformance adapter

Architecture: Tom Dyer. Adapter: ChatGPT GPT-6.

This is an **optional cross-pillar conformance seam** between Reasoned Thought and ooRexx Maths v0.20+. It deliberately does not make Maths an epistemic authority.

`MathsEvidenceTierPolicy` represents the currently declared Reasoned Thought ordering

`STYLOMETRIC < TESTIMONY < DOCUMENTARY < PROVENANCE`

through `.MathFiniteChain`. `verifyEvidenceClasses` compares that chain with the ranks currently exported by Claude-owned `.EvidenceClass` and reports drift.

The adapter does not authenticate evidence, admit grounds, decide binding scope, resolve SUPPORT/REBUT/UNDERCUT, choose assertion/settlement floors, or produce belief status. Those remain Reasoned Thought responsibilities. The configured ordering is project policy, not a universal claim about epistemology.

The adapter is optional: the existing `EvidenceCombiner` continues to consume the numeric tier contract and does not require Maths. This avoids turning a cross-pillar consistency check into a deployment dependency before the estate package resolver can guarantee the exact Maths version.

Qualification command once Maths v0.20+ and Reasoned Thought are both on `REXX_PATH`:

```sh
REXX_PATH="/path/reasoned-thought/src:/path/oorexx_maths/rexx" \
  rexx tests/test_maths_tier_policy.rex
```

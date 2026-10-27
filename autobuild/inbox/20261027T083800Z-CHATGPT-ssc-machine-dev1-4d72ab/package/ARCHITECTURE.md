# Architecture

\`ssc-machine\` is a projection, not a second source-control engine.

\`\`\`text
Gopher / bounded caller
        |
        v
semantic.source.control.machine/0.1
        |
        v
exact SSC v0.2.3 objects
        |
        v
SSC repository / accepted history
\`\`\`

The machine layer calls \`SemanticRepository\`, \`OoRexxSourceAnalyzer\`, \`ContractComparator\`, and \`ImpactEngine\` directly. It never parses the human \`osc\` output. Compare/impact reconciliation uses \`reconcileTrackingSet(..., .false)\`, so read-only machine queries do not append tracking proposals.

The exact v0.2.3 semantic engine is vendored solely to make the projection self-contained and deterministic. The vendor is provenance-locked by \`VENDOR_PROVENANCE.txt\` and the package manifest.

Mutation is intentionally absent from v0.1. A future mutation API must bind expected parent source level, repository generation/candidate digest, authority, and exact proposal/candidate identity as appropriate.

# Structured Relation Plugin v0.8 architecture

## Core rule

The rich source/evidence object is authoritative. Relational values, summaries and rule findings are
views over it. Flattening is allowed only at a deliberate consumer boundary.

## Source families

```text
XML native graph ---------\
EDIFACT native graph ------+--> RichProjectionValue --> RichBusinessFact --> HardWorld
X12 native graph ----------+
Git/code evidence graph ---/
```

`RichSourceCore.cls` remains format-neutral: processing events, findings, projected values and business
facts retain their native source objects.

## Git revision truth

```text
GitRepositoryContext
  -> GitCommitContext
       -> AUTHOR GitIdentity
       -> COMMITTER GitIdentity
       -> parent commit identities
       -> GitChangeRef
            -> GitFileRevision (parent blob)
            -> GitFileRevision (successor blob)
            -> GitDiffHunk
                 -> GitDiffLine
                      -> GitSourceSpan
```

Git author, committer and GitHub author/reviewer are intentionally different evidence categories. Source
file identity includes repository path, commit and blob SHA. Diff additions/deletions point to exact
predecessor/successor source spans.

## Semantic code layer

v0.6 places a bounded semantic graph *above* the revision objects rather than replacing them:

```text
GitFileRevision / RemoteSourceFileRevision
           |
           v
CodeSemanticDocument
  -> CodeSymbolRevision
       -> CodeGuardNode
       -> CodeCallNode
       -> CodeReturnNode
       -> CodeValueOrigin
       -> CodeControlFlowGraph
            -> CodeControlFlowEdge
```

The semantic object remains attached to the original blob.  `CodeSemanticChange` connects predecessor and
successor symbol/operation objects; it can therefore answer whether a guard is preserved or absent while
retaining both source revisions.

The current native ooRexx analyser deliberately covers a narrow C/C++ subset rather than hiding a compiler
behind a “magic AST” claim. It recognizes function revisions, parameters, local fixed-size arrays,
`if` guards, selected memory/allocation APIs, returns, sequential CFG edges and simple parameter origins.
Unsupported macros, complex aliases, templates, exceptional flow and arbitrary C++ constructs remain explicit
limitations for rule confidence; v0.7 handles only exact local aliases and derived-expression lineage in its separate flow layer.

## Value/alias/ownership flow layer

v0.7 adds a second bounded enrichment graph above each semantic symbol:

```text
CodeSymbolRevision
   |
   +--> CodeValueFlowGraph
          +--> CodeValueFlowEdge
          |      EXACT_ALIAS
          |      DERIVED_EXPRESSION
          +--> CodeGuardConstraint
          +--> CodeCallFlowFact
```

The graph is intentionally source-bound. Every edge and constraint carries the exact source span/file
revision which created it. Exact aliases are traversable in both directions for identity-equivalence checks;
derived-expression edges are directional lineage only. This prevents `n = len + 1` from inheriting a bound
proved for `len`, while allowing `n = len` to do so.

A guard protects a modelled memory operation only when its constraint dominates the operation, constrains
the exact length value (possibly through exact aliases), and any known numeric upper bound fits the retained
destination extent. This is stronger than v0.6 textual guard comparison and catches changes where a guard
remains visually unchanged but the write length changes semantic lineage.

Ownership reasoning uses the same alias graph. Release via alias and return-via-alias are retained as
positive evidence. Passing an allocation/alias to an unknown call becomes unresolved escape counterevidence,
not an invented ownership-transfer fact.

## Public-forge augmentation

```text
GitHubRepositoryEvidence
  -> GitHubPullRequestEvidence
       -> GitHubClaimEvidence
       -> review evidence
       -> check/CI evidence
       -> CodeChangeEvidence
```

GitHub provides intent/review/CI augmentation, not revision truth. Author claims, measurements, caveats,
review observations and observed CI state keep distinct posture.

`RemoteSourceFileRevision` is used only when a public source snapshot is fetched at an exact revision.
When a remote snapshot supplies a blob SHA, that SHA initially remains a `GIT_BLOB_CLAIMED` assertion.
Only after `verifyBlobIdentity()` computes the canonical Git object identity over the carried bytes and obtains
an exact match does provenance become `GIT_BLOB_BOUND`.  Mismatch and unverifiable states remain explicit.
This prevents a forge/API/parser claim from manufacturing strong revision identity merely by populating a field.

## HardWorld rule direction

```text
revision objects + semantic graph + PR/review evidence
                    |
                    v
             CodeAnalysisFinding
                    |
                    v
             RichBusinessFact
                    |
                    v
            Virtual RYTA / HardWorld
```

A memory rule can distinguish:

- “the code contains memcpy”;
- “the predecessor operation was guarded”;
- “the same guard text is preserved after an API change”;
- “the preserved guard actually constrains the value which reaches the memory length”;
- “the guard is still present but protects a different value”;
- “the guard disappeared in the successor revision”;
- “the allocation is released locally”;
- “the object is returned and ownership appears to transfer”;
- “no release/transfer is visible in the bounded model, but a leak is not proved.”

The rule result carries the semantic nodes, their revision-bound spans, and any PR/review evidence used.

## NoSQL boundary

NoSQLServer remains a consumer boundary. The source-evidence relation exposes ordinary scalar metadata to
SQL while direct provider rows keep the originating rich object. NoSQLServer v0.72 and DB Core v0.36 need
no semantic-code awareness.

## Deliberate v0.7 boundaries

- The native C/C++ analyser is bounded and is not a standards-complete parser/type checker.
- CFG is currently source-sequential plus guard association; full branch/jump/exception modelling comes later.
- Value flow now preserves exact local aliases and derived-expression lineage, but pointer arithmetic, field/global aliasing, phi/SSA joins and full branch-sensitive reaching definitions are not yet solved.
- Ownership flow recognizes local alias release/return and unresolved call escape; callee ownership contracts and whole-program interprocedural ownership are not yet solved.
- Semantic symbol ancestry across major renames/refactors is not yet solved.
- Preprocessor/macro expansion is not yet represented as a separate provenance graph.
- GitHub claims/reviews/checks remain evidence, not automatically trusted truth.
- The selected Bitcoin Core PRs are a public stress corpus, not assertions of exploitable vulnerabilities.

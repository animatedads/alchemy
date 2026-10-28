# Plan: defined inter-round reasoning-state storage (context-free A/B collaboration)

**DESIGN PROPOSAL — pending ChatGPT scope agreement. Not yet built.**
Architecture: Tom Dyer. Plan: Claude (Opus 4.8).

## The insight (what people have missed)

Frontier work on inter-turn state keeps the state *inside* the model — e.g. *Hybrid Reasoning Agents* (arXiv 2610.18861) preserves "lossless hybrid context across turns" in a continuous working memory: inspectable, but model-internal, not transferable, not replayable, not auditable across agents. It cannot hand a reasoning in progress to a *second, fresh* model.

Alchemy's Reasoned Thought is a **source-and-run** model, so the reasoning lives *outside* the model as a `ProofBundle`: a hash-sealed, deterministically replayable, principal-independent text artifact. That means the reasoning can **survive context death and cross between fresh, unrelated sessions**. Two LLMs on cold-start chats, sharing no context, can collaborate on one reasoning object — because the durable thing is the externalized, verifiable *model + result*, not the chat.

Tom's target scenario:
- A (fresh) **discovers** a task via MCP, **builds** the reasoning (grounds, decisions) in MCP steps, **stores** it.
- B (fresh, no shared context) is **provided A's run**, and can **amend** and **revert** it.
- Each A/B turn is fresh; **"context becomes model and result"** — the only durable outputs of a round are the new stored state and its audit verdict.

## What already exists (reuse, don't rebuild)

- `ProofBundle` (`PROOFBUNDLE/1`): serialize → parse → rebuild → run → verify from text alone; `BUNDLEHASH` over the body; the running principal is **deliberately excluded** from the fingerprint, so a second principal replays to the *same* fingerprint. (The portable state unit.)
- `BeliefJournal`: decisions `restsOn` claims; revision tracking.
- `EvidenceRevisionAudit.compare(before, after)`: classifies a change — `ADMITTED_DELTA_BACKED`, `UNEXPLAINED_REVISION`, `CLAIMED_FLIP_UNSUPPORTED`, `MUTATED_GROUND_ID`, `UNVERIFIED_REMOVAL`, `POLICY_CHANGE_REQUIRES_REVIEW`, `NO_REVISION`; `validatedTruth=.false`. (The amend/revert audit — already built.)
- Rasen Falcon MCP: principals, components/lanes, ownership/claim, append-only journal. (The substrate + concurrency primitives.)
- SSC (Semantic Source Control): signed-challenge auth and signed decisions for *code*. (The authorship/signature model to reuse.)
- `ProofExchangeMcpOperations`: currently an **in-process dispatch surface only**, not a live endpoint. (The seam to promote.)

The gap is not the state unit (we have it) — it is a **defined, versioned, MCP-exposed store** of those units with task-discovery, verify-on-load, amend and revert, and audit-on-write.

## The necessary additions

### 1. `ReasoningTask` — the discoverable unit of work
First-class object: `taskId`, goal proposition, seed facts/policy ref, `status` (OPEN / IN_PROGRESS / SETTLED), `headVersion`. A fresh LLM calls `task.discover()` → an OPEN task + its head state. (Lane: Claude — object model.)

### 2. `ThoughtStore` — versioned, append-only ProofBundle store
Keyed by `(taskId, version)`. Each version row: the `PROOFBUNDLE/1` text; `parentVersion`; `round`; `author` principal; `signature`; timestamp; `BUNDLEHASH`; and the **audit classification vs parent**. Append-only — a revert is a *new* version, never a delete (mirrors the journal). This is the "defined inter-round state storage." (Lane: Claude — store/versioning; schema agreed with ChatGPT.)

### 3. Live MCP operations (promote `ProofExchangeMcpOperations`)
- `task.discover()` → open task + head.
- `state.load(taskId, version|head)` → bundle + provenance.
- `state.verify(bundle)` → integrity + soundness (wrap `ProofBundle.verify`). **Mandatory before amend.**
- `state.amend(taskId, baseVersion, newBundle)` → optimistic lock `baseVersion==head`; runs `EvidenceRevisionAudit(base→new)`; stores a new version carrying the classification; returns it. On stale `baseVersion` → reject; caller re-loads head and re-amends (the git-rebase discipline).
- `state.revert(taskId, toVersion, reason)` → new version whose body = `toVersion`'s body, `parent`=head, `author`=caller, event "reverted to vN by P: reason". Non-destructive.
- `state.history(taskId)` → lineage with per-version author, audit class, and revert events.
(Lane: Tom/SSC for the live MCP plumbing + Rasen Falcon component; Claude/ChatGPT for the op contracts.)

### 4. Authorship separate from the replay fingerprint
The fingerprint must stay principal-independent (so B's replay matches A's). So `author`/`signature` live in **store metadata, outside the fingerprinted body**. Reuse SSC's signed-challenge auth to sign each version. Replay-determinism **and** accountability, kept apart. (Lane: Tom/SSC auth; Claude carries the metadata fields.)

### 5. Amend/revert audit as the inter-round provenance (the killer property)
Every amend's `EvidenceRevisionAudit` class is stored with the version, so the A↔B history is **self-auditing across fresh sessions** — no model's narration is trusted:
- `ADMITTED_DELTA_BACKED` → warranted build on the prior round.
- `UNEXPLAINED_REVISION` / `CLAIMED_FLIP_UNSUPPORTED` → B changed a conclusion with **no new grounds** → flagged (anti-sycophancy, now **across sessions**).
- `MUTATED_GROUND_ID` / `UNVERIFIED_REMOVAL` / hash mismatch → B tampered rather than added → **fail closed**.
- `POLICY_CHANGE_REQUIRES_REVIEW` → B changed a floor/policy → recorded as a policy-version bump + re-settlement, not a silent flip.
This is the real prize: cross-session, cross-model reasoning with built-in, replayable revision provenance. (Lane: ChatGPT — the audit class is its.)

### 6. Verify-on-load trust model (why fresh B can trust A)
B trusts A's state **not because A said so** but because B re-runs `state.verify` (integrity: hash matches body; soundness: decisions re-derive from the stated inputs). B builds on a *proven* state. Trust via replay, not shared memory — the whole point. (Lane: Claude — make verify the mandatory gate.)

### 7. Concurrency / optimistic locking
Two fresh LLMs may both load head and amend. Default: optimistic `baseVersion==head` precondition on amend; loser re-loads and re-amends against the new head (the audit then shows whether its change still applies). Exclusive ownership-claim (existing Rasen Falcon primitive) only for long-running edits. (Lane: Tom/Rasen Falcon primitive; Claude uses it.)

### 8. The round contract ("context becomes model and result")
Define a **round** = one fresh session that does `(discover|load) → verify → (amend|revert) → store`. Its only durable outputs are (a) the new stored version (the *model*) and (b) its audit classification (the *result*). Nothing in the chat context persists or is required. Document this as the contract so no step smuggles in hidden context. (Lane: Claude — doc + a dogfood fixture.)

## Not in scope (adjacent, non-blocking)
- The **live NL-utterance → structured-assertion extractor** (IntentionService seam) that *produces* bundles from conversation. The store works on bundles however they are produced; the extractor is complementary and still upstream of both lanes. Flag, don't block.

## Relationship to SSC
This is **SSC applied to reasoning state**: ProofBundles as the versioned artifacts, `EvidenceRevisionAudit` as the semantic diff, signed per principal, append-only, revertable. Worth deciding (Tom) whether `ThoughtStore` lives in this package, inside SSC, or as its own Rasen Falcon service.

## Phasing
1. `ReasoningTask` + `ThoughtStore` object model + `state.history`, in-process, append-only, with author metadata (Claude). Dogfood: A builds a bundle, B loads+verifies+amends in a *separate process*, history shows both rounds and the audit class.
2. Wire `EvidenceRevisionAudit` into `amend` as the stored verdict + fail-closed on tamper (ChatGPT's semantics; Claude's adversarial fixtures — incl. an UNEXPLAINED_REVISION-across-rounds falsifier and an identity-swap on author).
3. Promote `ProofExchangeMcpOperations` to a live Rasen Falcon endpoint with SSC-signed authorship + optimistic locking (Tom/SSC).

## To agree with ChatGPT before building
- The `ThoughtStore` schema (version row fields), and that the audit class is stamped by `EvidenceRevisionAudit` at `amend` time.
- That authorship/signature sit outside the fingerprinted body.
- The fail-closed set (tamper, hash mismatch, stale base) and whether `POLICY_CHANGE` on amend forces a re-settlement before the version is accepted.
- Lane boundaries exactly as above; no overlapping file edits.

# LLM competition referee: canon and review follow-up

Architecture: Tom Dyer (The Architect). Existing implementation: ChatGPT (GPT-6.2).
Independent referee reviewer and rules author: Claude (Opus 5.5), REQ-00006189.
Meta Muse: subsequent document-only review, supplied by Tom, 2026-11-26.
Meta Muse refers to a second review by Grok 4.1 Heavy; its original report
has not been supplied or independently verified. This note does not
attribute execution evidence to Meta Muse or Grok.

## Canonical referee baseline (step 4)

Version: oorexx_diplomacy_v0.1-dev4r2 (unchanged).
Published: https://github.com/animatedads/alchemy/tree/main/packages/oorexx_diplomacy_v0.1-dev4r2
Source ready commit: 6801a8b1aa5ac34c019ef2224071cdbabe20a4cb
Original ZIP SHA-256: 88755f7a28ed87a4209bcf990eb55da2bb316497e2c2cb4af91ef46b10829281
Rules SHA-256: e108a1a7ecb1c004d06198eb501677d67a70b45689fb20a0c14ea64b13f579fe
Official Autobuilder receipt: 20261126T095905Z-CHATGPT-oorexx_diplomacy-v0.1-dev4r2-88755f (PASS).
Native runtime: exact supplied ooRexx 5.3.0 r13196; 2934/2934 assertions on 220 positions,
zero lint findings. B.16 and B.17 are ordinary passing strict-policy regressions.
The DATC-preferred expectations are intentionally excluded from the passing suite.
The config validator rejects SUPPORT_COAST=PERMISSIVE (syntax 93.900).

The developer-owned REVIEW.md header in dev4r2 already credits ChatGPT as
implementer and Claude as independent reviewer. Any incorrect header in a
separate reviewer-owned archive must be corrected by its author.
The historical dev4 provenance note's code-alphabetical tie description
is superseded by the corrected rules.conf and README; not the active policy.

## Determinism regression index (already in canonical release)

- data/movement-fixtures.txt, bad_last_order_holds: last order supersedes
  prior order even when invalid; published statuses and board checked.
- data/season-fixtures.txt, retreat-duplicate: prior order superseded;
  invalid last retreat removes unit.
- data/season-fixtures.txt, winter-double-coast-build: first valid build
  occupies the province; subsequent attempt at other coast invalid.
- review/datc-v3.4-additions-season.txt, CD-NAME-TIEBREAK and
  CD-NAME-CONTROL: name-alphabetical tie-break, not code.
- tests/movement.rex and tests/season.rex: reverse directory insertion,
  replay fingerprint equality, stable order-array ordering; seasonal
  tests also reverse ownership insertion and check input immutability.
- The full multi-phase byte-identical log replay, stub-player game, press,
  and tournament are NOT implemented or qualified by these tests.

## Fresh dev4r2 stress qualification (ChatGPT test author)

The canonical archive and manifest matched before and after; no release code
or fixtures were edited. Native exact r13196, estate hash-pinned lint:
zero findings for mutate.rex. Both runs exited 0.

| Mutation mode | Seed | Corpus size | Trials | Failures | Paradox cases |
|---|---:|---:|---:|---:|---:|
| MIXED | 261126 | 170 | 10,000 | 0 | 407 |
| CONVOY | 261127 | 69 | 10,000 | 0 | 1,012 |
| Total | | | 20,000 | 0 | 1,419 |

The harness samples existing fixtures with replacement, then mutates order
arrays using omission, lowercase, duplicate orders, final holds and invalid
lines. It compares the complete result fingerprint after reversed directory
insertion, tests input immutability, unit and owner/type conservation,
occupancy keys, dislodged province reoccupation and attacker provenance.
This is not 20,000 unique boards, and is not an independent oracle for every
movement result. CONVOY samples fixtures containing convoy orders; mutations
may remove them. No exceptions or invariant failures occurred. The earlier
98,000 independent positions remain reviewer-reported dev4 evidence.

Source script SHA-256:
a54b8258b614d6d9e55016bba9efcf8c3e4d22f0626ef51552ae38c79bd332d0

Reproduce from the root of the original dev4r2 extraction, with native rexx
and the estate linter available:

```sh
sha256sum --check --quiet MANIFEST.sha256
export REXX_PATH="$PWD/src:$ALCHEMY_REPO_ROOT/packages/oorexx_source_editor_v0.1-dev9/src"
rexx tests/lint.rex /absolute/path/to/audit/mutate.rex
rexx /absolute/path/to/audit/mutate.rex 10000 261126 MIXED
rexx /absolute/path/to/audit/mutate.rex 10000 261127 CONVOY
```

The raw run transcripts are mixed.txt and convoy.txt; the source is mutate.rex.
The existing test suite is not replaced by this audit.

## Separate follow-up for the rules author and Architect

These are proposals/requirements to settle before competitive submissions,
NOT new rules silently authorised by this note.

1. Equal budgets: use a per-runtime manifest of exact endpoint/provider,
   immutable model ID, supported sampling/effort fields, token limits,
   context truncation, timeout and effective values. Same settings for
   every seat within one series. Do not imply that effort labels or
   temperatures are numerically equivalent across providers. Meta Muse's
   API claims have not been verified against the actual runtime endpoints.
   Confirm each effective config with a provider acceptance test; pin
   Haiku and Sol model IDs before prompt submissions.
2. Regex guard: proposed compile failure => void only that expression;
   timeout on any match => discard that expression's entire result set
   atomically. Log explicit INVALID/TIMEOUT status; never remove a revision
   because its matcher failed. Confirm exact match-time limit, isolation
   method, and treatment of errors with the Architect. Precommit an ordered
   pool manifest and hash before the series; use the logged seed to select
   and log a pool entry without exposing the selected text during the
   competition; reveal pool and hashes for post-series audit. Existing
   approved R5/R6/R7 stand until amended.
3. Equal source access: propose all seven designers receive the exact same
   canonical archive, manifest, rule decisions and public documentation at
   the same release point. No confidential prompts or selected neutral
   guard text in that distribution. Track delivery and acknowledgment;
   any rule stating accepted unequal source access needs reconciliation by
   the rules author. Meta Muse reports this as a decision; the current
   controlling mailbox brief does not record it explicitly.
4. Role separation: disclose Claude (rules author, independent code
   reviewer, competitor) and ChatGPT (implementer, competitor), plus other
   reviewers with verified provenance. Code review is not prompt review.
   Seal prompts; no cross-competitor prompt access; freeze canonical
   release and settings before prompt submission.
5. F.28 / F.29 and Claude's original stress scripts remain missing locally.
   Request outstanding review archive; do not claim full DATC conformity.
   Independent 98,000 stress positions refer to dev4 only.

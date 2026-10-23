# Changelog

## v0.2.3 — 2026-08-26

FederationBank level-7 relocation and legacy-adoption hardening. Semantic source level **5**.

- Replaced candidate-by-candidate cross-method relocation with global one-to-one reconciliation across the whole current candidate set and the immediately previous accepted external-operation set.
- Existing current call-sites retain their accepted identities first; a new same-table SQL operation cannot steal an identity whose historical operation still exists. Same SQL operation/source is supporting compatibility evidence, not identity proof.
- Added the Federation-shaped one-to-many regression: a two-operation transfer extraction remains tracked, while a later release retaining those operations and adding five same-surface FX/offline operations yields exactly two tracked and five pending proposals.
- Added batched contextual MD5 execution. Context-line and statement fingerprints remain MD5 as designed, but normal tree analysis invokes `md5sum` once for a proposal-heavy batch rather than per candidate.
- Added a compact historical identity loader for baseline/scan. It parses persisted `C/M/A/N/P/E` rows directly and avoids full legacy source-blob re-analysis when only identity continuity is required. Full semantic reconstruction remains available to impact/source/export.
- Preserved legacy accepted-level immutability as an evidence-subset rule: every file an old snapshot knew about must still match byte-for-byte; newly visible whole-release files may enrich later levels without rewriting the historical level.
- Normalized the old one-line `method;` parser defect only inside the derived legacy identity view; persisted historical rows are not rewritten.
- On the genuine historical FederationBank level-6 repository, exact sealed-v0.6 re-baseline completes in about 13.7 seconds and leaves the level-6 snapshot hash unchanged; adopting the same source as a synthetic next level completes in about 14.5 seconds.

## v0.2.2 — 2026-08-25

Terminal Machine dogfood hardening. Semantic source level **4**.

- Added first-class ooRexx `::attribute` semantic entities. Getter/setter availability is an API contract; `GET -> SET` and other capability removals produce `ATTRIBUTE_ACCESS_CHANGED [MAY_BREAK]`, while additive accessor expansion is low-risk.
- Modelled explicit `::attribute ... get` / `set` method bodies. Separate getter/setter implementation hashes produce `ATTRIBUTE_GETTER_IMPLEMENTATION_CHANGED` / `ATTRIBUTE_SETTER_IMPLEMENTATION_CHANGED [VERIFY]` without pretending attributes are ordinary `::method` entities. Paired getter/setter directives aggregate into one conceptual attribute entity.
- Added first-class `::constant` semantic entities. Value changes produce `CONSTANT_VALUE_CHANGED`; API/protocol/release/version/schema/format/magic identity constants are automatically elevated to high-risk verification.
- Extended use evidence so attribute message assignment can distinguish a leading `obj~attr = value` setter send (`attr=`) from getter use in an expression such as `if obj~attr = value`. Constant class-literal consumers participate in normal receiver-aware impact analysis.
- Added snapshot schema v4 records for attributes/constants. Pre-v0.2.2 repositories are re-indexed from immutable historical source blobs in memory, preserving accepted source levels and avoiding analyzer-upgrade false deltas.
- Preserved byte-identical accepted-level no-op semantics across repository schema upgrades: rebuildable semantic index rows do not make unchanged release evidence look like an immutable-source violation.
- Replaced per-entity SHA-256 process creation during tree analysis with a two-pass batch hash warm-up. Unique entity payloads are collected, hashed by one `sha256sum` batch for ordinary project sizes, then consumed from an in-memory cache during the real semantic pass. Isolated `contentHash()` calls retain a fallback path.
- Added a 1,200-method hash-scaling regression that asserts the analyzer uses one SHA-256 process for the whole tree. On the r13196 debug host it completes in about six seconds versus roughly fourteen seconds for the same synthetic corpus under v0.2.1.
- Added the exact Terminal Machine constant/attribute reproducer and custom accessor-body regressions to the packaged suite.

## v0.2.1 — 2026-08-25

Immediate FederationBank fee-round dogfood repair. Semantic source level **3**.

- Fixed package-level Rexx `CALL` statements being misclassified as SQL `CALL` merely because the statement mentioned variables such as `sql` or `proc`. The real FederationBank v0.6 tree fell from 101 external-operation candidates to the expected 18 independently significant banking SQL candidates.
- Preserved genuine stored-procedure SQL `CALL` detection when `CALL ...` is visibly carried as SQL text (or appears under `EXEC SQL`), while text-inspection idioms such as `sql~pos(...)` remain ordinary Rexx evidence.
- Added semantic relocation reconciliation for accepted external operations. An independently tracked SQL operation can move to another method in the same owning class and retain its external identity when operation kind plus data source identify one unique accepted operation. Ambiguous relocation deliberately creates a new proposal rather than guessing.
- Fixed `baseline` / `scan` pending-proposal reporting to use the same contextual/semantic tracking resolution as the analyzer. A changed-but-already-tracked SQL operation no longer appears as falsely pending merely because its proposal hash changed.
- Added FederationBank regressions for SQL-call noise, method extraction, external-ID retention and CLI pending-count consistency.
- Replayed the real FederationBank v0.5 -> v0.6 fee transition using only the original 18 level-5 accepted SQL decisions: v0.6 resolves to 18 candidates, 18 tracked operations, zero pending proposals, and the three transfer writes retain their original external IDs after extraction into `commitTransferPostings`.

## v0.2 — 2026-08-25

Dogfood hardening from IBM 4361 and FederationBank acceptance.

- Fixed valid one-line ooRexx methods such as `::method cylinder; expose cyl; return cyl`:
  - method identity stops at the first Rexx statement separator;
  - inline executable statements participate in body hashing and semantic analysis;
  - historical `osc source` lookup uses the real method name rather than `cylinder;`.
- Added first-class ooRexx package semantic revisions:
  - `::options` changes emit `PACKAGE_OPTIONS_CHANGED` (`HIGH`);
  - `::requires` additions/removals emit `SOURCE_REQUIREMENT_ADDED` / `SOURCE_REQUIREMENT_REMOVED`;
  - package identity is anchored to its first OO symbol where possible, not the file path.
- Added receiver-aware message-use evidence:
  - `.ClassName~new(...)` becomes an explicit dependency on `ClassName.init`;
  - class-literal sends, `self` sends, `:super` sends and dynamic receiver sends are distinct evidence kinds;
  - unrelated `self~init:super` sites no longer masquerade as consumers of every changed `init` method;
  - unknown receiver type remains conservative `VERIFICATION_REQUIRED` evidence rather than a claimed exact dependency.
- Added package-level executable code analysis, so top-level `.rex` tests and launchers contribute constructor/message and external-operation dependencies.
- Expanded the immutable blob snapshot from `.cls`/`.rex` only to **all files in the release tree**. Semantic parsing remains ooRexx-specific, but SQL schemas, READMEs, architecture files, manifests and test runners are retained/exported byte-for-byte as release evidence.
- Fixed embedded SQL canonicalisation so host ooRexx delimiters such as `")` do not contaminate predicate contracts.
- Removed the FederationBank-scale identical-baseline performance trap:
  - `SSCUtil.join` now uses `MutableBuffer` rather than repeated immutable-string concatenation;
  - accepted snapshot equality is linear array comparison rather than construction of two giant joined strings;
  - contextual MD5 windows are calculated only for actual external-operation candidates;
  - existing content-addressed blobs are checked by existence rather than rereading their entire contents.
- Added a comment-aware ooRexx lexical pass for structural analysis. `/* ... */` block comments (including nested comments) and `--` line comments can no longer manufacture fake `::class`, `::method`, `::options`, `::requires`, SQL, or command surfaces. Physical line numbering remains stable for evidence.
- Made method side part of semantic identity:
  - instance `Class.message` retains the v0.1 key for repository compatibility;
  - class-side methods use `Class.message#CLASS`;
  - live runtime trial methods have the reserved `Class.message#OBJECT` semantic side;
  - class and instance methods with the same message name no longer collide;
  - constructor edges target instance `init`, while class-literal sends target class-side methods.
- Added explicit `#CLASS` selectors to `osc source` / `osc consumers`; an unqualified method selector remains instance-side by default.
- Added v0.1 semantic re-indexing from immutable historical source blobs. Old accepted source bytes and source levels are never rewritten; v0.2 derives its richer package/use view in memory so analyzer upgrades do not appear as application changes. Existing proposal/decision ledgers are then re-applied.
- Added v0.2 regression suites for the IBM 4361 and FederationBank findings, including a ~4,300-record identical-baseline stress case.
- Preserved read compatibility with v0.1 repositories. Existing accepted source levels remain immutable; v0.2 can use them as baselines without migration.

## v0.1 — 2026-08-25

- Initial object-centric source snapshots with stable class/method identities and content-derived revision IDs.
- Whole-number, lineage-scoped `AT_LEAST` source requirements.
- Class and method contract/implementation semantic deltas.
- Recursive ZIP-in-ZIP intake and exact downstream impact locations.
- Proposal-driven independently tracked SQL/CLI external operations with MD5 contextual fingerprints.
- SQL projection/source/write/predicate semantics and declared data-lineage/result-ordinal impact.
- Immutable source levels, append-only tracking decisions, SHA-256 source blobs, export and historical method reconstruction.

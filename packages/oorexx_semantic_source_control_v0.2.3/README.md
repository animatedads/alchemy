# ooRexx Semantic Source Control v0.2.3

`oorexx_semantic_source_control_v0.2.3` is an object-centric source repository and impact engine for ooRexx.

It is deliberately **not a Git-shaped repository**. Files and ZIP archives are intake/export carriers and lossless evidence. The primary model is software entities and the contracts between them: classes, methods, source revisions, `AT_LEAST` requirements, message-use evidence, data-lineage evidence, and independently tracked external operations.


## v0.2.3 Federation level-7 repair

FederationBank exposed a genuine identity error in v0.2.2: cross-method SQL relocation could consume an old accepted identity merely because a new operation had the same SQL kind and data source. That works for a one-to-one method extraction, but fails when a later release legitimately adds FX and offline-ATM postings to the same banking tables.

v0.2.3 makes relocation a **whole-set, one-to-one historical reconciliation**. The immediately previous accepted call-site is strongest evidence. Cross-method relocation is allowed only when one remaining candidate and one remaining accepted identity are each other's sole compatible partner. The same table/source is supporting evidence, never permission to reuse an identity. A Federation-shaped regression now proves `2 moved -> 2 tracked`, followed by `2 continuing + 5 new -> 2 tracked + 5 pending`.

Legacy adoption is also separated from full semantic reconstruction. `baseline` / `scan` load a compact historical identity view directly from persisted class/method/attribute/constant/candidate rows; they do not re-analyze old source blobs merely to preserve identity. Old accepted levels therefore remain immutable while newer analyzers can enrich future release evidence. On the genuine historical Federation level-6 repository, an exact v0.6 re-baseline completes in about 14 seconds and leaves the old `snapshot.osc` SHA-256 unchanged.

Context MD5 collection is now batched just like SHA-256. The packaged SQL-scale regression asserts one `md5sum` invocation for 200 independently detected SQL candidates.

The product release label is v0.2.3; its semantic `SSC_MANIFEST` source level is **5**.

## v0.2.2 Terminal Machine repair

Terminal Machine exposed two source surfaces that were still invisible to the semantic graph: `::attribute` and `::constant`. v0.2.2 makes both first-class. An attribute is modelled as an OO property contract with separate getter/setter capability and implementation evidence; it is **not** flattened into an ordinary method. Explicit accessor bodies are retained semantically, so changing the body of `::attribute value get` is a verification event even when the accessor contract stays stable.

Constants are independently versioned source surfaces. A constant value change is at least `VERIFY`; constants whose names identify API/protocol/release/version/schema/format/magic surfaces are elevated to high-risk verification. Literal class consumers such as `.TerminalProtocol~API_VERSION` participate in receiver-aware impact analysis.

The same dogfood run exposed the cost of launching `sha256sum` for every method body/contract/entity seed. Tree analysis now performs a semantic warm-up pass, batches every unique SHA-256 payload, invokes SHA-256 once for ordinary project-sized batches, and runs the real analysis from the resulting cache. Repository identity remains SHA-256; this is an execution change, not a digest change.

The product release label is v0.2.2; its semantic `SSC_MANIFEST` source level is **4**, preserving whole-number `AT_LEAST` semantics.

Terminal-specific replay evidence is recorded in `VALIDATION_TERMINAL.txt`.

## v0.2.1 Federation fee-round repair

The first v0.2 FederationBank scan found a useful language ambiguity immediately: top-level Rexx test statements such as `call assert sql~pos(...)` were being proposed as SQL `CALL` operations because the classifier saw both `CALL` and the token `SQL`. v0.2.1 separates the Rexx `CALL` instruction from SQL stored-procedure `CALL` syntax. On the real v0.6 bank tree the candidate set is now exactly the 18 real banking SQL boundaries rather than 101 noisy candidates.

The same dogfood run also tightened external-operation identity. Accepted SQL identity is no longer permanently coupled to the containing method. If refactoring extracts an operation into another method of the same owning class, the repository can retain the existing external ID when kind, operation and data source identify exactly one accepted operation. If more than one old operation could match, no automatic move occurs: a fresh proposal is required.

`baseline` and `scan` now use this resolved tracking state when reporting pending proposals, so contextual evolution that already maps to an accepted external operation is not falsely shown as pending.

The product release label is v0.2.1; its semantic `SSC_MANIFEST` source level is **3**, preserving whole-number `AT_LEAST` semantics.

## Dogfood repairs in v0.2

v0.2 is the first hardening cut driven by two unrelated real consumers: the IBM 4361 emulator and the FederationBank multi-application demo. Their findings changed the semantic model rather than adding filename-specific exceptions.

The repaired surfaces are:

- valid one-line ooRexx directives such as `::method cylinder; expose cyl; return cyl` are parsed as method `cylinder`, and the inline executable statements participate in body hashing and dependency/external-operation analysis;
- package directives are first-class contracts: `::options` and `::requires` changes become semantic deltas even when every method body is unchanged;
- message-use evidence retains receiver meaning, so `.Class~new(...)` depends on `Class.init`, `self~init:super` remains a super-send rather than a global `init` consumer, and unknown receiver types remain conservative evidence;
- executable package-level code in `.rex` files is analyzed, so launchers and regression scripts contribute constructor/message dependencies;
- accepted source levels retain **every file in the release tree** as immutable blob evidence, while semantic parsing remains type-specific; SQL schemas, READMEs, manifests and test runners therefore survive byte-exact export;
- SQL host-language delimiters are removed before canonical predicate comparison; and
- large identical re-baselines are linear rather than quadratic. A synthetic ~4,300-use FederationBank-shaped regression re-baselines in seconds under the debug r13196 interpreter.

The repository format remains read-compatible with v0.1. Existing accepted source levels do not need to be rewritten to benefit from the v0.2 analyzer.

## What the current analyzer proves

One command can recursively inspect ZIPs inside a roll-up ZIP, compare recognised components with accepted source levels, and report semantic changes specifically where they intersect a working source tree:

```sh
bin/osc impact incoming-rollup.zip --repo .osc --against ./my-work
```

The report distinguishes, among other things:

- class/inheritance directive changes;
- method additions/removals;
- method argument/scope/visibility contract changes;
- implementation-only method changes;
- attribute access-contract and explicit getter/setter implementation changes;
- constant value changes, with API/protocol identity constants elevated for verification;
- unsatisfied `AT_LEAST` source requirements;
- unknown legacy source levels that require verification;
- independently tracked SQL projection/order/source/predicate/write changes;
- positional SQL result consumers;
- declared data-lineage consumers;
- independently tracked `ADDRESS SYSTEM` / `ADDRESS COMMAND` call-sites.

## Source level semantics: `AT_LEAST`

A source consumer declares the minimum source level it is known to require:

```rexx
-- @source-requires DataStore.AccountStore.loadAccounts AT_LEAST 7
```

`sourceLevel` is a monotonically meaningful whole number **inside a source lineage**. It is not inferred from `v0.24`, `1.2.3`, timestamps, filenames, or ZIP names.

An authoritative package can carry:

```text
SSC_MANIFEST

component=DataStore
lineage=MAIN
sourceLevel=12
```

A legacy filename such as `DataStore_v999.zip` is useful for recognising the component name, but its `v999` is never silently interpreted as `AT_LEAST 999`. If a consumer has a known minimum and the incoming archive has no authoritative `sourceLevel`, impact reports `VERIFICATION_REQUIRED`.

Passing `AT_LEAST` does **not** imply compatibility. It means only that the known minimum is satisfied. A changed required contract still yields `MAY_BREAK`.

Different source lineages are not numerically comparable. An incoming lineage change is a `SOURCE_LINEAGE_CHANGED` high-risk semantic delta.

## Embedded/external operation tracking is proposal-driven

Detection does not silently redefine the source model.

When the analyzer sees a likely independently significant operation, for example:

```rexx
sql = "SELECT account_id, name, balance FROM account WHERE customer_id = ?"
```

it records a proposal:

```sh
bin/osc proposals --repo .osc
bin/osc proposal show TP-... --repo .osc
```

A proposal records:

- containing method identity;
- candidate kind and operation;
- MD5 of the normalized embedded statement;
- an ordered window of MD5 hashes for normalized lines above it;
- an ordered window of MD5 hashes for normalized lines below it;
- semantic contract;
- source location and confidence.

The contextual fingerprint is intentionally not a line number and not merely one adjacent line. The default context window is four method-local lines in each direction where available.

The reviewer decides:

```sh
bin/osc proposal accept TP-... --repo .osc --reason production SQL result shape matters
```

or:

```sh
bin/osc proposal reject TP-... --repo .osc --reason documentation example only
```

A rejection is durable repository knowledge: the exact candidate is deliberately not independently tracked. If the embedded operation later changes materially, its statement identity changes and it is proposed again. Accepted call-sites survive statement edits and modest relocation by contextual matching and become stable `EO-...` entities.

Decisions are append-only. A later opposite decision supersedes the previous decision without erasing it.

## SQL contracts and downstream impact

Tracked SQL currently records:

```text
operation
sources
projection/order
write columns
predicate
```

For example, changing:

```sql
SELECT account_id, name, balance FROM account ...
```

to:

```sql
SELECT account_id, balance, name FROM account ...
```

produces `SQL_PROJECTION_OR_ORDER_CHANGED`.

A positional result consumer can explicitly retain why this matters:

```rexx
-- @source-result-ordinal DataStore.AccountStore.loadAccounts 2 NAME
-- @source-result-ordinal DataStore.AccountStore.loadAccounts 3 BALANCE
```

The impact report then identifies those exact lines as `MAY_BREAK_HIGH`.

Data lineage can be declared independently:

```rexx
-- @source-data READ ACCOUNT
-- @source-data WRITE ACCOUNT
```

A tracked `UPDATE`, `INSERT`, `DELETE`, operation-class change, write-column change, data-source change, or mutating predicate-scope change can propagate `MAY_BREAK_HIGH` to known consumers of the affected data source.

Dynamic/unrecognised semantics are not silently treated as safe. v0.2 only gives structured SQL deltas where its bounded SQL model can support them.

## Source is losslessly reconstructible

Semantic entities are primary, but source bytes must not be lost.

Accepted source files are retained in a content-addressed SHA-256 blob store:

```text
repo/
  blobs/sha256/ab/abcdef...
  components/
    DataStore/
      levels/
        1/snapshot.osc
      LATEST
  proposals.osc
  decisions.osc
```

The snapshot contains semantic entity revisions and pointers to immutable file blobs. Paths therefore remain supporting evidence/export information rather than the identity of a method or class.

Export an accepted source level:

```sh
bin/osc export DataStore --repo .osc --level 1 --to /tmp/datastore-1
```

The test suite verifies byte-for-byte reproduction of the fixture source.

Retrieve one historical method directly:

```sh
bin/osc source DataStore.AccountStore.loadAccounts --repo .osc --level 1
```

Method side is semantic identity. Instance-side methods preserve the historical selector; class-side methods are explicit:

```sh
bin/osc source DataStore.AccountStore.open#CLASS --repo .osc --level 1
```

`#OBJECT` is reserved for receiver-specific live trial implementations installed into a running object. Those runtime trial revisions belong in the future code-epoch layer rather than in a persisted source-file snapshot. This keeps a live `setMethod(..., "OBJECT")` implementation distinct from both the instance and class source surfaces.

This is the seam intended for live-patch/code-epoch integration.

## Stable object identity and revisions

Methods and classes have repository entity IDs independent of file paths. Accepted snapshots reconcile an existing entity identity across normal edits. Method identity includes OO side (`INSTANCE`, `CLASS`, or the reserved live `OBJECT` side), so same-named class and instance methods are distinct entities. A likely method rename with identical containing class, side, semantic body and contract preserves the prior entity identity.

A method revision ID is derived from stable entity identity plus contract/body content hashes. `surface` displays both:

```sh
bin/osc surface DataStore --repo .osc
```

Files can move or be exported differently without becoming the conceptual source entity.

## Accepted source levels are immutable

`baseline` stores an accepted source-level snapshot. Re-running the same level with identical semantic/source evidence is a no-op. Attempting to put different source into the same accepted source level fails.

Tracking decisions do not require rewriting historical source levels: candidate evidence is part of the immutable source snapshot; accept/reject decisions are stored separately and materialised when the historical snapshot is read.

When a v0.1 repository is read, v0.2 can derive newly introduced package and receiver-use semantics from the immutable historical source blobs **in memory**. That derived interpretation is rebuildable analyzer state; the accepted source level and original blob evidence are not mutated. This prevents an analyzer upgrade itself from generating false incoming application changes.

## CLI

```text
osc baseline PATH --repo REPO --component NAME --level N [--lineage L]
osc scan PATH --repo REPO [--component NAME]
osc proposals --repo REPO
osc proposal show|accept|reject ID --repo REPO [--reason TEXT]
osc surface COMPONENT --repo REPO
osc source Component.Class.method[#CLASS] --repo REPO [--level N]
osc export COMPONENT --repo REPO [--level N] --to DIRECTORY
osc consumers TARGET[#CLASS] --against WORKTREE [--repo REPO]
osc intake|impact ROLLUP.zip --repo REPO --against WORKTREE
```

`impact` and `intake` are aliases. Intake never adopts incoming code; analysis and adoption are separate operations.

## Example workflow

```sh
rm -rf /tmp/my-source-repo

# Establish accepted source level 1. Suspected external operations are proposed.
bin/osc baseline tests/fixtures/provider_v1 \
  --repo /tmp/my-source-repo \
  --component DataStore \
  --level 1

bin/osc proposals --repo /tmp/my-source-repo
bin/osc proposal show TP-... --repo /tmp/my-source-repo
bin/osc proposal accept TP-... --repo /tmp/my-source-repo \
  --reason production SQL result shape matters

# No historical source rewrite is required after the decision.
bin/osc surface DataStore --repo /tmp/my-source-repo

# Inspect a ZIP containing another ZIP containing DataStore level 2.
bin/osc impact tests/fixtures/incoming_rollup.zip \
  --repo /tmp/my-source-repo \
  --against tests/fixtures/work
```

The acceptance fixture reports all of these independently:

```text
METHOD_CONTRACT_CHANGED
METHOD_REMOVED
SQL_PROJECTION_OR_ORDER_CHANGED
KNOWN_UNSATISFIED_SURFACE
DECLARED_RESULT_ORDINAL -> MAY_BREAK_HIGH
```

and reports exact work-tree source locations such as `src/Consumer.cls:5`.

## Recursive roll-up intake

`RollupIntake` recursively extracts nested ZIP archives into an isolated repository staging directory. New packages should use `SSC_MANIFEST`. Legacy packages are recognised from the originating ZIP filename and receive `sourceLevel=UNKNOWN`.

The supplied real `oorexxapis(8).zip` was used as a scale/legacy acceptance case. With `security_effect` level 1 baselined from its real v0.9 package, v0.2 recursively inspected the roll-up, recognised the later legacy `security_effect` package without a manifest, and reported a method implementation change. On the supplied environment this took approximately 4.6 seconds for roll-up intake after a roughly 2.2 second 170-method real-component baseline.

## Current bounded-analysis policy

v0.2 intentionally does not pretend to be a complete ooRexx compiler or SQL parser.

Static evidence includes:

- a comment-aware lexical view, so structural/directive/external-operation evidence is not inferred from `/* ... */` or `--` comments;
- `::class` directives and their class contract tail (visibility/inheritance surface);
- `::method` / `::routine` method surfaces;
- `USE [STRICT] ARG` argument contracts;
- message sends visible as `~message`;
- explicit `AT_LEAST`, data-lineage and result-ordinal annotations;
- proposal candidates for recognisable SQL and `ADDRESS SYSTEM` / `ADDRESS COMMAND` operations.

Dynamic sends, dynamically assembled SQL and external operations that cannot be safely resolved should be treated conservatively. The architecture is designed so additional analyzers contribute evidence without replacing stable repository identities or reviewer decisions.

## Deliberate boundaries for v0.2

- It is an ooRexx semantic source repository and impact engine, not a distributed VCS.
- It does not use Git internally or require Git for source-history semantics.
- Only one accepted active lineage per component is persisted by the v0.2 CLI; incoming lineage changes are recognised and flagged rather than silently numerically compared.
- SQL analysis is bounded, not a full SQL dialect parser.
- Obvious system command lines are proposed; HTTP/API/queue/stored-procedure detectors can be added through the same `ExternalCandidate` contract.
- Archive extraction currently uses the platform `unzip` command into repository-controlled staging.
- Runtime-observed dependency evidence and live code-epoch trial/accept/reject integration are the natural next layer; v0.2 already exposes historical method source for that integration.

## Runtime requirements

Validated with:

```text
ooRexx 5.3.0 r13196 - Internal Test Version
```

The package vendors the supplied ooRexx Crypto v0.2 implementation for compatibility MD5 contextual fingerprints and a pure-Rexx SHA fallback. Normal revision/blob hashing uses the platform `sha256sum` for roll-up-scale performance.

Run acceptance tests with:

```sh
./run_tests.sh
```

# Virtual RYTA / HardWorld v0.31-work database promotion-basis validation

Rule: database evidence may be cited by authority, but evidence is not authority. A refused promotion remains refused regardless of the richness or success of its database basis.

---

# Virtual RYTA / HardWorld v0.30-work Database Core v0.43 provenance validation

`v0.30-work` descends from the manually validated v0.29-work checkpoint and uses the same canonical `oorexxapis(20260824-191338).zip` upstream set. Sealed v0.23 remains the release checkpoint.

Fresh v0.30 boundary: Database Core logical transaction/retry projection is deterministic, detached, rich-provenance preserving, and explicitly non-authoritative. The existing Queue/Legal authority-lifetime and authenticated-ledger rules remain unchanged.

---

# Virtual RYTA / HardWorld v0.29-work Alchemy v0.8 / current API validation

## Development status

`v0.29-work` is an incremental descendant of the exact bundled `virtual_ryta_hardworld_v0.28_work.zip`. Sealed `v0.23` remains the release checkpoint. This cut moves the RYTA house base to Alchemy Objects v0.8 and adds an optional governed Logging v0.5 interposition boundary around the authority-bearing decision surface.

## Canonical API roll-up

```text
oorexxapis(20260824-191338).zip
sha256 c2e3b1e7751e3ed69514cc2743e1ba82c0d3e6b7ca2b16f999a862f3dcfef5a8
source ancestor current/virtual_ryta_hardworld_v0.28_work.zip
sha256 ae0556ac73dd518128fbb62543ceb5cea66fc6e530d13c0b81c2b3dda2d79d70
```

`CURRENT_STACK_LOCK.sha256` pins 47 non-RYTA `current/` members. Lock replay: **47/47 PASS**.

## Fresh v0.29 evidence

```text
Alchemy Objects v0.8 RYTA STANDARD adoption                 PASS
  construction provenance                                    INIT/base-0.8
  house standard                                              ALCHEMY-HOUSE-OBJECT-0.8
Alchemy v0.8 + Logging v0.5, Logging-first                  PASS
  physical wrappers                                           1
  providers                                                    2
  independent Alchemy release                                PASS
Alchemy v0.8 + Logging v0.5, Alchemy-first                  PASS
  destructive inner removal while outer wrapper active       REFUSED
  refusal code                                                TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE
  final independent release                                  PASS
RYTA decision semantics under both orders                    UNCHANGED
Alchemy execution provenance raw world argument              NOT RETAINED
Legal reducer-order guard                                     PASS / retained
Native live Legal authority / Registry v0.14                 PASS
Legal v0.14 counterfactual non-authority                     PASS
Queue authenticated authority transport                      PASS
Queue retained consumer-time authority                       PASS
Queue authenticated-ledger adversaries                       PASS
Legal retained consumer-time evaluation                      PASS
Legal authenticated completed-work recovery                  PASS (split after aggregate timeout)
Camera v0.41 RYTA bridge                                      PASS
Structured Relation v0.9 rich bridge                         PASS
Structured Relation v0.9 -> NoSQLServer v0.77                PASS
Runtime Registry v0.14 execution evidence                    PASS, 24 assertions
Database Core v0.43 transaction identity                     PASS
Database Core v0.43 retry-attempt context                    PASS
Database Core v0.43 relational source                       PASS
Database Core v0.43 conformance failure                      PASS
RYTA core vectors                                             64 / 0 holes / 0 ambiguous
adversarial corpus                                            25/25
mutants killed                                                16/16
table-fed authority                                           18/18
consistency x authority                                       162/162
rexxc                                                         42/42
exercised upstream trees                                      PRISTINE 9/9
```

The aggregate current-stack runner reached the final unchanged pure-ooRexx crypto-heavy Legal ledger-recovery gate before the outer command window expired. That final gate was then run alone and PASSed; the aggregate timeout is not represented as a product failure.

### Upstream qualification yellow label

Camera v0.41's own `test_camera_execution_provenance.rex` explicitly expects Alchemy construction `base_version=0.7`; when run against the canonical Alchemy Objects v0.8 it reaches the assertion and reports expected `0.7`, actual `0.8`. The RYTA Camera integration passes on v0.8 and Camera source is pristine. RYTA therefore records this as a stale upstream package-qualification assertion, not as permission to patch Camera.

## Non-authority claims

- cooperative method interposition changes observability mechanics, not RYTA authority;
- Logging events and policies do not become HardWorld, Legal Effect or EvidencePromotion authority;
- Alchemy object/interposition/execution identities remain outside deterministic RYTA semantic identity;
- Runtime Registry execution evidence remains provenance rather than legal authority;
- Database transaction/attempt identity is supporting provenance and does not confer RYTA authority;
- `LEGAL_STATUS_REDUCTION_AMBIGUOUS` remains fail-closed.

---

# Virtual RYTA / HardWorld v0.28-work API-roll-up validation

## Development status

`v0.28-work` is an incremental descendant of the supplied `virtual_ryta_hardworld_v0.27_work.zip` and remains a work checkpoint. Sealed `v0.23` remains the release checkpoint. The cut migrates RYTA-owned long-lived objects to Alchemy Objects v0.7 preferred construction and adds an explicit Legal Effect v0.14 counterfactual non-authority boundary.

## Canonical API roll-up

```text
oorexxapis(20260824-162718).zip
sha256 bdfe9b499bdb4911160b634a6bfa0feb168f786b62fba66a89017e77c417a489
source ancestor current/virtual_ryta_hardworld_v0.27_work.zip
sha256 00f08fb626a1a7ec1408267bedd3f3ff63e1857c460e10bf07ff218ed5eb8c7c
```

`CURRENT_STACK_LOCK.sha256` pins 45 non-RYTA `current/` members. Lock replay: **45/45 PASS**.

## Fresh v0.28 evidence

```text
Alchemy Objects v0.7 preferred RYTA adoption                 PASS
  adoption                                                    STANDARD
  construction provenance                                    INIT/base-0.7
  internal legacy rytaInitAlchemy calls                      0
  VirtualRYTA EVALUATE execution provenance                  PASS
  raw world argument retained                                NO
Legal Effect v0.14 counterfactual non-authority              PASS
  hypothetical                                                true
  authoritative                                               false
  assumption authority                                       COUNTERFACTUAL_ASSUMPTION
  same analysis / different Alchemy adapter id               same evidence identity
  changed assumption                                          different evidence identity
  counterfactual -> promotion                                 REFUSED
  counterfactual -> EvidencePromotionApplier                  REFUSED
Legal reducer-order guard                                     PASS / retained
Native live Legal authority compatibility                     PASS
Queue authenticated authority transport                      PASS
Queue retained consumer-time authority                       PASS
Queue authenticated-ledger adversaries                       PASS
Legal retained consumer-time evaluation                      PASS
Legal authenticated completed-work recovery                  PASS
Camera v0.40 bridge                                           PASS
Structured Relation v0.9 rich bridge                         PASS
Structured Relation v0.9 -> NoSQLServer v0.77                PASS
rexxc                                                         41/41 PASS
RYTA core vectors                                             64 / 0 holes / 0 ambiguous
adversarial corpus                                            25/25
mutants killed                                                16/16
table-fed authority                                           18/18
consistency x authority                                       162/162
exercised upstream trees                                      PRISTINE 8/8
```

Focused upstream current-API tests also passed for Alchemy v0.7 execution provenance, Legal v0.14 counterfactual evaluation (63 assertions), Runtime Registry v0.13 pinned Ability routing, Queue Fabric v0.9 release-boundary compatibility, Camera v0.40 Alchemy v0.7 trend persistence, and NoSQLServer v0.77 Alchemy-object-base smoke.

The aggregate promoted-stack shell runner was interrupted in the unchanged pure-ooRexx SHA-512 Structured->legacy-Legal compatibility path. That aggregate completion is **not** claimed. The same compatibility path had passed against this exact API roll-up before the v0.28 Alchemy constructor migration; changed v0.28 paths and all authority-lifetime/authenticated-ledger gates were executed separately after migration. Incremental byte-identity evidence is recorded in `V028_INCREMENTAL_INHERITED.txt`.

## Non-authority claims

- Alchemy object identity, telemetry, introspection and execution provenance are evidence, not RYTA authority.
- Legal v0.14 counterfactual results are hypothetical analysis, never live legal execution authority.
- `COUNTERFACTUAL_ASSUMPTION` is not evidence that the assumed fact is true.
- Runtime Registry identity remains execution provenance, not legal authority.
- Queue durability and authenticated ledger state do not mint new legal authority.
- `LEGAL_STATUS_REDUCTION_AMBIGUOUS` remains fail-closed.

---

# Virtual RYTA / HardWorld v0.27-work authenticated-ledger validation

## Development status

`v0.27-work` authenticates the durable Queue authority execution ledger. Only MAC-verified V3 completion state is eligible for automatic ACK-only recovery. V1/V2 remain historical evidence only. Sealed `v0.23` remains the release checkpoint.

## Current evidence

- authenticated Queue ledger adversarial suite: **PASS**;
- authenticated Queue transfer/receipt integration: **PASS**;
- native Legal Effect v0.10 authenticated completed-work recovery: **PASS**;
- retained-authority v0.25 compatibility: **PASS**;
- native Legal v0.10 / Camera / Structured Relation / NoSQL promoted-stack gates: **PASS**;
- forged/mutated/reordered V3 records: **REFUSED**;
- missing V3 keyring / missing historical rotation key: **REFUSED**;
- V1/V2 recovery downgrade: **REFUSED**;
- externally anchored valid-tail rollback: **REFUSED on checkpoint mismatch**;
- `rexxc`: **40/40**;
- RYTA core: **64 vectors, 0 holes, 0 ambiguous winners**;
- adversarial corpus: **25/25**; mutants: **16/16 killed**;
- table authority: **18/18**; consistency x authority: **162/162**;
- current library lock: **29/29**;
- exercised upstream trees: **byte-identical to fresh extraction**.

The local V3 MAC chain is not described as rollback-proof. A separately trusted/monotonic host checkpoint is required to detect replacement by an older otherwise-valid chain prefix.

---

# Virtual RYTA / HardWorld v0.26-work authority-lifetime validation

## Development status

`v0.26-work` separates immutable work-envelope identity, authority-decision
identity, and queue delivery-attempt identity. A durable V2 `COMPLETE` record may
therefore authorize transport ACK cleanup for the same immutable envelope without
minting fresh authority or reapplying HardWorld state. New work still requires
fresh consumer-time authority. Sealed `v0.23` remains the release checkpoint.

## Current evidence

- promoted current-stack v0.26 runner: **PASS**;
- Legal Effect v0.10 completed-work ACK recovery: **PASS**;
- cached authority cross-attempt / cross-work adversaries: **REFUSED**;
- tampered COMPLETE envelope ACK bypass: **REFUSED**;
- `rexxc`: **40/40**;
- RYTA coverage: **64 vectors, 0 holes, 0 ambiguous winners**;
- adversarial corpus: **25/25**; mutants: **16/16 killed**;
- table authority: **18/18**; consistency x authority: **162/162**;
- current library lock: **29/29**;
- inherited byte identity: **297 unchanged files, 0 unexpected deltas**;
- upstream ownership: exercised trees **byte-identical to fresh extraction**.

The monolithic inherited debug runner was interrupted in the unchanged Librarian
relation stress path by the outer execution window. That monolithic completion is
not claimed; incremental inherited acceptance is documented in
`V026_INCREMENTAL_INHERITED.txt`.

---

# Virtual RYTA / HardWorld v0.23 promoted-stack roll-up validation

## Seal status

`v0.23` is the sealed recovery checkpoint on
`oorexx-libs(20260822-020835).zip/current/`. The Runtime Registry evidence
blocker recorded by v0.22-work is closed, and the seal-critical inherited,
compile, current-stack, manifest and ownership gates were replayed from fresh
manual extractions under ooRexx 5.3.0 r13196.

## Canonical recovery source

```text
oorexx-libs(20260822-020835).zip
sha256 fe807190fdffcdaee28ccc44c09ede7f9f674d01a816a062e3d3c963ae680eea
```

Exact member hashes are recorded in `CURRENT_STACK_LOCK.sha256`.

## Runtime

```text
Open Object Rexx 5.3.0 r13196 - Internal Test Version
Build date: Aug 3 2026
Addressing mode: 64
```

The user-supplied debug `.deb` is extracted in isolation for testing.

## Promoted current-stack focused results

```text
Legal Effect v0.7 native runtime promotion + Registry v0.11    PASS
  detached RuntimeExecutionEvidence                           PASS
  runtime provenance retained as basis                        PASS
  runtime artifact excluded from legal authority              PASS
Queue Fabric v0.8.1 authority/replay boundary                 PASS
Camera v0.34 -> Algorithm Relation                            PASS
Structured Relation v0.9 -> HardWorld rich evidence           PASS
Structured Relation v0.9 -> NoSQLServer v0.75                 PASS
Structured Git/code -> Legal v0.7 -> HardWorld                PASS
Legal v0.7 promotion -> NoSQLServer v0.75                     PASS
Runtime Registry v0.11 execution-evidence acceptance          PASS (24 assertions)
Queue Fabric v0.8.1 core                                      PASS
  acceptance/adversarial                                      62 / 71 assertions
  concurrency                                                  2000 / 2000, 0 duplicates
  MQ / NoSQL / channels / channel-NoSQL                       141 / 24 / 85 / 38
  topics / topic-NoSQL                                        135 / 44
Camera v0.34 frozen-generation assessment                     PASS
NoSQLServer v0.75 focused v0.71-v0.74 regression set          PASS
NoSQLServer v0.75 optional Unicode/TUTOR smoke                SKIP (TUTOR root not supplied)
RYTA class compilation under rexxc                            PASS (37/37)
Locked upstream member hashes                                 PASS (19/19)
Nested ZIP archive integrity                                  PASS (17/17)
```

The previous expected `LEGAL_RUNTIME_EVIDENCE_REQUIRED` result is therefore no
longer part of the canonical promoted-stack contract. If that result reappears
with this exact locked stack, it is a regression.

The known Legal Effect v0.7 reducer-order adversary remains guarded separately;
runtime execution evidence proves which code generation executed the legal
machinery but does not cure or mask semantic reducer ambiguity.

## Ownership

Every `current/` member is a read-only upstream input. v0.23 modifies only
the RYTA recovery descendant. Package promotion is by hash-pinned replacement,
never by patching somebody else's source tree.

---

## Historical v0.22-work validation retained for lineage

# Virtual RYTA / HardWorld v0.22 recovery roll-up validation

## Candidate status

`v0.22-work` reconstructs the known v0.20 + v0.21 RYTA deltas over the clean
`oorexx-libs.zip/current/virtual_ryta_hardworld_v0.19.zip` anchor. It is not
sealed because the canonical bundled Runtime Registry v0.8 lacks the
`RuntimeLease~executionEvidence` surface required for runtime-bound Legal Effect
v0.7 evaluation.

## Canonical recovery source

```text
oorexx-libs.zip
sha256 401791f9b617418eaf33bd8defb8f6382e7491095def66da6817dda5c20caf59
```

Exact member hashes are recorded in `CURRENT_STACK_LOCK.sha256`.

## Runtime

```text
Open Object Rexx 5.3.0 r13196 - Internal Test Version
Build date: Aug 3 2026
Addressing mode: 64
```

The exact user-supplied `.deb` was extracted in isolation; no system ooRexx
replacement was required.

## Current-stack replay results

```text
Legal Effect v0.7 semantic/execution identity guard       PASS
Queue Fabric v0.5 authority/replay boundary               PASS
Camera v0.33 -> Algorithm Relation                        PASS
Structured Relation v0.9 -> HardWorld rich evidence      PASS
Structured Relation v0.9 -> NoSQLServer v0.73            PASS
Structured Git/code -> Legal v0.7 -> HardWorld            PASS
Legal v0.7 promotion -> NoSQLServer v0.73                 PASS
Runtime Registry v0.8 <-> Queue Fabric v0.5 HTTP ability  PASS
Queue Fabric v0.5 core                                    PASS
runtime-bound Legal v0.7                                  EXPECTED FAIL-CLOSED
  code: LEGAL_RUNTIME_EVIDENCE_REQUIRED
```

Queue Fabric core replay against bundled NoSQLServer v0.73 + Registry v0.8:

```text
acceptance      62 assertions PASS
adversarial     71 assertions PASS
concurrency     2000 produced / 2000 consumed / 0 duplicates
MQ semantics    141 assertions PASS
NoSQL           24 assertions PASS
channels        85 assertions PASS
channel NoSQL   38 assertions PASS
```

## Inherited RYTA suite replay

The debug build exceeded the outer wall-clock on a monolithic `run_all.sh`, so
the suite was completed in two segments without changing the tree:

```text
completed before harness timeout       28 PASS
remaining non-staging Rexx tests       33 PASS
non-staging Rexx total                  61 / 61 PASS
static/Python guards                    PASS
rexxc                                   37 / 37 classes PASS
```

See `V022_INTERNAL_SPLIT_RUN.txt`, `V022_STATIC_GUARDS.txt`, and
`V022_REXXC.txt`.

The existing RYTA reducer-order guard also remains required; Legal Effect v0.7
still exposes differing execution/status results for the known undeclared norm
combination while semantic identity remains equal.

## Ownership

All packages extracted from `oorexx-libs.zip/current/` are read-only upstream
inputs. This recovery cut modifies only the RYTA work tree. A final packaging
step must re-check upstream hashes against `CURRENT_STACK_LOCK.sha256` before any
seal decision.

---

## Historical v0.21-work validation retained for lineage

# Virtual RYTA / HardWorld v0.21 work validation

## Candidate status

`v0.21-work` is **not sealed**. The Queue Fabric v0.5 integration is executable and green, but the currently supplied Runtime Registry v0.8 archive is a different same-labelled artifact from the one recorded with sealed v0.20 and cannot satisfy Legal Effect v0.7 runtime provenance.

## Runtime

```text
Open Object Rexx 5.3.0 r13196 - Internal Test Version
Build date: Aug 3 2026
Addressing mode: 64
```

Runtime source: user-supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64(4).deb`, extracted under `/tmp` rather than installed over the container.

## Exact current inputs

```text
oorexx_queue_fabric_v0.5.zip      76c363aca4fd012ed94555a73ba11cbef695ce5f39069f42f872defefb1f3161
nosqlserver_v0.73.zip              d0f557feed29897c87350e0966672b3cce2b1b42dad11e3c9e55577f6890e897
virtual_ryta_hardworld_v0.20.zip   24ceb1ae3762feaaa2ff7a53869baf878a7538f5123d258b29d1bd6fcd11b7bc
legal_effect_v0.7(1).zip           32ef8fc0a68f8f9180dcbf3efb6710174fc177bd856e0c70333524013d21742e
runtime_registry_v0.8(1).zip       6b4f4c8e13b86762c5640e8d993aafe7d0babe9893c724f008cdce4147b42df5
```

The Runtime Registry v0.8 checksum retained from the sealed-v0.20 companion set is:

```text
7ef1eccbf52871968db78ded125f7ee2f05146f0922e24079e1418ada2ae4e30
```

The two same-labelled Registry archives are therefore treated as distinct artifacts.

## v0.21 focused Queue authority execution

`tests/run_queue_authority_v021.sh` against Queue Fabric v0.5: **PASS**.

The executable test covers local application/ACK, work-fingerprint conflicts, START-only crash uncertainty, COMPLETE-before-ACK replay suppression, real transfer receipts, registered-receipt validation, mandatory execution namespace, durable receipt recovery across Queue Manager restart, duplicate transfer suppression after restart, absence of raw/hex `claimToken` from the RYTA ledger, and absence of claimed-package/raw-ACK objects from RYTA result surfaces.

## Inherited HardWorld suite

`tests/run_all.sh`: **PASS**.

Key inherited invariants observed in the run include:

```text
world combinations                     64
holes                                   0
ambiguous winners                       0
mutation mutants killed                 16
mutation survivors                      0
table-fed authority vectors             18 / 18
consistency x authority vectors         162 / 162
RESULT/result static guard              PASS
legacy determinism static guard         PASS
```

`rexxc` over all shipped `.cls` files in the work tree: **37 / 37 PASS**.

## Queue Fabric v0.5 upstream core against current companions

Fresh core run against NoSQLServer v0.73 + current Runtime Registry v0.8 upload:

```text
acceptance                              62 assertions PASS
adversarial                             71 assertions PASS
concurrency                             2000 produced / 2000 consumed / 0 duplicates
MQ semantics                            141 assertions PASS
NoSQL                                   24 assertions PASS
channels                                85 assertions PASS
channel NoSQL                           38 assertions PASS
```

The full pure-ooRexx Ed25519 checkpoint suite was not re-certified here: the debug interpreter exceeded the command window during the expensive Ed25519 scalar test. The bundled crypto known-answer test itself passed before that timeout. v0.21 Queue-authority execution does not claim a fresh complete Queue Fabric crypto-suite seal from this run.

## Runtime Registry <-> Queue Fabric

The current Runtime Registry artifact's `test_ability_http_queue_fabric.rex` passes unchanged against Queue Fabric v0.5. It proves generation drain/activation and rich queue payload behaviour at the existing public integration surface.

## NoSQLServer v0.73 focused replay

Under the exact r13196 runtime:

```text
v073_json_relation_smoke                    PASS
v072_general_join_on_smoke                  PASS
v071_external_mutation_dispatch_smoke       PASS
v070_external_metadata_boundary_smoke       PASS
```

## Legal Effect v0.7 safety gates

The known reducer-order attack still reproduces:

```text
semantic identity A == B                   PASS
execution identity A != B                  PASS
raw status A != B                          PASS
HardWorld authority promotion refused      LEGAL_STATUS_REDUCTION_AMBIGUOUS
```

Against the **currently uploaded** Runtime Registry v0.8 artifact, native Legal v0.7 runtime acquisition fails closed as expected:

```text
LEGAL_RUNTIME_EVIDENCE_REQUIRED
Runtime Registry execution evidence is required by legal.effect/0.7
```

Inspection confirms this archive's `RuntimeLease` has no `executionEvidence` method, while Legal Effect v0.7 explicitly requires that method before returning a legal runtime lease. No RYTA adapter manufactures substitute evidence.

## Seal decision

Do not seal v0.21 against the currently supplied Registry archive. Sealed v0.20 remains authoritative until the exact Registry artifact carrying the execution-evidence contract is restored or a genuinely newer upstream Registry version is supplied and validated.

---

## Inherited v0.20 validation

## Runtime

```text
Open Object Rexx 5.3.0 r13196 Internal Test
Build date: Aug 3 2026
64 bit
```

All commands used the supplied r13196 runtime with its standard ooRexx class directory on `REXX_PATH`.

## Release base and package integrity

The user-supplied `virtual_ryta_hardworld_v0.19.zip` was extracted before modification and its complete `MANIFEST.sha256` verified successfully.

v0.20 is based on that exact tree. Production-code delta from v0.19 is limited to:

```text
NEW     integration/LegalEffectV07PromotionAdapter.cls
CHANGED integration/StructuredRelationRichEvidenceAdapter.cls
```

`tests/run_all.sh` gains static guards for the v0.7 adapter. All other new files are tests, docs and validation evidence.

No companion package is modified or vendored.

## Companion stack directly exercised

```text
structured_relation_plugin_v0.8
runtime_registry_v0.8
legal_effect_v0.7
virtual_ryta_hardworld_v0.20
nosqlserver_v0.71        focused promotion/SQL boundary
ooRexx 5.3.0 r13196
```

Legal Effect v0.6 was additionally used for backwards-compatibility authority tests.

## Native Legal Effect v0.7 authority bridge

Focused current-stack tests:

```text
LEGAL EFFECT V0.7 NATIVE PROMOTION + RUNTIME PROVENANCE V0.20      PASS
LEGAL EFFECT V0.7 SEMANTIC / EXECUTION IDENTITY GUARD V0.20       PASS
STRUCTURED V0.8 GIT -> LEGAL EFFECT V0.7 -> HARDWORLD V0.20       PASS
LEGAL EFFECT V0.7 PROMOTION ALGREL -> NOSQL V0.71 V0.20           PASS
```

Authority has the form:

```text
LEGAL_EFFECT/0.7/<generation>
  @<semantic-hash>
  +<execution-hash>
  +cert:<certificate-hash>
  +verified:<verification-closure-hash>
```

The focused runtime test confirms Runtime Registry artifact/generation identity is absent from this authority string and appears only as promotion basis.

## Verification/compiler closure

The v0.7 generation snapshot carries forward the v0.19/v0.6 verifier hardening rather than relying only on a derived boolean verification surface.

For every compiler-certificate verification snapshot, v0.20 validates the live bound verifier evidence across:

```text
subject kind
source id
provision id
expression id
locator
algorithm
expected digest
actual digest
verified flag/status
material representation
material length
verifier id
verification time
parent verification evidence
```

Missing, duplicate, unverified or mismatching evidence fails authority pinning.

Promotion basis includes:

```text
LEGAL_VERIFIED_SOURCE
LEGAL_SOURCE_VERIFICATION_EVIDENCE
LEGAL_VERIFIED_PROVISION
LEGAL_PROVISION_VERIFICATION_EVIDENCE
LEGAL_COMPILATION_CERTIFICATE
```

Focused tests assert detached verifier snapshots retain the original native source objects.

## Runtime Registry v0.8 provenance boundary

`LEGAL_RUNTIME_EXECUTION` and `UPSTREAM_RUNTIME_EXECUTION` basis entries retain detached `RuntimeExecutionEvidence` when the Legal Effect runtime envelope is supplied.

The runtime test proves:

```text
runtime generation captured       PASS
runtime artifact captured         PASS
runtime artifact excluded from legal authority PASS
runtime evidence object retained  PASS
runtime evidence survives lease release PASS
```

## Structured Relation v0.8 Git/code evidence chain

The public Bitcoin Core PR #35688 corpus is analyzed through Structured Relation v0.8. The exact carried source snapshots verify against Git object identity:

```text
base blob  0796bbeb3271a210ed7ed5d85a82fc76939db61a
head blob  d9e16f361107c6d66f32ad8050c658d3b01f9241
identity   GIT_BLOB_BOUND
```

The derived finding is:

```text
BOUNDS_VALUE_FLOW_PROTECTION_PRESERVED
```

A separately verifier-backed, compiler-certified Legal Effect v0.7 policy evaluates that evidence as `REVIEW_REQUIRED`. After explicit promotion/application, the HardWorld review-required fact retains the original `CodeSemanticChange`; both exact remote revisions and their bound blob identities remain reachable.

## Rich complex diagnostic canonicalisation

The first v0.20 integration attempt correctly failed authority pinning because code-analysis diagnostics contain ordered `evidence` / `counterEvidence` arrays rather than only scalar details.

v0.20 does not drop or stringify these objects. `STRUCTURED_DIAGNOSTIC_V2` canonicalises supported provenance-bearing objects using explicit public identity surfaces:

```text
remote repository/revision/path
claimed and computed blob identity
blob verification state
source span + lexical source
symbol identity
operation kind/callee
constraint/value-flow discriminators
before/after semantic-change identities
```

Arrays remain ordered, map keys are sorted, and volatile observation timestamp keys are excluded from semantic identity while remaining available on the untouched native diagnostic object.

No arbitrary object's `string` method is used as a fallback.

## Reducer ambiguity fault-line

The known Legal Effect ungrouped status-reduction adversary still reproduces under v0.7. Two compiler-certified generations can have the same insertion-order-independent legal semantic identity but different observable execution identities and raw reduced statuses.

Both authority attempts are refused as:

```text
LEGAL_STATUS_REDUCTION_AMBIGUOUS
```

HardWorld does not invent precedence.

## v0.6 backwards compatibility

Executed against Legal Effect v0.6:

```text
LEGAL EFFECT V0.6 EFFECTIVE / SUPPRESSED AUTHORITY BASIS V0.19    PASS
LEGAL EFFECT V0.6 SEMANTIC / EXECUTION IDENTITY GUARD V0.19      PASS
LEGAL EFFECT V0.6 RETAINED OBJECT DRIFT BOUNDARY V0.19           PASS
LEGAL EFFECT V0.6 VERIFICATION EVIDENCE / COMPILER GATE V0.19    PASS
```

The historical v0.6 adapter remains present and authority semantics are unchanged.

## NoSQLServer v0.71 boundary

The v0.7 promotion relation was run through stock NoSQLServer v0.71:

```text
registration / metadata       provider executions = 0
first SELECT                   provider executions = 1
basis reads                    provider executions = 1
UPDATE attempt                 SQLUNSUPPORTED
HardWorld mutation             explicit EvidencePromotionApplier only
```

Source/provision verification snapshot rows report retained native objects.

## Complete inherited HardWorld suite

The supplied v0.19 self-contained suite passes unchanged on the v0.20 tree. Representative invariants remain:

```text
HardWorld world vectors          64
holes                             0
ambiguous winners                 0
HardWorld adversarial          25/25
HardWorld mutants killed       16/16
table-fed authority            18/18
consistency x authority       162/162
```

Static guards pass:

```text
STATIC GUARD NO RESULT VARIABLE: OK
STATIC GUARD NO LEGACY DETERMINISM: OK
STATIC GUARD NO GLOBAL NOSQL TRANSPORT CLASSES: OK
STATIC GUARD NO GLOBAL LEGAL VERIFICATION SNAPSHOT CLASS: OK
STATIC GUARD V0.7 RUNTIME NOT LEGAL AUTHORITY: OK
```

## ooRexx syntax compilation

Every shipped `.cls` target was compiled independently with `rexxc`:

```text
36 / 36 PASS
```

## Upstream companion suites

### Structured Relation v0.8

Complete native XML/EDIFACT/X12, Git, semantic, value-flow, ownership and public Bitcoin corpus suite passed. Its optional NoSQL federation tests were not part of this upstream invocation; the HardWorld v0.20 focused NoSQL test separately exercises NoSQLServer v0.71.

### Legal Effect v0.7

Complete companion-aware suite passed with Structured Relation v0.8, Runtime Registry v0.8 and HardWorld v0.20. This includes source verification, compiler boundary, runtime bundle/evidence chain and HardWorld compatibility.

### Runtime Registry v0.8

Complete suite passed with Structured Relation v0.8 and HardWorld v0.20, including crypto known-answer/verifier, structured semantic runtime, HardWorld bundle/rich dependency, Ability Registry real stack and Ability HTTP real stack.

Queue Fabric integration was skipped because no Queue Fabric package was supplied for this handoff.

## Evidence files

```text
V020_INTERNAL_FINAL_RUN.txt
V020_FOCUSED_CURRENT_STACK.txt
V020_UPSTREAM_SUITES.txt
VALIDATION_TRANSCRIPT.txt
```

## Trust-boundary non-claims

1. Digest equality does not prove who supplied the expected digest or that retrieval was authoritative.
2. `GIT_BLOB_BOUND` proves carried bytes match a claimed Git blob object ID; it does not establish repository/commit legal authority.
3. Runtime provenance is not legal authority.
4. Structured business/code evidence is not normative authority merely because Legal Effect consumes it.
5. The Legal Effect reducer-order ambiguity remains unresolved upstream and is refused here.
6. Queue Fabric was not supplied and its optional Runtime Registry integration was not re-executed.
7. No companion package was modified or vendored.

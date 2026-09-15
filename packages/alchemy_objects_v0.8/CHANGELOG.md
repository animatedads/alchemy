# Changelog

## v0.8 - 2026-08-24

- Added optional cooperation with an already-active generic method-interposition coordinator using the `__methodInterpositionAdd` / `__methodInterpositionRemove` / `methodInterpositionStatus` protocol. Alchemy becomes provider `ALCHEMY.EXECUTION_PROVENANCE` at priority 1000 and shares the existing physical wrapper rather than overwriting it.
- Preserved the existing Alchemy-first / Logging-second behavior: when a coordinator is merely available but not active, Alchemy retains its direct object wrapper so Logging v0.3 can capture and later restore that exact layer.
- Added fail-safe release ordering. A direct Alchemy wrapper cannot be removed while an outer coordinator still owns the current method; `uninstrumentMethod()` returns `TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE` without mutation until the coordinator releases.
- Added opaque per-object authorization tokens for the public cooperative callback bridge; forged callback invocation is rejected.
- Made `instrumentMethod()`, `instrumentRegisteredMethods()`, and `uninstrumentMethod()` `PROTECTED` mutation surfaces so hosted Security Manager policy can deny customer instrumentation changes.
- Extended `alchemyBaseState()` with `cooperative_interposition_available` and `coordinated_instrumentation_count` without exposing provider/interceptor objects.
- Added `test_cooperative_interposition.rex`; extended the hosted policy-mutation test to prove customer code cannot add or remove method instrumentation when service policy denies the protected METHOD checkpoints.
- Independently exercised the supplied ooRexx Logging v0.3 package in both layering orders; its unchanged pre-existing-Alchemy compatibility test remains PASS and Logging-first/Alchemy-second runs with one physical wrapper and two independently releasable providers.
- Advanced the structural house standard to `ALCHEMY-HOUSE-OBJECT-0.8`; no new external runtime dependency is introduced.


## v0.7 - 2026-08-24

- Added bounded `alchemy.objects.execution-provenance/0.1` records for explicitly instrumented eligible methods. Each record binds object/method identity, contract id/revision/canonical fingerprint, implementation origin, entry lifecycle/inheritance state, observed Security Manager runtime profile, elapsed time and result-contract/failure outcome without copying raw argument/result values.
- Advanced method contracts to `alchemy.objects.method-contract/0.2` with stable `contract_id` and monotonic `contract_revision`; policy/data edits advance the revision and each execution records the revision/fingerprint actually in force at entry.
- Implementation-origin attribution now prefers an exact effective `Method` object identity match against class-owned definitions, with an explicitly labelled lineage-scan fallback.
- Added bounded execution-retention policy (default 128, range 0..4096). Lowering the limit evicts oldest completed records only; every eviction or unretained call increments `dropped_total`.
- `SETEXECUTIONEVIDENCEPOLICY` is `PROTECTED`; the hosted mutation attack test now proves a customer Security Manager cannot disable execution evidence when service policy denies the checkpoint.
- Automatic telemetry now catches `ANY` Rexx condition for exit attribution while preserving the existing rule that PROTECTED/PRIVATE/PACKAGE/reserved Alchemy surfaces are never auto-wrapped.
- Updated `AlchemyTestRun` to enter the preferred `INIT` super-chain rather than the compatibility `initAlchemy(...)` path.
- Advanced the structural house standard to `ALCHEMY-HOUSE-OBJECT-0.7`; method-description credit now requires method-contract schema/id/revision structure.
- Added `test_execution_provenance.rex`; suite now contains 26 executable tests.


## v0.6 - 2026-08-23

- Added non-virtual `alchemy.objects.construction-provenance/0.1` evidence recording base entrypoint, receiver class/package, base version, completion and initial reserved-surface integrity.
- Added deterministic canonical reserved-surface fingerprints without placing pure-ooRexx SHA-512 on the object-construction hot path. Cryptographic tamper evidence is provided by sealed admission/checkpoint envelopes instead.
- Added `AlchemyAdoptionCheckpoint`, plain/sealed checkpoint creation, and later comparison that distinguishes a different object from post-admission reserved-surface drift.
- Bound sealed checkpoint envelopes to schema and producer purpose `<object-id>:adoption`; a valid proof for another payload/purpose is rejected.
- Added `LEGACY_INIT_ENTRYPOINT` migration warning for compatibility `initAlchemy(...)`; preferred new construction remains `self~init:super(...)`.
- Advanced the structural house standard to `ALCHEMY-HOUSE-OBJECT-0.6`, splitting inheritance credit between current integrity and clean completed construction provenance while retaining a 100-point total.
- Added `test_adoption_checkpoint.rex`; suite now contains 25 executable tests.

## v0.5.1 - 2026-08-23

- Carries forward the downstream migration fix that Alchemy base VERSION and SCHEMA facts are class-qualified (`.AlchemyObject~VERSION` / `.AlchemyObject~SCHEMA`) rather than virtual sends through `self`.
- Makes base construction non-virtual: `INIT` enters a private AlchemyObject core with an explicit search-start class, and initialization-time helper/validator calls likewise start at `AlchemyObject`.
- Uses Object-scope `CLASS` and `IDENTITYHASH` during base identity construction so descendant overrides cannot forge those initialization facts.
- Keeps `initAlchemy(...)` as a compatibility entry point, but recommends `self~init:super(...)` for new descendants.
- Treats VERSION and SCHEMA as class facts rather than reserved descendant instance-message names; legitimate business `version()` / `schema()` methods are permitted by the adoption verifier.
- Adds `test_base_dispatch_isolation.rex`, including a migration-shaped business VERSION/SCHEMA descendant and a hostile initialization-helper-shadow descendant.
- Suite count: 24 executable test programs.


## v0.5 - 2026-08-23

- Added `AlchemyAdoptionVerifier` and `AlchemyAdoptionResult` with explicit BASE, STANDARD and SECURE_READY readiness levels for downstream inheritance admission.
- Added `metadata/inheritance_contract.json` as the externalized machine-readable adoption contract for other library lanes.
- Added `AlchemyObject~alchemyBaseState()` and `AlchemyObject~alchemyInheritanceIntegrity()` read-only base surfaces.
- Reserved every non-private `AlchemyObject` method except `INIT`; descendants may initialize themselves but must not silently replace universal base behavior.
- Added class/mixin override detection and effective object-specific `setMethod()` overlay detection for reserved base surfaces.
- Added capture-time `inheritance_integrity` to every sealed introspection payload so post-admission shadowing becomes evidence-visible.
- Hardened security/evidence internals to use the AlchemyObject-scope object id directly instead of virtual dispatch through a potentially shadowed `alchemyObjectId` getter.
- Refactored internal surface-contract evaluation so sealed introspection and house scoring cannot be fooled by a descendant `checkSurfaceContract` override.
- Prevented automatic method telemetry from installing object wrappers over reserved AlchemyObject surfaces.
- Advanced the structural house standard to `ALCHEMY-HOUSE-OBJECT-0.5`; inheritance integrity and explicit PURPOSE/PACKAGE/PACKAGE_VERSION/AUTHORSHIP/STANDARDS/DESIGN_LIMITATIONS metadata now participate in the calculated score.
- Added hostile adoption tests covering missing base initialization, incomplete STANDARD metadata, class-level identity getter shadowing, object-specific method overlay, base-scope identity retention, and reserved-surface telemetry refusal.
- v0.5 contains 23 executable test programs; all have PASS evidence on the supplied ooRexx 5.3.0 r13196 development runtime. Project-host 5.2.0 r0 compatibility remains inherited evidence from v0.4.3 pending a v0.5 host rerun.


## v0.4.3 - 2026-08-23

- Recorded project-host field validation: all 22 tests PASS uninterrupted on ooRexx 5.2.0 r0 in 15.940 seconds.
- Confirmed the protected-METHOD Security Manager semantics on 5.2.0 match the reference and 5.3.0 r13196 observations.
- Confirmed the static `::REQUIRES` Security Manager supervision gap is reproducible on ooRexx 5.2.0 r0 as well as 5.3.0 r13196.
- Hardened `run_tests.sh` interpreter selection: `REXX` / `OOREXX_REXX` must identify one executable, not a shell command string such as `time rexx`.
- Documented external timing (`time ./run_tests.sh ...`) as the portable timing contract.
- Retained the v0.4.1 relative crypto dependency path fix and the v0.4.2 live fail-closed runtime semantics probe.
- `ALCHEMY-HOUSE-OBJECT-0.4` remains the house-standard identifier.

## v0.4.2 - 2026-08-23

- Replaced the hard-coded ooRexx 5.3.0 r13196 executable-profile gate with a live, process-cached protected-`METHOD` Security Manager semantics probe.
- The probe independently exercises raw `.false` and `.true` returns with a manager-supplied handled result; only the documented/reference behavior (`.false` continues, `.true` handled) is promoted to executable authority.
- Unknown version strings are no longer rejected merely for being unknown; ambiguous, reversed or failed checkpoint behavior still fails closed.
- Added `test_security_runtime_probe.rex`, including the default `AlchemySecurityManager~new(policy)` path with no explicit runtime profile.
- Retained the v0.4.1 relative crypto dependency path fix and explicit `crypto.cls` runner form.
- `ALCHEMY-HOUSE-OBJECT-0.4` remains the house-standard identifier.

## v0.4.1 - 2026-08-23

- Fixed `run_tests.sh` dependency-path handling: the crypto source path is canonicalized before the runner changes into `tests/`, so documented relative sibling paths such as `../oorexx_crypto_v0.1/src` remain valid.
- The runner now also accepts an explicit `/path/to/crypto.cls` for convenience while preserving the directory form as the documented contract.
- No Alchemy object/security semantics changed; `ALCHEMY-HOUSE-OBJECT-0.4` remains the house-standard identifier.

## v0.4 - 2026-08-23

- Added stable environment/external requirement IDs, disclosure and optional checker bindings.
- Added explicit requirement assessment history with UNCHECKED/PASS/FAIL/WAIVED/NOT_APPLICABLE/UNKNOWN states; declaration no longer implies execution.
- Added protected `runRequirementChecks()` and manual `recordRequirementResult()` surfaces.
- Added instrumentation enable/repeat/disclosure rules with canonical consecutive-repeat collapse, retained suppression totals and disabled-drop counts.
- Made requirement-result mutation and instrumentation-rule mutation `PROTECTED`; hosted Security Manager deny tests prove customer code cannot self-waive requirements or disable instrumentation.
- Applied disclosure filtering to instrumentation point definitions, events and suppression summaries.
- Advanced the structural house standard to `ALCHEMY-HOUSE-OBJECT-0.4` and made requirement/instrumentation policy structure part of the calculated score.


## v0.3 - 2026-08-23

- Corrected Security Manager documentation/profile terminology: ooRexx reference and observed r13196 both use `.false` for authorized/continue and `.true` for manager-handled behavior.
- Added structured `alchemy.objects.security-runtime-profile/0.1` reference-vs-observed evidence and included it in object introspection.
- Added Security Manager execution-context quotas with CONTEXT, METHOD, CLASS_METHOD, OBJECT and OBJECT_METHOD accounting scopes.
- Added authenticated ChaCha20 + SipHash-128 crypto-locked method records, an abstract key-provider boundary, service-local in-memory provider, and locked-method vault.
- Added envelope-locked method provisioning: one immutable method ciphertext, HMAC-SHA-512-derived per-record content key, independently revocable subkey wrappers, authenticated capability subkey claims, and single-use key/envelope retirement without ciphertext regeneration.
- Added PROTECTED per-object locked-method stubs that materialize a PRIVATE operating Method only for the call window and remove it on success or failure.
- Added independent Security Manager + vault double-gate tests and single-use capability replay rejection.
- Added method policy declarations for instrumentation, disclosure, security sensitivity, side effects and authority effects; structural contradictions fail surface checks.
- Added detached object relationship evidence that never stores the live target reference.
- Added Clouseau no-follow/suppress rules around evidence-sealer, capability-authority and locked-method-vault links, plus a serialized sentinel-key non-leak regression test.
- Added `alchemy.objects.source-snapshot/0.2`: embeds the concrete class package source once, records inherited class/package lineage, and externalizes inherited dependency source instead of repeatedly embedding inherited Method source in every descendant snapshot.
- Preserved Clouseau's good lineage and the removal of the obsolete AlchemyBsfProxy dependency.

## v0.2 - 2026-08-23

- Added object-specific method telemetry wrappers with calls, success/failure counts, elapsed totals/min/max/last and optional result-contract enforcement.
- Preserved security/access semantics by refusing automatic wrapping of PROTECTED, PRIVATE and PACKAGE-scope methods; retained originals are private object aliases.
- Preserved original guarded/unguarded method mode in generated telemetry wrappers.
- Added structured per-method INPUT/OUTPUT/RESULT data descriptions.
- Added `AlchemyCapabilityAuthority~issueForSeconds()` and cryptographically bound, enforced capability expiry using `base-day:seconds-of-day` stamps.
- Removed unnecessary SHA-512 work from capability-id generation; capability authenticity remains the MAC over the complete canonical record.
- Added capability-gated fixed execution trace evidence with separate STACK and FULL disclosure purposes.
- Avoided arbitrary customer `~string` calls while building execution-frame evidence.
- Added `ALCHEMY-HOUSE-OBJECT-0.2` claimed/calculated compliance assessment with sealed delta reporting.
- Added `AlchemyTestRun`, an `AlchemyObject` descendant for assertion, surface/result-contract and sealed test-run evidence.
- Added tests for method telemetry/access preservation, capability expiry/tamper, trace disclosure/compliance/data descriptions and inherited test support.
- Fixed Rexx-special-variable collisions where a local `result` name could be overwritten by the special `RESULT` variable after message/call expressions.
- Kept generated fixed emitters free of illegal bare labels inside DO/LOOP blocks.

## v0.1 - 2026-08-23

- Added `AlchemyObject` foundational base class.
- Added structured identity, lifecycle/usage telemetry, performance counters, requirements, method/result contracts, instrumentation ledger, compliance descriptions and sealed reports.
- Added disclosure-labelled state registration and object-specific fixed state emitter installed with `setMethod(..., "OBJECT")`.
- Added PUBLIC/CUSTOMER/INTERNAL/FULL introspection profiles and JSON serialized sealed snapshots.
- Added canonical evidence envelopes, SipHash MAC sealer, and Ed25519 sealer backed by `oorexx_crypto_v0.1`.
- Added delegated, object/operation/purpose-bound single-use capabilities.
- Added service + tenant composite ooRexx Security Manager policy.
- Added runtime-profile fail-closed behavior for Security Manager boolean semantics.
- Added executable tests proving supplied r13196 protected-method semantics, manager immutability gating, capability gating, tenant non-weakening, and the static `::REQUIRES` supervision gap.
- Integrated the supplied good Inspector Clouseau and Alchemy inspector rules.
- Removed the obsolete `AlchemyBsfProxy.cls` requirement and all BFS/BSF proxy dependencies.

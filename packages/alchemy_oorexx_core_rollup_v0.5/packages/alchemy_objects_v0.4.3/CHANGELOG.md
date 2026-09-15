# Changelog

## v0.4.3 - 2026-08-23

- Recorded project-host field validation: all 22 tests PASS uninterrupted on ooRexx 5.2.0 r0 in 15.940 seconds.
- Confirmed the protected-METHOD Security Manager semantics on 5.2.0 match the reference and 5.3.0 r13196 observations.
- Confirmed the static `::REQUIRES` Security Manager supervision gap is reproducible on ooRexx 5.2.0 r0 as well as 5.3.0 r13196.
- Hardened `run_tests.sh` interpreter selection: `REXX` / `OOREXX_REXX` must identify one executable, not a shell command string such as `time rexx`.
- Documented external timing (`time ./run_tests.sh ...`) as the portable timing contract.
- Retained the v0.4.1 relative crypto dependency path fix and the v0.4.2 live fail-closed runtime semantics probe.
- `ALCHEMY-HOUSE-OBJECT-0.4` remains the house-standard identifier.

## v0.4.3 - 2026-08-23

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

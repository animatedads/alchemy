# Alchemy Objects v0.8

Foundational ooRexx object infrastructure intended to sit underneath future Alchemy libraries.  The base is deliberately behavioural rather than application-specific: descendants inherit identity, lifecycle evidence, contracts, telemetry, inspection surfaces, cryptographic evidence and security integration rather than rebuilding those facilities independently.

## Core model

`AlchemyObject` provides inherited identity, lifecycle/usage telemetry, structured metadata, environmental and external requirements, method/result contracts, method data descriptions, declared instrumentation points, method performance telemetry, bounded execution provenance, compliance score surfaces, disclosure-labelled state registration, fixed object-specific emitters, and cryptographically sealed introspection/snapshot messages.

`AlchemyTestRun` inherits the same base.  Tests can therefore produce the same lifecycle, assertion, contract, telemetry and sealed evidence as production objects instead of living in a separate informal testing universe.

Deep source/object-graph inspection is delegated to the included Inspector Clouseau v1.4.2 lineage through `AlchemyInspectorBridge`.  The bridge deliberately uses `addRoot()` rather than `attach()` so a bounded object inspection does not implicitly seed `.environment`, `.local`, and `.context`.

## Universal inheritance/adoption contract

v0.8 carries forward the v0.6 temporal adoption model and the v0.7 execution-provenance contract. `AlchemyAdoptionVerifier~verify(object, level)` evaluates the current object by deliberately dispatching verification reads from `AlchemyObject` scope, while `AlchemyObject~alchemyConstructionProvenance` records how the non-virtual base invariant was established. `AlchemyAdoptionVerifier~checkpoint(...)` can then bind an admitted object to its identity, base version, construction provenance and reserved-surface integrity so later drift is distinguishable from bad construction.

Three readiness levels are defined:

- `BASE` — the object inherits `AlchemyObject`, the non-virtual Alchemy base initialization core actually executed, the registered surface contract is structurally valid, and no reserved base surface is shadowed;
- `STANDARD` — BASE plus package/class purpose, package version, authorship, implemented standards, and explicit design-limitations metadata;
- `SECURE_READY` — STANDARD plus a configured evidence sealer, capability authority, and a live-observed ooRexx Security Manager runtime profile.

All non-private `AlchemyObject` instance surfaces except `INIT` are reserved, with one deliberate exception: `VERSION` and `SCHEMA` are class facts and are not reserved descendant instance-message names. Descendants are expected to define their own `INIT`, but not to replace the universal evidence/security/telemetry/requirement methods. The integrity scan walks descendant/mixin class definitions and also detects object-specific `setMethod()` overlays of reserved names. Automatic method telemetry refuses to wrap a reserved base surface for the same reason.

The rule is detection-and-rejection rather than a false claim of language-level finality: ooRexx does not provide a `final` method declaration for this design. Every sealed introspection payload includes both freshly calculated `inheritance_integrity` and `construction_provenance`. The construction record retains the initial integrity fingerprint while the live record carries the current fingerprint and `reserved_surface_drift` flag.

Admission can be externalized with `AlchemyAdoptionVerifier~checkpoint(object, level)`. For tamper-evident service use, prefer `sealedCheckpoint(object, level, sealer)` and later `compareSealedCheckpoint(...)`; the envelope is purpose-bound to `<object-id>:adoption`. A valid MAC/signature on some other payload or producer is not accepted as an adoption checkpoint. Checkpoints are evidence, not authority.

The externalized form of this contract is `metadata/inheritance_contract.json`. This package defines the contract; downstream library lanes perform their own wiring/adoption against it.

## Security boundary

Alchemy uses independent gates:

1. the ooRexx Security Manager constrains what hosted/agent code may attempt;
2. delegated cryptographic capabilities authorize selected operations or disclosure profiles;
3. the object itself controls what a requested disclosure profile contains.

`AlchemyCompositeSecurityPolicy` evaluates the service policy first and a tenant policy second.  A tenant policy can tighten service policy but cannot override a service denial.

Security Manager execution is authorized by **observed interpreter behaviour, not a version-string whitelist**. `AlchemySecurityRuntimeProfile~current` performs a small live `METHOD` checkpoint probe once per process using both raw `.false` and `.true` manager returns. A runtime is promoted to an executable profile only when `.false` demonstrably continues the protected method body and `.true` demonstrably takes the handled/substitution path, matching the ooRexx Reference. The successful profile is cached for the process. Ambiguous, missing, or reversed METHOD semantics remain unobserved and `AlchemySecurityManager` fails closed. The descriptive `~documented` profile is also deliberately unobserved and cannot construct an executing manager. Project-host ooRexx 5.2.0 r0 and the supplied ooRexx 5.3.0 r13196 build both pass this live probe.

A second observed 5.2.0 r0 and r13196 limitation is that static `::REQUIRES` in a secured routine is not delivered to the routine's Security Manager. Hosted code must therefore enter through an Alchemy-controlled loader after dependency-closure validation; the Security Manager alone must not be described as a complete package-loading sandbox.

`AlchemySecurityRuntimeProfile~evidence` exposes the normative/reference and runtime-observed return semantics as structured evidence. `AlchemyObject` includes that record in sealed introspection as `security_runtime_semantics`, so documentation drift can be detected by code and tests rather than prose review alone.

## Execution-context quotas

`AlchemyExecutionQuotaSet` can be attached to `AlchemySecurityManager`. Quotas are enforced at Security Manager checkpoints and can be scoped by execution context, method, class+method, object, or object+method. This keeps quota authority in the hosted execution envelope while still allowing per-object accounting. Quota evidence is appended to the Security Manager audit event; quota rules do not live in customer objects.

## Delegated cryptographic capabilities

External dependency: `oorexx_crypto_v0.1` (`crypto.cls`). It is not vendored here.

Capabilities issued by `AlchemyCapabilityAuthority` are MAC-authenticated and bound to:

- target object id;
- operation;
- purpose;
- subject;
- capability id/nonce;
- issued-at data;
- optional expiry.

`issueForSeconds()` produces a bounded authorization using a `base-day:seconds-of-day` expiry stamp.  The split representation is intentional: it retains one-second comparison precision under normal Rexx numeric precision, whereas a single large absolute-second counter does not.  Expiry is checked before authorization succeeds and the expiry field itself is covered by the MAC.

Capability ids are unique replay/revocation handles, not a second proof. They therefore do not perform an unnecessary SHA-512 calculation; authenticity comes from the MAC over the complete canonical capability record.

Capabilities may be single-use. `AlchemySecurityPolicy~requireCapability()` consumes by default; set its final `consumeCapability` argument to `.false` only when the protected method body itself performs the final consume.

## Crypto-locked methods

`AlchemyLockedMethodVault` supports methods whose operating source is stored as authenticated encrypted data rather than as a permanently installed Method object. A registered locked method installs only a tiny `PROTECTED` instance stub under the public message name. On a permitted call the object:

1. extracts the capability argument;
2. asks the vault/key provider to authenticate the encrypted record and consume the object/method/purpose-bound capability;
3. decrypts the source into an array of Rexx source lines;
4. creates a PRIVATE object-specific operating Method under a unique temporary alias;
5. dispatches to that alias with the business arguments;
6. removes the temporary Method on both success and propagated failure;
7. clears local plaintext/source references and records bounded audit/instrumentation evidence.

The public stub is `PROTECTED`, so hosted customer code can additionally be required to pass the ooRexx `METHOD` Security Manager checkpoint. Tests cover the double-gate form where the Security Manager verifies the capability without consuming it and the vault independently consumes it before releasing the method key. Replay therefore fails at the vault even when the outer policy still considers the signed token structurally valid.

`defineCryptoLockedMethod()` is a trusted build/host convenience that accepts plaintext source and immediately creates an encrypted record. Production hosted/customer packages should normally receive/install only an authenticated locked-method record created by trusted service code; using plaintext literals inside a package obviously means those literals remain visible in that package's own SOURCE evidence.

The current in-memory key provider is a service-local reference implementation, not a claim that long-lived production keys should reside in ordinary process memory. The provider boundary is intentionally abstract so HSM/KMS/external key services can replace it later.

The current direct in-memory key provider is retained as a small compatibility/reference implementation. `AlchemyEnvelopeLockedMethodKeyProvider` is the preferred service-side pattern: the method ciphertext is encrypted once under a per-record 256-bit content key; independently revocable 256-bit subkeys wrap only that content key. A capability carries an authenticated `locked_subkey_id` claim selecting the permitted envelope. Single-use consumption can delete that subkey and every envelope that depends on it without changing the method ciphertext.

For the built-in provisioning helper, a 256-bit master is accepted only as a method-local provisioning input and is never retained in the provider. HMAC-SHA-512 with domain separation derives the per-record content key, ChaCha nonces and subkeys; outputs used as keys are truncated to 256 bits. This avoids depending on the ooRexx `random()` function for cryptographic key entropy. In production the same interface can be backed by an HSM/KMS instead.

Revocation has the normal cryptographic limitation: deleting a raw key cannot make a copy already exfiltrated from memory cease to exist. For that reason hosted customer code receives capabilities/key identifiers, never wrapping-key bytes; the authoritative provider performs unwrap/decrypt inside the service boundary.

## Evidence sealing

Two evidence sealers are provided:

- `AlchemyMacSealer` — SipHash-2-4-128 shared-key evidence. The MAC directly binds the canonical payload and avoids a redundant pure-ooRexx SHA-512 pass.
- `AlchemyEd25519Sealer` — Ed25519 public-verification evidence with SHA-512 payload digest. This is deliberately more expensive in the current pure-ooRexx crypto implementation.

Introspection evidence is not authority. A valid seal proves the captured payload according to the configured proof scheme; it does not grant the inspected object or evidence recipient any additional execution capability.

## Disclosure levels

State variables may be registered as `PUBLIC`, `CUSTOMER`, `INTERNAL`, or `SECRET`.

- `PUBLIC`: no registered state values; descriptions/contracts/telemetry only.
- `CUSTOMER`: PUBLIC plus CUSTOMER registered values.
- `INTERNAL`: all registered values except SECRET.
- `FULL`: all registered values, the concrete class package source, class-lineage/source references, and optional graph evidence from an inspector bridge.

A non-PUBLIC `sealedIntrospection` requires a capability bound to `SEALEDINTROSPECTION` and purpose `INTROSPECT:<PROFILE>`.

SOURCE/FULL source evidence uses `alchemy.objects.source-snapshot/0.2`. The complete Rexx source document for the concrete receiver class is embedded once. Inherited classes remain represented in a lineage with their package identities and source-availability facts, but their versioned package source is externalized rather than copied into every descendant snapshot. This is deliberate: `Class~methods` without a class selector returns inherited definitions, and embedding every inherited `Method~source` repeated the same Alchemy base implementation dozens of times. Deep dependency-source collection remains a separate forensic/package-artifact operation.

The state emitter is reinstalled immediately before capture as an object-specific fixed method generated from the registered state description.  A subclass therefore cannot simply leave behind an altered emitter and have it trusted as the current capture implementation.

## Requirement execution evidence

Environment and external requirements are declarations first, not assertions that the environment was tested. Each declaration now has a stable `requirement_id`, disclosure class and optional checker method. Introspection reports `UNCHECKED` until an assessment exists. `runRequirementChecks()` is an explicit `PROTECTED` operation that runs only declared checker methods; requirements without a checker remain `UNCHECKED`. Host/test code can also call `recordRequirementResult()` to record `PASS`, `FAIL`, `WAIVED`, `NOT_APPLICABLE`, `UNKNOWN` or an explicit `UNCHECKED` result with timestamp/evidence. INTERNAL/FULL snapshots include the bounded check history.

This separation is deliberate: the existence of an environmental requirement is universal; automatic execution of an environmental probe is not.

## Instrumentation rules and repeat evidence

Instrumentation points declare `enabled`, `repeat_mode` (`ALL` or `COLLAPSE`) and disclosure. `COLLAPSE` compares canonical evidence for consecutive identical events. Repeats are not silently lost: suppression totals are retained, and the next distinct recorded event states how many repeats preceded it. Disabled-point drops are counted separately. Snapshot disclosure filters point definitions, events and suppression summaries through the same PUBLIC/CUSTOMER/INTERNAL/FULL policy.

## Method policy and detached relationships

Method contracts can additionally declare `instrumentable`, `disclosure`, `security_sensitivity`, `side_effects`, and `authority_effect`. The surface checker treats contradictions as structural failures; for example, authority-changing behavior cannot be declared on an ordinary unprotected method.

`recordRelationship()` records `OWNS`, `USES`, `LEASES`, or other caller-defined relationships using detached target identity evidence. It intentionally does **not** retain the target object reference. The telemetry/introspection layer therefore cannot become an accidental global keepalive mechanism. Relationship disclosure is filtered through the same PUBLIC/CUSTOMER/INTERNAL/FULL hierarchy.

## Method contracts, data descriptions and execution provenance

`registerMethodContract()` describes purpose, argument surface and result contract. v0.8 method contracts use `alchemy.objects.method-contract/0.2`, carry stable `contract_id = METHOD:<NAME>`, and maintain a monotonic `contract_revision`. Re-registering a contract or changing its policy/data description advances the revision. `describeMethodData()` adds structured INPUT/OUTPUT/RESULT descriptions including type, required status, description and disclosure classification.

`instrumentMethod()` is a `PROTECTED` mutation surface. For a standalone Alchemy object it installs the historical object-specific wrapper around an eligible method, retaining the original method as a private object alias and preserving guarded/unguarded mode. When the receiver already has an **active** generic cooperative method-interposition coordinator (the `__methodInterpositionAdd` / `__methodInterpositionRemove` / `methodInterpositionStatus` protocol introduced by ooRexx Logging v0.3), Alchemy instead joins that coordinator as provider `ALCHEMY.EXECUTION_PROVENANCE` at priority 1000. It therefore shares the existing physical wrapper rather than overwriting it. There is no runtime dependency on Logging: protocol detection is by object surface only.

The order rules are deliberate. If Alchemy instruments first while a coordinator is merely available but inactive, it keeps the direct-wrapper path so existing Logging-v0.3 layering remains compatible. Logging may subsequently wrap that Alchemy layer and later restore it. While such an outer coordinator still owns the current method, `uninstrumentMethod()` fails without mutation with `TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE`; removing the underlying Alchemy wrapper at that moment would corrupt the coordinator's saved restore layer. Once the outer provider releases, Alchemy can remove its direct wrapper normally. If the external coordinator arrived first, Alchemy joins it and either provider can then withdraw independently.

The generic coordinator callbacks are public only as a protocol necessity and are protected by an opaque per-object identity token held by the package-local Alchemy interceptor. Calling the callback messages directly without that exact token raises authorization failure. `instrumentMethod()`, `instrumentRegisteredMethods()` and `uninstrumentMethod()` are all `PROTECTED`, so hosted customer packages can additionally have those mutations denied by the ooRexx Security Manager.

See `INTERPOSITION_COMPATIBILITY.md` for the provider protocol, ordering rules, release behavior and Logging v0.3 compatibility evidence. The machine-readable externalized form is `metadata/interposition_contract.json`.

Optional real-package interoperability can be exercised without making Logging a runtime dependency:

```sh
./run_logging_integration.sh /path/to/oorexx_logging_v0.3 /path/to/oorexx_crypto_v0.1/src
```

That runner executes Logging v0.3's unchanged pre-existing-Alchemy regression plus Alchemy-owned Logging-first and unsafe-release-order cases.

The wrapper/interceptor records calls, successes, failures, elapsed totals/min/max/last and result-contract failures. The same instrumentation path emits bounded `alchemy.objects.execution-provenance/0.1` records. A retained record captures the method contract id/revision and a disclosure-safe canonical structural token, the effective implementation origin, object lifecycle and inheritance integrity at entry, the live-observed Security Manager runtime profile, elapsed time, and result-contract/failure classification at exit. It deliberately records only argument **count** and result **class**, never arbitrary argument/result values.

Implementation origin is resolved before the wrapper is installed. Alchemy first matches the exact effective `Method` object against class-owned definitions (`EFFECTIVE_METHOD_IDENTITY_MATCH`); if an interpreter does not preserve method-object identity through that introspection surface, the evidence explicitly labels the fallback as `LINEAGE_DECLARATION_SCAN_FALLBACK` rather than pretending certainty.

Execution history is bounded per object. The default retained limit is 128 records and may be changed, under a `PROTECTED` `setExecutionEvidencePolicy(maxRecords)` operation, within 0..4096. When space is required, the oldest **completed** records are evicted; active calls are never deleted merely to make room. Every eviction or unretained call increments `dropped_total`, so memory bounding does not masquerade as complete history.

The contract structural token is intentionally redacted. It contains structural/security fields and counts, not purpose text, argument names, or data-description text. This prevents a PUBLIC execution record from laundering a SECRET method-data description through a reversible canonical "fingerprint". Cryptographic integrity comes from the surrounding sealed introspection evidence.

Automatic instrumentation deliberately refuses:

- `PROTECTED` methods;
- `PRIVATE` methods;
- PACKAGE-scope methods.

This is a security property. Telemetry is not permitted to turn a protected interpreter checkpoint or a restricted access surface into an ordinary public wrapper.

`instrumentRegisteredMethods()` attempts instrumentation for registered contracts and returns a result for every method, including explicit skip results for ineligible surfaces. Instrumented wrappers use `SIGNAL ON ANY` for ordinary Rexx-condition exit attribution; abrupt interpreter/process termination may still leave a retained record marked incomplete, which is itself distinguishable from a normal exit.

## Fixed execution trace emitter

`sealedExecutionTrace()` is itself `PROTECTED` and capability-gated. It reinstalls a fixed object-specific execution emitter immediately before capture and supports two disclosure profiles:

- `STACK` — frame type/name/line/trace line/invocation/executable and bounded target descriptors; no arguments;
- `FULL` — STACK plus bounded argument descriptors. String argument values are included, so this profile is deliberately higher-disclosure.

Capabilities are purpose-bound to `TRACE:STACK` or `TRACE:FULL`. The trace is sealed as `alchemy.objects.execution-trace/0.1` evidence. The fixed emitter is intentionally distinct from Clouseau's deeper tracing/probe machinery.

## House-standard compliance

`declareHouseCompliance(claimedScore)` registers the `ALCHEMY-HOUSE-OBJECT-0.8` structural assessment. `complianceReport()` independently calculates the score, records claimed/calculated/max values and their delta, and returns the report only as capability-gated sealed evidence. Method-description credit now requires the method-contract schema, stable id and positive revision as well as the existing purpose/result/security-policy fields.

The current 100-point structural check covers metadata, surface contracts, current inheritance integrity, clean construction provenance, requirements, instrumentation, method/state descriptions, configured evidence/security facilities and lifecycle evidence. It is a machine-checkable house standard, not a claim that the application semantics are correct.

## Test support

`AlchemyTestRun` provides assertion evidence for booleans, strict equality, object surface contracts and result contracts. Calls to `complete()` close the run and emit completion instrumentation. The test object can then use inherited sealed introspection to produce cryptographically locked evidence of the test run.

## Inspector Clouseau

The supplied good `InspectorClouseau.cls` is included, with the obsolete `AlchemyBsfProxy.cls` dependency removed. No BFSProxy, BSFProxy or AlchemyBsfProxy implementation is required. Diagnostic references to bridge/Java concepts inside Clouseau remain ordinary inspection labels only.

The historical `AlchemyInspectorRules.cls` is retained alongside Clouseau for compatibility/reference. New base-object introspection should normally use `AlchemyInspectorBridge`.

The bridge also installs explicit no-follow/suppress rules for the base object's evidence sealer, capability authority and locked-method vault links. The acceptance suite serializes a Clouseau snapshot around an in-memory locked-method provider containing a known 32-byte sentinel key and proves the key/prefix never appears and the traversal remains at the bounded root.

## Quick use

```rexx
ring = .CryptoMacKeyRing~new
ring~addKey("service", "00112233445566778899aabbccddeeff")
sealer = .AlchemyMacSealer~new(ring)
authority = .AlchemyCapabilityAuthority~new(ring)
obj = .MyObject~new(sealer, authority)
adoption = .AlchemyAdoptionVerifier~verify(obj, "SECURE_READY")
if \adoption~ok then raise syntax 88.900 array("Alchemy adoption failed")
admission = .AlchemyAdoptionVerifier~sealedCheckpoint(obj, "SECURE_READY", sealer)

publicEvidence = obj~sealPublicIntrospection
customerCap = authority~issueForSeconds("tenant-A", obj~alchemyObjectId, -
                                        "SEALEDINTROSPECTION", "INTROSPECT:CUSTOMER", 60)
customerEvidence = obj~sealedIntrospection("CUSTOMER", customerCap)

traceCap = authority~issueForSeconds("tenant-A", obj~alchemyObjectId, -
                                     "SEALEDEXECUTIONTRACE", "TRACE:STACK", 30)
traceEvidence = obj~sealedExecutionTrace("STACK", traceCap, 32)
```

A new subclass with its own `INIT` should call `self~init:super(...)`, then register its state slots, contracts, data descriptions, requirements, instrumentation points and compliance checks. `initAlchemy(...)` remains a compatibility entry point for older descendants and is reported as `LEGACY_INIT_ENTRYPOINT` by the adoption verifier.

## Tests

Run:

```sh
./run_tests.sh /path/to/oorexx_crypto_v0.1/src
```

Relative paths are supported and are canonicalized before the runner changes directory, so a sibling checkout works directly:

```sh
./run_tests.sh ../oorexx_crypto_v0.1/src
```

For convenience the runner also accepts the explicit `crypto.cls` path.

The packaged validation suite is executed under the supplied ooRexx 5.3.0 r13196 runtime; other interpreter versions are admitted only after the live runtime-semantics probe passes in that process. It includes actual protected-method Security Manager behavior, reference-vs-observed semantics evidence, manager replacement denial, service/tenant non-weakening, static-`::REQUIRES` gap evidence, capability binding/replay/expiry, execution-context quotas, crypto-locked transient methods and Security Manager double-gating, method-policy/relationship checks, method telemetry/access preservation, bounded execution provenance/contract attribution, fixed execution traces, key-vault-bounded Clouseau integration, house compliance and inherited test-run evidence. The v0.8 suite contains 27 core test programs, including cooperative interposition ordering and mutation-security regressions. It retains the downstream-migration regression for legitimate business `version()` / `schema()` methods and the v0.6 temporal admission drift tests.

## v0.8 validation and runner note

`REXX` / `OOREXX_REXX` must identify one ooRexx executable (for example `rexx`
or `/usr/local/bin/rexx`). They are not interpreted as shell command strings.
To measure suite runtime, wrap the runner itself:

```sh
time ./run_tests.sh ../oorexx_crypto_v0.1/src
```

Project-host field validation on ooRexx 5.2.0 r0 completed all 22 v0.4.3 tests in one
uninterrupted run (real 15.940s) and independently confirms that the static
`::REQUIRES` Security Manager supervision gap is present on that runtime too. That
is platform/lineage evidence, not a claim that v0.8 itself has already completed a
5.2.0 field run.

### Safe descendant construction

Descendant `INIT` methods should call `self~init:super(metadata, sealer, authority)`.  AlchemyObject then enters its private initialization core with an explicit search-start class.  This prevents legitimate business methods such as `version()` or `schema()`--and even invalid shadows of Alchemy initialization helpers--from intercepting partially initialized base construction.

`initAlchemy(...)` remains as a compatibility entry point for existing descendants, but it is a reserved Alchemy surface and should not be overridden.  Alchemy base facts use `.AlchemyObject~VERSION` and `.AlchemyObject~SCHEMA`; `VERSION` and `SCHEMA` are intentionally *not* reserved instance-message names because downstream classes may legitimately define business methods with those names.

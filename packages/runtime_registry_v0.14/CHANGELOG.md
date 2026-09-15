# Runtime Registry changelog

## v0.14

- bumps `RuntimeRegistryBuild~RELEASE` to `0.14` while retaining the stable `runtime.registry/0.3` core API contract;
- retains the reference HTTP protocol `ability.http/0.7` and optional WLU bridge `ability.wlu/0.1`; this is a consumer qualification release, not a protocol redesign;
- requalifies the existing dynamic `AbilityWLUBridge` against `oorexx_work_load_units_v0.12` and authenticated discovery evidence `work.load.units/0.12`;
- removes the stale acceptance assumption that a current WLU authority must report `work.load.units/0.3`; no compatibility shim or version masquerading is introduced;
- preserves pre-work rejection = zero spend, post-work rejection = settle performed work, result-store failure settlement, and capacity refusal before dynamic provider side effects;
- keeps standalone `oorexx_crypto_v0.1` as the cryptographic dependency and does not vendor WLU or Alchemy sources.

## v0.12

- bumps `RuntimeRegistryBuild~RELEASE` to `0.12` while retaining the stable `runtime.registry/0.3` core API contract;
- advances the reference HTTP protocol to `ability.http/0.6`;
- adds the optional `AbilityWLU.cls` bridge (`ability.wlu/0.1`) to the external Work Load Units authority without moving tariffs, balances, buckets or throughput policy into Runtime Registry;
- keeps `AbilityHttpServer.cls` free of a `WorkLoadUnits.cls` dependency so deployments with no WLU bridge retain the non-WLU v0.11-compatible path;
- admits WLU-managed work before dynamic capability dispatch and maps WLU entitlement/capacity/throughput refusal to HTTP 429, propagating `Retry-After` when supplied;
- exposes only `wluManaged`, reservation identity/scope and `meterFact(...)` through `AbilityInvocationContext`; dynamic capability code never receives WLU authority/account/bucket/rate-card/raw-reservation objects;
- settles actual performed work independently of business success, including provider rejection or materialisation failure after meter facts have been emitted;
- retains WLU evidence as detached `execution.wlu` metadata on responses/materialised results without adding synthetic WLU/execution columns to business data;
- advertises WLU governance through authenticated ability discovery and OpenAPI 429 responses while deliberately omitting live tariff/balance/capacity values;
- adds a WLU HTTP acceptance covering successful forecast-vs-actual settlement, pre-work and post-work rejection, result-store failure after performed work, retained materialised execution metadata, and 429-before-side-effects;
- rebases the v0.12 line on the v0.11.1 standalone-crypto boundary and does not restore a vendored `src/crypto.cls`;
- validates the refreshed stack against Structured Relation v0.9, HardWorld v0.19, Queue Fabric v0.8.2, NoSQLServer v0.75, WLU v0.2.1, Terminal Machine v0.5 and Legal Effect v0.10.1.

## v0.11.1

- Removes vendored `src/crypto.cls`; standalone `oorexx_crypto_v0.1` is now the explicit cryptographic dependency.
- Keeps Runtime Registry's SHA-512 / Ed25519 trust contract unchanged and retains independent consumer known-answer tests.
- Test runner requires `CRYPTO_SRC`/`OOREXX_CRYPTO_SRC`; runtime bundles must source `crypto.cls` from the standalone package when building immutable closures.

## v0.11

- bumps `RuntimeRegistryBuild~RELEASE` to `0.11` while retaining the stable `runtime.registry/0.3` core API contract;
- advances the reference HTTP protocol to `ability.http/0.5`;
- adds `AbilitySchema.cls` with immutable, canonical, enforceable ability JSON-Schema fragments;
- extends `AbilityDescriptor` with immutable `inputSchema` and `outputSchema`, preserving backward-compatible generic-object input and unconstrained output defaults;
- includes schema canonical text in `AbilityProfileRevision~canonicalText`, making schema changes part of profile semantic identity/drift detection;
- extends `ABILITY-PROFILE/1` with optional `ability-input-schema:` and `ability-output-schema:` records using canonical JSON fragments;
- rejects unsupported schema keywords rather than publishing contracts the runtime does not enforce;
- validates ability inputs before dynamic dispatch and returns 422 without invoking the capability on mismatch;
- validates explicit ability outputs against their JSON-safe wire projection and returns 500 on provider contract violation;
- exposes exact input/output schemas through `GET /v1/abilities`;
- generates OpenAPI request/output contracts from the same descriptor-owned schemas;
- emits literal granted custom ability paths in OpenAPI so each custom ability can carry its own exact schema, rather than one path-template operation with ambiguous per-ID bodies;
- adds schema acceptance covering numeric-vs-quoted-string typing, object/array bounds, enum, required/additional-property enforcement, unsupported-keyword rejection, canonical ordering and copy immutability;
- extends HTTP acceptance with 422 pre-dispatch input rejection, profile-specific schema discovery, exact OpenAPI schemas and a 500 output-contract violation probe;
- revalidates the complete current stack against Structured Relation v0.9, HardWorld v0.19, Queue Fabric v0.7, NoSQLServer v0.74, Terminal Machine v0.3.1 and Legal Effect v0.7.

## v0.10

- bumps `RuntimeRegistryBuild~RELEASE` to `0.10` while retaining the stable `runtime.registry/0.3` core API contract;
- advances the reference HTTP protocol to `ability.http/0.4`;
- adds `AbilityApiDescription.cls` and authenticated `GET /v1/openapi.json`;
- emits an OpenAPI 3.2.0 document from the exact immutable Ability Profile generation serving the request, rather than a server-wide/static document;
- advertises only granted query/evaluation paths and only non-reserved abilities in the generic ability path enum;
- makes `/v1/queries` and `/v1/evaluations` the only invocation paths for the reserved `query`/`evaluate` abilities, preventing inline generic dispatch from bypassing materialised-result semantics;
- adds profile-scoped `x-oorexx-profile`, `x-oorexx-abilities`, `x-oorexx-resources`, and `x-oorexx-rules` contract metadata;
- deliberately uses a generic JSON-object request schema where the current Ability Descriptor carries no precise schema, rather than inventing false precision;
- enriches `GET /v1/abilities` with provider-neutral `invoke_uri`, `http_method`, `result_mode`, and `input_schema` fields;
- adds private profile-generation ETags for OpenAPI discovery plus exact `If-None-Match` -> `304 Not Modified`;
- adds profile-isolation acceptance proving a second client with only `echo.custom` sees neither query nor evaluation paths and receives a different ETag.

## v0.9

- bumps `RuntimeRegistryBuild~RELEASE` to `0.9` while retaining the stable `runtime.registry/0.3` API contract;
- adds detached `RuntimeExecutionEvidence` snapshots and `RuntimeEvidenceEnvelope` for exact generation/artifact provenance without lifecycle authority;
- adds `RuntimeLease~executionEvidence` / `~envelope`, plus snapshot and Ability Session/Invocation Context propagation through the already-pinned runtime closure;
- ability invocation evidence remains alias-confined: an ability cannot inspect execution evidence for undeclared runtime aliases;
- adds a 24-assertion execution-evidence lifecycle regression covering ACTIVE->DRAINING observation, detached historical snapshots, rich-value identity, release behavior and authority confinement;
- satisfies Legal Effect v0.7's mandatory Runtime Registry execution-evidence contract and passes its complete runtime-evidence chain with Structured Relation v0.9;
- adds provider-neutral evidence `provenance` projection in `AbilityResultStore`;
- adds a real NoSQLServer v0.74 HTTP query capability using profile-owned logical resources rather than client-authoritative SQL;
- proves real FILE + SNAPSHOT federation (`FEDERATED_TABLE_SCAN`, rows_scanned=5), one-time materialisation, cursor paging and NoSQL execution provenance dereference without re-execution;
- adds a real Terminal Machine v0.3.1 safe TN5250 automation capability exposing snapshot/set-field/press while keeping trusted runtime/network bytes private and nondisplay values masked;
- updates real integration certification to Structured Relation v0.9, HardWorld v0.19, Queue Fabric v0.7, NoSQLServer v0.74 and Terminal Machine v0.3.1;
- adds optional Legal Effect v0.7 bridge/evidence-chain tests to `run_tests.sh`.

## v0.8

- bumps the reference Ability HTTP protocol to v0.3;
- adds `AbilityResultStore.cls` and first-class in-memory materialised query/evaluation resources;
- `POST /v1/queries` and `POST /v1/evaluations` now execute the granted ability exactly once and return `201 Created` plus a stable result URI;
- adds `GET/DELETE /v1/queries/{id}`, `GET /v1/queries/{id}/rows`, `GET/DELETE /v1/evaluations/{id}`, `GET /v1/evaluations/{id}/evidence`, and `GET /v1/evidence/{id}`;
- cursor paging traverses stored rows and never re-invokes the underlying capability;
- materialised results own the exact `AbilitySession` which created them, so result/evidence objects remain bound to the original profile/runtime generation across later code/profile publication;
- result DELETE and TTL expiry release the owned `AbilitySession`, allowing old profile/runtime generations to drain;
- recursively detects evidence-bearing rich objects, retains the live object internally, and exposes a stable evidence reference rather than flattening the object graph;
- evidence identities are scoped by owning result (`qry-...-ev-...` / `eval-...-ev-...`) to prevent cross-result index collisions;
- result/evidence lookup is client-owned; cross-client access is deliberately indistinguishable from not-found;
- adds strict bounded cursor/limit parsing and rejects duplicate/unknown paging parameters;
- adds explicit `context~boolean()` / `AbilityBoolean` so numeric Rexx `1` and `0` remain JSON numbers unless a capability deliberately marks a value as Boolean;
- real structured-relation v0.7 + HardWorld v0.16 HTTP test retains a P1 result across P2 activation, proves the old XML evidence remains dereferenceable, and proves P1 cannot retire until the retained result is released;
- updates the stateful Queue Fabric specimen to supplied v0.3 core semantics; its optional NoSQL projection remains excluded because it explicitly targets NoSQLServer v0.72 while this stack baseline remains v0.71.

## v0.7

- bumps the reference Ability HTTP protocol to v0.2;
- adds generic `POST /v1/abilities/{ability-id}` dispatch for any ability explicitly granted by the active profile;
- keeps `/v1/queries` and `/v1/evaluations` as convenience resources over the same confined invocation contract;
- URL ability IDs are restricted to one unescaped `a-z0-9._-` path segment; arbitrary class/method reflection remains impossible;
- generic invocation still constructs `AbilityInvocationContext` from the selected descriptor, so undeclared runtime aliases remain invisible;
- adds a real Queue Fabric v0.2 capability integration using only `ObjectQueueFabric.cls`;
- client-facing Queue Fabric managers are deliberately constructed without a Runtime Registry reference, preventing queue triggers from escaping the immutable Ability Profile closure;
- queue operations use `context~clientId` as the Queue Fabric principal and a logical Ability Profile data binding (`work-queue`) to resolve the actual queue name;
- proves nested JSON payloads remain live `Directory`/`Array` objects inside Queue Fabric rather than being flattened to strings;
- proves memory-only queue state is generation-local: P1/Q1 retains queued state while global Q2 publication is invisible to P1; P2 explicitly adopts Q2 and its separate empty object universe;
- adds Queue Fabric v0.2 HTTP integration as an optional `QUEUE_FABRIC_ROOT` test target.

## v0.6

- adds `AbilityHttpServer.cls`, a deliberately thin HTTP/1.1 transport above `AbilityRegistry`;
- loopback bind by default with TLS/reverse-proxy termination explicitly outside the ooRexx process;
- authenticates reference `ab1.<key-id>.<secret>` bearer credentials to one environment/client identity;
- every authenticated request acquires exactly one immutable `AbilitySession` and releases it after routing;
- HTTP code receives no Runtime Registry staging/activation/drain/release authority;
- adds `GET /v1/health`, `/v1/abilities`, `/v1/resources`, `/v1/rules`, plus `POST /v1/queries` and `/v1/evaluations`;
- dynamic module dispatch is limited to the fixed `runtimeInvokeAbility(abilityId, restrictedContext)` contract rather than arbitrary reflection;
- `AbilityInvocationContext` exposes only runtime aliases declared by the selected ability descriptor;
- bounded request line/header/body parsing, duplicate-header rejection and deliberate `Transfer-Encoding` rejection avoid ambiguous HTTP framing in the reference listener;
- POST invocation requires `application/json`; malformed/non-object JSON is rejected before dynamic module invocation;
- errors use `application/problem+json` style structured responses;
- adds real loopback socket acceptance and adversarial framing/auth tests;
- adds live HTTP promotion proof over structured-relation v0.7 + HardWorld v0.16: global S2/H2 publication does not change client P1; publishing P2 atomically changes subsequent HTTP requests to S2/H2 while held P1 work remains S1/H1;
- removes new transport/test uses of numeric-coercion `+ 0` shortcuts;
- adds the HTTP suites to mandatory `run_tests.sh` coverage.

## v0.5

- adds `AbilityRegistry.cls`, introducing a second immutable publication boundary above runtime code generations;
- adds `AbilityProfileRevision`, runtime/data/rule bindings and model-neutral ability descriptors;
- profile staging atomically captures and retains one exact `RuntimeSnapshot` for the profile generation's warm lifetime;
- runtime upgrades no longer silently change an already-active client profile; a replacement profile revision must be staged/published to adopt the new runtime closure;
- ability-profile rollback is independent of global runtime rollback;
- adds strict `ABILITY-PROFILE/1` parsing/loading and canonical profile text;
- rejects semantic drift when the same `client/profile@revision` identity is re-used with changed configuration;
- adds read-only `AbilityGenerationView` and request-scoped `AbilitySession` objects;
- seals Runtime Registry lifecycle authority behind read-only `RuntimeGenerationView` objects;
- seals `RuntimeModuleContext~releaseDependencies()` behind an internal registry authority token;
- activation now aborts if the old generation's `runtimeQuiesce()` fails, leaving the old route ACTIVE and the candidate READY;
- adds adversarial regressions for generation lifecycle access, premature dependency release and quiesce-failure publication;
- runtime acceptance suite now has 77 assertions;
- adds eight-held-session + 4,000-post-publication Ability Registry concurrency probe;
- updates real structured-relation integration to the supplied v0.7 tree (15 plugin source units, 16 bundle units, 9,898 generated lines, 17 local requires bound);
- keeps real HardWorld v0.16 generation/self-test proof and rich-source dependency composition;
- adds real-stack Ability Registry proof: P1 pins structured S1 + HardWorld H1, global runtime advances to S2/H2, P1 remains unchanged, P2 adopts S2/H2;
- preserves rich `RichBusinessFact` evidence into HardWorld while `BIG_UPSELL` remains `PROHIBITED` and `WARNING` remains `REQUIRED`;
- retains v0.1-v0.4 lifecycle, crypto, signed-manifest, dependency and bundle semantics.

## v0.4

- first real rules-engine generation specimen using `virtual_ryta_hardworld_v0.16`;
- bundles the minimal live HardWorld authority closure into one generation-private ooRexx package;
- HardWorld lifecycle self-test exercises the adversarial extreme-scoring safety case;
- two complete HardWorld generations with identical public class names coexist and live-reload correctly;
- same immutable HardWorld source loaded in TEST and PROD receives distinct package/class object universes;
- structured-relation integration harness made version-neutral;
- real HardWorld -> structured-source dependency pinning and rich-evidence composition proof;
- fixes and regression-tests a classic Rexx generated-source caller-variable/abuttal contamination trap.

## v0.3

- deterministic generation-private multi-file bundle builder;
- local `::REQUIRES` closure binding with provenance markers;
- structured-relation rich-object integration probe.

## v0.2

- signed artifact manifests, trust policy and Ed25519/SHA-512 verifier reference;
- immutable dependency-generation closure;
- duplicate-snapshot and quarantined-dependency lease hardening.

## v0.1

- live/test/prod generation registry;
- stage, self-test, atomic activation, drain, retire, rollback and release;
- request leases and coherent multi-module snapshots.

## v0.13

- advances the reference HTTP protocol to `ability.http/0.7`;
- adds trusted `AbilityHttpRouter~routePinnedAbility` for canonical dynamic Ability execution against an already-held generation-pinned `AbilitySession`;
- reuses the existing private invocation engine, preserving input/output schema validation, optional WLU admission/settlement and runtime evidence rather than duplicating those rules;
- rejects `query` and `evaluate` on the pinned inline path so materialization semantics remain canonical;
- adds live-generation acceptance proving a held v1 session executes v1 after v2 activation while a normal route executes v2;
- rejects released sessions and path/ability mismatches.


# ooRexx Runtime Registry v0.14

## v0.14 current WLU qualification

v0.14 is a compatibility/qualification release. It keeps the core `runtime.registry/0.3`, reference `ability.http/0.7`, and optional `ability.wlu/0.1` contracts unchanged while requalifying the existing dynamic WLU bridge against `oorexx_work_load_units_v0.12` / `work.load.units/0.12`.

The bridge continues to obtain the WLU API version from the configured authority and publishes that exact value through authenticated Ability discovery. Runtime Registry does not masquerade a current WLU authority as an older API. The v0.14 acceptance therefore expects `work.load.units/0.12` and retains the existing side-effect-safe admission, actual-work settlement, detached execution evidence, and HTTP 429-before-provider-invocation semantics.

## v0.13 pinned in-process Ability dispatch

v0.13 adds `AbilityHttpRouter~routePinnedAbility(session, abilityId, request)` for trusted in-process callers that already hold an `AbilitySession`. It routes dynamic abilities through the same schema, WLU admission, runtime invocation, settlement and output-schema engine as HTTP while retaining the caller's exact Ability generation lease. It deliberately refuses `query` and `evaluate` aliases so materialized query/evaluation semantics cannot be bypassed. The Runtime Registry core API remains `runtime.registry/0.3`; the reference Ability HTTP API advances to `ability.http/0.7`.


A deliberately thin live-code microkernel plus client ability-generation layer for the HardWorld / federated-data / REST server stack.

The permanent framework now owns two independent publication boundaries:

```text
RuntimeGeneration -> AbilityGeneration -> AbilitySession
```

The first answers **which immutable code closure is live**. The second answers **which exact code/rule/data closure a particular client chatbot is allowed to use**. A request receives an `AbilitySession` and remains pinned to that ability generation for its lifetime.

The design rule is:

> **Code upgrades and client-configuration upgrades are separate atomic operations. Neither is allowed to silently change an in-flight request.**

## v0.12: optional Work Load Unit admission and execution accounting

v0.12 advances the reference HTTP protocol to `ability.http/0.6` and consumes the separate ooRexx Work Load Units authority through an optional `AbilityWLUBridge`. Runtime Registry does **not** own tariffs, balances, capacity buckets or throughput policy, and `AbilityDescriptor` remains an immutable authority/schema/runtime contract rather than a pricing authority. The Runtime Registry core API remains `runtime.registry/0.3`.

The execution order is deliberately side-effect safe:

```text
authenticate + resolve immutable AbilitySession
        -> validate request schema and handler configuration
        -> trusted WLU planner emits forecast facts
        -> WLU authority quotes/reserves/admit-verifies proof
        -> only then invoke dynamic capability
        -> capability emits native meter facts
        -> settle actual work or release an unused reservation
        -> return/materialise business result plus detached execution.wlu metadata
```

A WLU entitlement/capacity/throughput refusal is returned as HTTP `429 Too Many Requests`; `Retry-After` is propagated when supplied by WLU. Dynamic capability code receives only the restricted metering surface on `AbilityInvocationContext` (`wluManaged`, `wluReservationId`, `wluScope`, `meterFact`). It never receives the WLU authority, account, bucket, rate card, tariff, proof secret or raw reservation object.

Accounting follows **performed work**, independently of business success. A provider rejection before any meter fact releases the reservation and spends zero; work reported before a later 422/500/503 is still settled. WLU evidence is attached as execution metadata and may be retained with a materialised result, but is never inserted into business rows or the provider result object. Successful materialisation, later paging and evidence retrieval do not execute or meter the capability again.

The WLU dependency is optional. `AbilityHttpServer.cls` does not `::requires WorkLoadUnits.cls`; only `AbilityWLU.cls` owns that dependency. With no bridge configured, the HTTP/result path remains the v0.11-compatible non-WLU path. OpenAPI advertises the possible 429 outcome but contains no live tariff, balance or capacity values.

The v0.12 release line keeps the v0.11.1 standalone-crypto boundary: Runtime Registry contains no vendored `src/crypto.cls`; cryptographic primitives come from `oorexx_crypto_v0.1`.

## v0.11: immutable ability schemas and enforced contracts

v0.11 adds `AbilitySchema.cls` and advances the reference HTTP protocol to `ability.http/0.5`. `AbilityDescriptor` now owns immutable input and output JSON-Schema fragments. Schema objects are copied on ingress/egress, have deterministic canonical text, and participate in `AbilityProfileRevision~canonicalText`, so changing an ability contract is a semantic profile change rather than transport metadata drift.

The runtime deliberately implements a bounded enforceable JSON-Schema subset instead of accepting keywords it does not enforce. Supported validation keywords are `type`, `properties`, `required`, `additionalProperties`, `items`, `enum`, `const`, numeric minimum/maximum, string min/max length, and array min/max items; `title` and `description` are annotations. Unsupported keywords are rejected when the profile/schema is constructed. The ooRexx JSON parser preserves numeric JSON values separately from quoted `.JSONString` values, so an integer schema correctly rejects `"2"` while accepting `2`.

Input validation occurs after JSON parsing but **before** dynamic capability dispatch. A mismatch returns HTTP 422 and the capability is not invoked. Explicit output schemas are validated against the JSON-safe projected output after the dynamic handler returns; a mismatch is treated as a server-side contract violation and returns HTTP 500. Legacy descriptors remain compatible: their default input schema is a generic JSON object and their default output schema is unconstrained.

`GET /v1/abilities` now exposes both exact `input_schema` and `output_schema`. OpenAPI generation uses those same descriptor-owned schemas. Reserved `query`/`evaluate` operations receive exact request schemas on their canonical materialised endpoints. Custom abilities are emitted as literal granted paths such as `/v1/abilities/echo.custom`, rather than one ambiguous templated operation whose body schema would vary with a path parameter. Thus one immutable schema object is the source of truth for runtime validation, discovery and OpenAPI.

## v0.10: profile-scoped machine-readable API contract

v0.10 adds `AbilityApiDescription.cls` and advances the reference HTTP protocol to `ability.http/0.4`.  An authenticated client can request `GET /v1/openapi.json` and receives an OpenAPI **3.2.0** description generated from the exact immutable `AbilitySession`/profile generation serving that request.  The document is therefore client/profile scoped rather than a server-wide catalogue.

The generated contract includes only granted fixed operations and authenticated profile extensions for the exact ability generation, logical resources, rule bindings, runtime generation IDs and artifacts. v0.11 supersedes v0.10's generic custom-ability OpenAPI path with exact literal granted ability paths so each can carry its own schema.  `query` and `evaluate` have one canonical invocation path (`/v1/queries` and `/v1/evaluations`); `/v1/abilities/query` and `/v1/abilities/evaluate` are deliberately rejected so callers cannot bypass materialised-result semantics.

v0.10 deliberately used generic JSON-object schemas because descriptors did not yet carry precise contracts. v0.11 replaces that temporary limitation with immutable descriptor-owned input/output schemas and enforcement.

The OpenAPI response is authenticated, returns `Cache-Control: private, no-cache`, `Vary: Authorization`, and an ETag bound to `client/profile/revision/ability-generation`.  An exact `If-None-Match` returns `304 Not Modified`; different client/profile generations produce different ETags.

v0.9 retains the v0.1-v0.8 lifecycle, signed-manifest, bundle, Ability Registry, HTTP and materialised-result semantics, then adds two current-stack boundaries: **detached runtime execution evidence** and **configuration-driven federated/automation abilities**. A lease can now prove exactly which environment/module/generation/artifact executed work without exposing lifecycle authority, while Ability Profiles can expose logical NoSQL resources and safe automation facades without handing chatbots raw SQL, raw terminal transport, or the Runtime Registry.

## Materialised REST result lifecycle

The reference HTTP API is now `ability.http/0.7`. Query/evaluation creation is resource-oriented:

```text
POST /v1/queries
   -> execute granted query ability once
   -> 201 Created
   -> /v1/queries/qry-...

GET /v1/queries/{id}
GET /v1/queries/{id}/rows?cursor=c.N&limit=N
DELETE /v1/queries/{id}

POST /v1/evaluations
   -> execute HardWorld/other evaluation once
   -> 201 Created
   -> /v1/evaluations/eval-...

GET /v1/evaluations/{id}
GET /v1/evaluations/{id}/evidence
DELETE /v1/evaluations/{id}

GET /v1/evidence/{evidence-id}
```

`AbilityResultStore` keeps the raw materialised value and the owning `AbilitySession`. Evidence-bearing objects such as `RichBusinessFact` are retained as live ooRexx objects; the JSON representation contains a stable evidence reference and a compact scalar projection. Dereferencing the evidence returns bounded value/source metadata while the original rich source object remains retained internally.

The ownership chain is therefore:

```text
RuntimeGeneration
    -> AbilityGeneration
        -> AbilitySession
            -> AbilityMaterializedResult
                -> rich evidence objects
```

Publishing a newer runtime/profile generation does not reinterpret an existing result. Deleting the result or allowing its TTL to expire releases its owned session and permits old generations to drain. Result/evidence identifiers are client-owned and are not bearer credentials.

Cursor paging is over the stored row array only. It never invokes the dynamic capability again. The reference cursor is deliberately local/opaque (`c.<offset>`) with a maximum page size of 200.

Because Rexx represents `.true`/`.false` as `1`/`0`, dynamic capability code must use `context~boolean(value)` for values intended to be JSON Boolean. Raw numeric 1 and 0 are preserved as numbers.

## Runtime execution evidence and rich envelopes

`RuntimeLease~executionEvidence` returns a detached `RuntimeExecutionEvidence` snapshot containing the environment, module, generation, artifact, API identity and generation state observed at that instant. The evidence object contains no lifecycle methods and does not retain the mutable generation.

```text
RuntimeLease
    |
    +-- executionEvidence -> detached snapshot
    |       environment
    |       module/generation/artifact
    |       ACTIVE / DRAINING / ... at capture time
    |
    +-- envelope(richValue, locator)
            -> RuntimeEvidenceEnvelope
               exact rich value identity
               detached runtime evidence
               stable locator
```

This distinction matters during live replacement: an old lease can observe `DRAINING` after publication of a replacement, while an evidence snapshot captured before publication remains `ACTIVE` forever as historical evidence. Releasing the lease prevents minting new evidence but does not mutate already-issued evidence/envelopes.

`RuntimeSnapshot`, `AbilitySession`, and `AbilityInvocationContext` expose the same evidence operation only through the already-pinned module closure. The invocation context applies the normal required-alias confinement: a query granted only `data` can obtain the exact `data` execution evidence but receives no evidence for an undeclared `rules` alias. It never reacquires the globally current generation.

This detached-evidence contract was introduced for Legal Effect v0.7. The current v0.12 integration revalidates it against Legal Effect v0.10.1:

```text
Structured Relation rich fact
    -> RuntimeEvidenceEnvelope
    -> LegalFact (original native source retained)
    -> Legal Effect compiled semantic generation
    -> LegalRuntimeSemanticBindingEvidence
    -> LegalEffectExecutionEnvelope
```

Source evidence, legal compilation/semantic evidence, and runtime execution evidence therefore remain distinct and independently inspectable.

## Runtime lifecycle

```text
VERIFIED -> LOADED -> READY -> ACTIVE -> DRAINING -> RETIRED -> RELEASED
                       |          ^                    |
                       |          +------ rollback ----+
                       +-> QUARANTINED
```

Every runtime generation is loaded with `.Package~new()` using a unique registry URI. Registry identity is a generation object, never a globally resolved class name.

A request/module obtains a `RuntimeLease` or `RuntimeSnapshot`; a later activation cannot change the code objects reachable through that already-issued lease/snapshot.

## Ability lifecycle

An `AbilityProfileRevision` describes one immutable client-facing configuration:

- runtime bindings, optionally pinned to exact artifact IDs;
- callable ability descriptors;
- logical federated-data bindings;
- HardWorld/rule bindings;
- client/profile/revision identity.

Staging a profile atomically captures one runtime snapshot and owns those runtime leases for the whole warm lifetime of the ability generation:

```text
Runtime Registry
   data-provider S1 ACTIVE
   hardworld     H1 ACTIVE
          |             |
          +------ atomic snapshot ------+
                                        |
                               AbilityGeneration P1
                               client=acme-chatbot
                               revision=1
                                        |
                                request sessions
```

If the global runtime later activates S2/H2, P1 does **not** change:

```text
Global runtime:        S2 + H2
Ability P1:            S1 + H1
Ability P2 staged now: S2 + H2
```

Only publishing P2 changes new sessions for that client. Existing P1 sessions remain pinned to P1.

A retired ability generation remains warm for rollback and therefore deliberately retains its runtime snapshot. Releasing the ability generation releases those runtime leases.

## Dynamic ability profile format

v0.5 adds a strict canonical file form:

```text
ABILITY-PROFILE/1
profile-id: customer-bot
revision: 1
client-id: acme

description: customer service profile
runtime: data|structured.relation|structured:artifact:v1
runtime: rules|rules.hardworld|hardworld:artifact:v1
ability: query|QUERY|true|data|Read bounded federated data
ability: evaluate|RULE_EVALUATION|true|rules,data|Evaluate proposed action

data: orders|data|orders|READ
rule: customer-policy|rules|customer-service
```

`AbilityProfileParser` / `AbilityProfileLoader` reject:

- unknown fields;
- duplicate singleton fields;
- duplicate aliases/ability/data/rule names;
- unresolved runtime aliases;
- malformed booleans/field counts;
- re-use of the same `client/profile@revision` identity with changed canonical semantics.

Set-like declarations are canonicalised before identity comparison, so harmless declaration order does not create a different profile.

The current profile identity protection is an in-process canonical pin. Ability-profile signing is deliberately not claimed yet; the existing runtime signed-artifact verifier is the natural model for a later signed control-plane format.

## Runtime authority boundary hardening

v0.5 seals three authority defects that matter before client-facing code exists.

### Read-only generation views

Raw `RuntimeGeneration` lifecycle objects no longer cross normal registry boundaries. Staging, lookup, active-generation access and lease generation inspection expose `RuntimeGenerationView` objects containing metadata/diagnostics only.

A consumer cannot obtain a generation and invoke lifecycle methods such as drain/release directly.

`AbilityRegistry` follows the same rule with `AbilityGenerationView`; an `AbilitySession` does not expose its mutable generation object.

### Dependency leases cannot be dropped by loaded code

`RuntimeModuleContext~releaseDependencies()` now requires a registry-internal authority token. A dynamically loaded dependent module cannot prematurely drop its lifetime dependency closure.

This preserves the invariant:

> **A live/warm generation keeps every generation in its declared dependency closure alive until the owning generation is released.**

### Failed quiesce aborts activation

Activation no longer publishes a candidate if the previous active generation's `runtimeQuiesce()` fails.

The old route stays ACTIVE. If the candidate had already executed `runtimeStart()`, the registry stops that candidate and leaves it READY rather than publishing a half-transitioned runtime.

## RuntimeBundleBuilder

Real ooRexx components are often several `.cls` files linked by `::REQUIRES`. Ordinary named package reuse is unsafe for independently reloadable code closures.

`RuntimeBundleBuilder` deterministically creates one generation-private source closure:

```text
RichSourceCore.cls
XmlNativeSource.cls       ::requires RichSourceCore.cls
XmlRelationAdapter.cls    ::requires XmlNativeSource.cls
...
        |
        v
RuntimeBundleBuilder
        |
        | local ::REQUIRES become provenance markers
        | all source units remain in canonical order
        v
one immutable bundle source
        |
        v
RuntimeRegistry -> .Package~new(unique generation URI, bundle source)
```

External/stable `::REQUIRES` directives remain intact. The generated bundle source is the artifact that is hashed/signed/promoted.

## Immutable runtime dependency closures

A staged runtime generation atomically snapshots all active declared dependencies and owns those leases for its lifetime:

```text
Capability gen17
    +----> Rules gen42
```

Activating Rules gen43 does not mutate Capability gen17. A replacement capability generation must be staged to bind gen43.

Additional safety properties include:

- duplicate requested module IDs acquire one lease;
- duplicate dependency declarations are rejected;
- failed prepare/self-test candidates release dependency leases immediately;
- old dependency generations cannot be released while a live/warm generation owns them;
- dependency sets are captured through one atomic multi-module snapshot.

## Signed runtime artifacts

`RUNTIME-MANIFEST/1` and the optional Ed25519 reference verifier remain available.

Verification order is deliberately cheap-to-expensive:

1. signer exists;
2. signer is not revoked;
3. signer is authorised for environment/module kind;
4. field formats are valid;
5. source SHA-512 matches;
6. Ed25519 verifies.

Trust policy is rechecked on verification-cache hits, so revocation still wins.

Cryptography is supplied by standalone `oorexx_crypto_v0.1`; Runtime Registry no longer vendors a private `crypto.cls`. The registry uses only its SHA-512 and Ed25519 paths, both checked here again as consumer integration known-answer tests. Private keys are expected to remain outside the live server process.

## Real structured-relation v0.9 proof

The v0.5 integration harness discovers the plugin's complete top-level `src/*.cls` closure and reads its declared version dynamically.

With the supplied `structured_relation_plugin_v0.9` tree the test builds:

```text
plugin_version=0.9
source_units=15
bundle_units=16
bundle_lines=10194
local_requires_bound=17
```

A dynamically loaded generation returns a real XML-derived `RichBusinessFact` whose typed value, lexical value, evidence-bearing state, native XML node, source path and document identity remain reachable across the registry boundary.

This preserves the stack's non-flattening rule: the relational/HTTP layer may project a simple representation, but the internal source/evidence object remains rich.

## Real HardWorld v0.19 proof

The HardWorld integration bundles the minimal authority closure:

```text
HardWorld.cls
RYTAStateRules.cls
VirtualRYTA.cls
RYTABasicScoring.cls
RYTATestExtremeScoring.cls
+ runtime lifecycle wrapper
```

Its generation self-test deliberately gives:

```text
BIG_UPSELL preference = +1,000,000
WARNING    preference = -1,000,000
```

Staging fails unless the real engine still returns:

```text
BIG_UPSELL -> PROHIBITED
WARNING    -> REQUIRED
```

Two complete HardWorld generations with the same public class names coexist as distinct package/class universes. A held request remains on generation A after B becomes active; new requests receive B.

## HardWorld + rich-source dependency proof

A HardWorld generation can declare `structured.relation` as an exact runtime dependency. During preparation it receives that exact module generation through `RuntimeModuleContext`.

The test obtains a native XML `RichBusinessFact`, promotes only the scalar value into a HardWorld fact, and retains the original rich object as evidence.

Upgrade sequence:

```text
structured S1 ACTIVE
        |
        +--- dependency lease ---> HardWorld H1 ACTIVE

activate structured S2
        |
        +--- S1 DRAINING, still pinned by H1
        +--- H1 still calls S1

stage/activate HardWorld H2
        |
        +--- H2 pins S2
        +--- held H1 still pins H1 -> S1
```

Retired-but-warm H1 continues pinning S1 for rollback. Only releasing H1 releases its dependency snapshot.

## Real Ability Registry stack proof

v0.5 composes the two real modules behind an actual client profile:

```text
AbilityProfile P1
  data  -> structured.relation S1
  rules -> HardWorld H1
```

P1 can query the rich XML fact and evaluate the HardWorld safety decision. Then the global runtime activates S2/H2.

P1 continues seeing S1/H1. A newly staged P2 captures S2/H2 and, once published, new client sessions receive P2.

The proof confirms:

- `BIG_UPSELL` remains `PROHIBITED` despite +1,000,000 preference;
- `WARNING` remains `REQUIRED`;
- the XML evidence path remains `/Order[1]/Quantity[1]`;
- a profile generation can directly pin S1/H1 while H1 independently pins S1;
- layered release semantics keep S1 alive until both profile and HardWorld ownership are gone.

This is the boundary the later HTTP layer should use. HTTP should authenticate a client, call `AbilityRegistry~acquire(environment, clientId)`, and operate only through the resulting `AbilitySession`. The HTTP request path should not receive Runtime Registry lifecycle authority.

## Ability HTTP Server v0.3

`AbilityHttpServer.cls` is the first transport above the immutable ability-generation boundary. The intended deployment is:

```text
Internet / chatbot
       |
TLS reverse proxy / certificate / connection policy
       |
private loopback HTTP
       |
AbilityHttpServer
       |
bearer credential -> environment/client
       |
AbilityRegistry~acquire(...)
       |
AbilitySession
       |
exact profile/runtime closure
```

The reference listener binds `127.0.0.1` by default and deliberately implements a conservative HTTP/1.1 subset: one request per connection, `Connection: close`, bounded request line/header/body sizes, duplicate-header rejection, `Content-Length` framing and no `Transfer-Encoding`. A normal SSL reverse proxy is expected to own Internet-facing TLS, HTTP connection management and additional rate/connection policy.

Current resources are:

```text
GET    /v1/health
GET    /v1/abilities
GET    /v1/resources
GET    /v1/rules
POST   /v1/queries
GET    /v1/queries/{id}
GET    /v1/queries/{id}/rows?cursor=c.N&limit=N
DELETE /v1/queries/{id}
POST   /v1/evaluations
GET    /v1/evaluations/{id}
GET    /v1/evaluations/{id}/evidence
DELETE /v1/evaluations/{id}
GET    /v1/evidence/{evidence-id}
POST   /v1/abilities/{ability-id}
```

POST ability requests require `application/json` and a JSON object body. Errors are returned as structured `application/problem+json` responses.

`POST /v1/abilities/{ability-id}` is the extension point for non-query/non-rule capabilities. `{ability-id}` is one unescaped URL-safe segment (`a-z0-9._-`). The router still resolves the ID through the active `AbilityProfileRevision`; an ungranted ability receives 403, and the caller cannot supply a class or method name.

The supplied credential store is intentionally a small in-memory reference mechanism using bearer tokens of the form `ab1.<key-id>.<secret>`. It demonstrates the authority boundary; it is not yet a persisted/rotating production credential store.

### Ability invocation confinement

HTTP never invokes an arbitrary class/method name supplied by the caller. The router resolves a granted `AbilityDescriptor`, creates an `AbilityInvocationContext`, and calls only:

```text
runtimeInvokeAbility(abilityId, restrictedContext)
```

The context exposes only aliases declared in that ability's `requiredAliases`. A profile may contain both `data` and `rules`, but a `query` ability declaring only `data` cannot retrieve the rules module through the context. An `evaluate` ability may explicitly declare both.

### Live HTTP promotion proof

The real-stack HTTP test keeps one listener running while the underlying runtime changes:

```text
P1 -> structured S1 + HardWorld H1
          |
          | globally activate S2/H2
          v
HTTP through P1 still -> S1/H1
          |
          | stage + publish P2
          v
next HTTP request -> S2/H2
```

Held P1 sessions continue using the complete old closure. The HardWorld response still proves `BIG_UPSELL -> PROHIBITED`, while the rich XML evidence remains reachable at `/Order[1]/Quantity[1]`.

## Queue Fabric v0.8.2 ability proof

The optional `QUEUE_FABRIC_ROOT` integration bundles the supplied `ObjectQueueFabric.cls` into a normal generation-private runtime capability and exposes two profile-granted abilities through the generic HTTP path:

```text
queue.submit
queue.depth
```

The profile contains a logical data binding:

```text
work-queue -> runtime alias queue -> resource WORK
```

The dynamically loaded queue wrapper resolves `WORK` through `AbilityInvocationContext~dataBinding()` and uses `context~clientId` as the Queue Fabric principal. Queue ACLs therefore remain meaningful in addition to the outer Ability Profile grant.

For the client-facing proof the `ObjectQueueManager` is intentionally created with `runtimeRegistry = .nil`. This is a hard separation from Queue Fabric's useful but different `QueueRegistryTriggerTarget`, which deliberately resolves the currently active runtime generation at trigger time. Such system wiring must be configured as an explicit infrastructure capability rather than giving a chatbot-facing queue a route around its immutable Ability Profile closure.

The HTTP test submits nested JSON and proves the queued payload remains a live ooRexx object graph (`Directory` containing an `Array` containing another `Directory`). It then publishes Queue Fabric Q2 globally while P1 remains active:

```text
P1 -> Q1, depth=1
         |
         | publish Q2 globally
         v
P1 -> Q1, depth=1
         |
         | publish P2
         v
P2 -> Q2, depth=0
```

A held P1 session can still inspect the original Q1 rich payload after P2 becomes active. This is the same generation-isolation rule applied to stateful capability objects. Durable queue-state migration/recovery is deliberately a separate later exercise.

The client-facing registry integration deliberately uses only the object-native `ObjectQueueFabric.cls` core from the v0.8.2 package (queue API 0.8), so queue state and rich payloads remain inside the exact profile-pinned queue generation. Queue Fabric's optional NoSQL projections are deliberately not used as an escape route from the client Ability Profile.

## NoSQLServer v0.75 logical-resource query proof

The optional `NOSQLSERVER_ROOT` integration bundles the real NoSQLServer v0.75 engine into a generation-private capability. The client does **not** supply arbitrary SQL. Instead the Ability Profile publishes logical data bindings such as:

```text
orders          -> table:orders
customers       -> table:customers_snapshot
customer-orders -> sql:<server-owned read-only federated SELECT>
```

The chatbot supplies the logical resource and bounded projection/order/limit intent. The capability validates identifiers and limits, resolves the trusted descriptor, then executes NoSQLServer internally. A real FILE + SNAPSHOT join is exercised through HTTP and reports `FEDERATED_TABLE_SCAN` with `rows_scanned=5`.

The query is materialised exactly once; subsequent REST paging and evidence dereference do not re-execute NoSQLServer. Execution metadata is exposed as provider-neutral provenance evidence containing the NoSQLServer release, logical resource, access path, rows scanned, row count and snapshot generation when present. Raw-SQL-only requests and identifier-shaped injection attempts are rejected.

NoSQLServer v0.75 retains the native ooRexx SQLite/GeoPackage reader which replaced the historical external helper; the registry treats that as provider implementation detail rather than changing the Ability contract.

## Terminal Machine v0.5 safe-automation proof

The optional `TERMINAL_MACHINE_ROOT` integration loads the real TN5250 implementation but exposes only `TN5250AutomationSession` through granted abilities:

```text
terminal.snapshot
terminal.set-field
terminal.press
```

The trusted `TN5250RuntimeSession` remains private inside the dynamic module. The safe automation facade cannot call raw network-feed/drain methods, and REST never receives password-bearing outbound transport bytes. Nondisplay fields are returned masked; `terminal.press` reports only a safe `transport_output_pending` flag plus a detached screen snapshot.

This demonstrates the same capability rule used elsewhere: **useful action does not imply raw transport authority**.

## Legal Effect v0.10.1 runtime-evidence proof

The optional `LEGAL_EFFECT_ROOT` integration exercises Legal Effect's Runtime Registry bridge and complete runtime-evidence chain against the current registry. Legal Effect v0.10.1 is validated with Structured Relation v0.9 and HardWorld v0.19, including compiler/source-verification boundaries, Ed25519 source-authority verification, authority/conflict rules and HardWorld promotion compatibility.

A legal runtime binding records both the compiled legal semantic identity and the detached Runtime Registry evidence which proves what code generation executed it. Upstream structured-analysis runtime evidence remains recoverable from `LegalFact` evidence after both runtime leases are released.

## TEST / LIVE / PROD

Environments remain ordinary registry scopes:

```text
                 immutable signed bundle A
                    /       |       \
                   /        |        \
                TEST      LIVE      PROD
                 pkg1      pkg2      pkg3
```

Promotion loads the same immutable artifact into a target-local package universe. No test object, cache or class instance is moved into production.

Ability profiles are similarly staged/activated per environment, allowing a client to run profile revision N in LIVE and N-1 in PROD without altering either underlying artifact.

## Run

With ooRexx 5.3.0 r13196 installed and the standalone crypto package available:

```bash
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src bash run_tests.sh
```

The base suite covers:

1. runtime lifecycle/rollback/class isolation and authority-boundary attacks;
2. eight-activity + 4,000-post-publication runtime concurrency;
3. immutable dependency closure and premature-release attack;
4. multi-file bundle/live-reload behaviour;
5. ability-profile parser/canonicalisation;
6. ability-generation lifecycle, rollback and profile-drift rejection;
7. eight-activity + 4,000-post-publication ability concurrency;
8. materialised result/evidence identity, ownership and release acceptance;
9. live reload demo;
10. RFC 8032 Ed25519 and SHA-512 known-answer probes;
11. signed-manifest tamper/trust/cache/revocation suite;
12. real loopback HTTP authentication/routing/framing/result-lifecycle acceptance.

Real integrations are enabled by supplying roots:

```bash
CRYPTO_SRC=/path/to/oorexx_crypto_v0.1/src \
STRUCTURED_RELATION_ROOT=/path/to/structured_relation_plugin_v0.9 \
HARDWORLD_ROOT=/path/to/virtual_ryta_hardworld_v0.19 \
QUEUE_FABRIC_ROOT=/path/to/oorexx_queue_fabric_v0.8.2 \
NOSQLSERVER_ROOT=/path/to/nosqlserver_v0.75 \
WLU_ROOT=/path/to/oorexx_work_load_units_v0.2.1 \
TERMINAL_MACHINE_ROOT=/path/to/oorexx_terminal_machine_v0.5 \
LEGAL_EFFECT_ROOT=/path/to/legal_effect_v0.10.1 \
bash run_tests.sh
```

That additionally exercises:

- real structured-relation bundle integration;
- real HardWorld v0.19 bundle/live-generation integration;
- HardWorld -> structured rich-evidence dependency pinning;
- real client ability profile over both modules;
- one live HTTP listener across S1/H1 -> S2/H2 runtime publication and P1 -> P2 ability publication;
- Queue Fabric v0.8.2 as a generic profile-granted HTTP capability, including non-flattened object payload and Q1/P1 -> Q2/P2 state isolation;
- NoSQLServer v0.75 as a profile-configured logical federated-data query capability with materialised paging and provenance evidence;
- WLU v0.2.1 as an optional admission/accounting authority with 429-before-side-effects and actual-work settlement;
- Terminal Machine v0.5 through its AI/operator-safe TN5250 automation facade without raw transport authority;
- Legal Effect v0.10.1 Runtime Registry bridge and rich runtime-evidence chain.

## Deliberately not in v0.12

- TLS termination inside the ooRexx process (expected at the reverse proxy);
- persisted/rotating customer credential store;
- tariff/rate-card/balance ownership inside Runtime Registry or `AbilityDescriptor`;
- a hard WLU dependency for non-WLU deployments;
- arbitrary chatbot-supplied SQL as a default query surface;
- raw terminal transport/network bytes on the chatbot ability surface;
- the full JSON Schema vocabulary: v0.11 accepts only the subset it actually enforces;
- MCP/model-specific tool adapters;
- signed ability-profile control-plane artifacts;
- persistent artifact/profile catalogue;
- persisted trust-store/key-rotation format;
- online/private-key signing;
- native accelerated crypto verifier;
- worker-process containment for native/untrusted code;
- physical ooRexx package unload guarantees.

Those remain layers above or beside this small registry/ability/HTTP substrate.


## Shared crypto dependency (v0.11.1)

Set `CRYPTO_SRC` (or `OOREXX_CRYPTO_SRC`) to `oorexx_crypto_v0.1/src` when running Runtime Registry. The package deliberately contains no `src/crypto.cls`; this prevents Runtime Registry, Queue Fabric and WLU from drifting onto independent copies. Runtime bundles that include `RuntimeCryptoVerifier.cls` must include the authoritative `crypto.cls` from that package in their immutable source closure.

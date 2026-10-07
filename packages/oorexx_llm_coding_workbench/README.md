# ooRexx LLM Coding Workbench v0.1-dev13

This is the coding lane:

```text
specification/challenge
  -> inspect local Semantic Source Control objects
  -> Luna chooses one semantic coding action
  -> Intention Service policy / READY / COMMIT
  -> Development Desk mutation
  -> materialise
  -> compile/test evidence
  -> repair or REPORT
```

The workbench does not own Semantic Source Store/SCCD, Development Desk,
Intention Service, Coding Intention, API Client, or the language runtime.  It
consumes those authorities.

## Local SSCS access - no website required

The dev7 local runner remains part of this package:

- `tools/run_local_sscs.sh` - one local Development Desk action per invocation.
- `tools/run_local_sscs_session.sh` - persistent line-oriented local session.

Both construct the real in-process chain:

```text
SemanticSourceStore
  -> SemanticSourceMcpDirect
  -> SemanticSourceDevelopmentDesk
```

No browser, Wire UI, HTTP listener, or HTTPS MCP server is required.  Runtime
roots are explicit and `SSCS_ROOT/test` is rejected so a compile-only database
stub cannot masquerade as a live backend.

## Structured coding - no flattening

Semantic class/method objects, model actions, method bodies, compiler/test
results, and Coding Intention evidence remain structured objects.  A multiline
method body is not converted into command prose before Intention Service.
Controller-owned package ID, member path, actor, and project identity cannot be
replaced by the model.

## Coding Intention dev13 integration

Dev11 consumes `coding_intention_steps_v0.1-dev13` as its current
language-knowledge authority.

Coding Intention vendors its own Intention Service line, so the workbench does
not load that package into the same runtime activity as the separately selected
Intention Service.  Instead `tools/export_coding_intention_catalogue.rex` asks
the real dev13 `RexxLanguageKnowledge` object for its knowledge in a separate
ooRexx activity.  The resulting structured projection contains:

- 38 semantic operations;
- 7 language skills;
- 5 class-contract families;
- method contracts with exact form, result type, package, and evidence.

Environment qualification regenerates the projection from the actual dev13
package and requires byte equality with
`config/coding_intention_dev13_rexx_catalogue.json`.

### Runtime interrogation evidence

`LlmRuntimeEvidenceRegistry` carries controller-owned runtime witnesses.  An
observed value records:

- actual `value~class~id`;
- safe planning shape (`DIRECTORY`, `ARRAY`, `TABLE`, `SET`, `LIST`, etc.);
- confidence 100;
- explicit provenance.

A runtime witness is never supplied by Luna.

### Method hallucination gate

`SEND_MESSAGE` is now renderable only when the workbench has evidence for the
message:

1. a live runtime witness reports `hasMethod(message)`; or
2. a Coding Intention dev13 class contract contains that method.

Thus an observed Directory permits `items`, while `frobnicate` is rejected
before source exists.  A semantically constructed Directory can also use the
exported `Directory.items` contract without inventing a spelling.

Only no-argument message sends are rendered in this increment.  Argument-bearing
message sends remain closed until their operands have a first-class structured
contract.

### Shape gate

`GET_NAMED_MEMBER` follows Coding Intention's object-shape rule.  It requires keyed-shape
evidence before bracket access is emitted.  Loading JSON only establishes a
`JSON_VALUE`; it does not prove that the decoded top-level value is a Directory.
A runtime witness or explicit host-owned shape hint must establish keyed shape.
Runtime member interrogation propagates the child's actual class/shape when a
witness exists.

### Generated-source proof

The generated contract test constructs semantic operations equivalent to:

```text
CREATE_DIRECTORY d
SET_NAMED_MEMBER d[x] = ready
SEND_MESSAGE d items -> count
RETURN count
```

The deterministic result is:

```rexx
d = .Directory~new
d["x"] = "ready"
count = d~items
return count
```

It is compiled and executed under ooRexx 5.3.0 r13196.

## Intention Service dev9 evidence gate

Luna is **not treated as knowing ooRexx**.  It chooses semantic operations and
domain operands only.  Exact language spelling remains owned by Coding
Intention / `RexxLanguageKnowledge` and the deterministic renderer.

For semantic operations that depend on object capabilities, dev9 publishes the
workbench's structured evidence into Intention Service dev9 as
`IntentionEvidenceFact` records.  Meaning and feasibility are then separate:

```text
semantic request understood
  -> evidence requirement assessed
  -> CLARIFY while evidence is insufficient
  -> refresh the retained decision when evidence changes
  -> READY only when the plan is feasible
```

Examples:

- `GET_NAMED_MEMBER` requires keyed-access evidence for the source object.
- `SEND_MESSAGE` requires runtime `hasMethod()` or language-contract evidence.
- an invented message remains blocked before source generation.

The semantic evidence gate does not dispatch source mutations.  Actual source
mutation still goes through the ordinary Intention Service READY/COMMIT path
for Development Desk `WRITE_METHOD`.

### Method-result propagation

Coding Intention dev13 method contracts are now used after a bound
`SEND_MESSAGE`.  For example, `Directory.items` propagates a `NUMBER` result at
contract confidence 95 with `CLASS_METHOD_CONTRACT` provenance.  Generic
`VALUE` results remain unknown instead of acquiring an invented type, and a
later runtime witness may supersede contract evidence at confidence 100.

## Luna Responses boundary

`AzureLunaApiClientTransport` uses the injected existing API Client
`ApiRequest` / `ApiClient~execute()` contract.  It does not implement DNS,
sockets, TLS, redirects, or HTTP itself.

Development Desk operations are strict Responses function tools with:

- `tool_choice = required`;
- `parallel_tool_calls = false`;
- `max_tool_calls = 1`;
- closed strict schemas;
- `store = false`.

`CODING_OPERATION` exposes the dev13 operation catalogue.  `SEND_MESSAGE`
requires workbench evidence; raw `WRITE_METHOD` remains an escape hatch only.

## Verification gate

Method-changing actions are materialised and passed to an injected verifier.
Verification results are structured observations.  `REPORT` is controller-gated
until a structured PASS exists and still has to pass Intention Service
READY/COMMIT afterward.

## Qualification

Core + Intention Service:

```sh
OOREXX_ROOT=/path/to/extracted-r13196 \
CODING_INTENTION_ROOT=/path/to/coding_intention_v0.1-dev13 \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev9 \
  ./tools/run_environment_test.sh
```

Include the real Development Desk adapter:

```sh
SEMANTIC_SOURCE_STORE_ROOT=/path/to/current-semantic-source-store \
OOREXX_ROOT=/path/to/extracted-r13196 \
CODING_INTENTION_ROOT=/path/to/coding_intention_v0.1-dev13 \
INTENTION_SERVICE_ROOT=/path/to/oorexx_intention_service_v0.1-dev9 \
  ./tools/run_environment_test.sh
```

For a live local SSCS database use `tools/run_local_sscs.sh` or
`tools/run_local_sscs_session.sh` with explicit `NOSQLSERVER_ROOT`,
`ALCHEMY_ROOT`, `CRYPTO_ROOT`, and `SSCS_ROOT`.

## Current r13196 evidence

The Workbench qualification proves:

- Coding Intention dev13's own 19-stage environment suite passes;
- live dev13 catalogue projection: 38 operations, 7 skills, 5 class contracts;
- all workbench sources/tests compile under r13196;
- strict Luna/API Client function-tool boundary;
- action/body non-flattening;
- structured verification fail -> repair -> pass loop;
- Intention Service dev9 hint integration;
- real Development Desk Intention bridge;
- runtime `hasMethod()` message gating;
- dev13 class-contract message gating;
- keyed-shape gate;
- generated House, catalogue, and runtime-contract programs compile and run.

## dev10 — Coding Intention dev13 capability negotiation

The workbench now consumes Coding Intention dev13 as the ooRexx language authority.
The exported catalogue is `coding-intention.rexx-language-catalogue/0.3` and records
`language=rexx` plus `capability_authority=RexxLanguageKnowledge.resolveOperation`.
Each projected operation carries an explicit `language_supported` decision and the
language/API evidence which supports it. Luna is not expected to know ooRexx or infer
that a library probably exists.

The workbench fails closed when the selected language authority has no implementation
contract for a semantic operation. YAML is the positive asymmetry proof: ooRexx dev13
advertises `LOAD_YAML_FILE`/`SAVE_YAML_FILE` through the r13196 `yaml.cls` contract.
An invented operation is not exposed as supported and cannot reach source generation.

## dev10 — real local SSCS on NoSQLServer v0.85

`tools/run_local_sscs_v085_qualification.sh` qualifies the website-free Development
Desk path against a real dependency stack. The acceptance used:

- ooRexx 5.3.0 r13196;
- current Semantic Source Store / Development Desk package used by this workbench;
- NoSQLServer v0.85;
- Alchemy Objects v0.8.2 semantic-target;
- ooRexx Crypto v0.8.3.

The test creates a fresh local store and executes `CREATE_PACKAGE`, `CREATE_CLASS`,
`ADD_ATTRIBUTE`, `ADD_METHOD`, `WRITE_METHOD`, `VIEW_METHOD`, `MATERIALISE`, then
compiles the resulting source with `rexxc`.

The same dependency environment then executes NoSQLServer's own
`v085_integer_precision_smoke.rex`, proving that 10-digit INTEGER values such as
`1277558000` round-trip and compare exactly under default Rexx precision. This replaces
the older v0.83 backend assumption in local SSCS qualification.

Enable the real local qualification with:

```sh
RUN_LOCAL_SSCS_V085_QUALIFICATION=1 \
SSCS_ROOT=/path/to/semantic-source-store \
NOSQLSERVER_ROOT=/path/to/nosqlserver-v0.85 \
ALCHEMY_ROOT=/path/to/alchemy-objects \
CRYPTO_ROOT=/path/to/oorexx-crypto-v0.8.3 \
OOREXX_ROOT=/path/to/r13196 \
CODING_INTENTION_ROOT=/path/to/coding-intention-dev13 \
INTENTION_SERVICE_ROOT=/path/to/intention-service-dev9 \
SEMANTIC_SOURCE_STORE_ROOT=/path/to/semantic-source-store \
./tools/run_environment_test.sh
```


## dev11 — portable semantic collection operations

Coding Intention dev13 is now projected into the workbench as 38 authoritative ooRexx
operations. Luna can select portable collection intent without knowing ooRexx method names:
`GET_COLLECTION_SIZE`, `GET_KEYS`, `APPEND_ITEM`, and `CONTAINS_KEY`.

The deterministic bridge maps those operations to ooRexx only after shape evidence passes:
collection size requires collection evidence, keys/membership require keyed evidence, and
append requires sequence evidence. The bridge records result evidence for size (`NUMBER`),
keys (`ARRAY`), and membership (`LOGICAL`). A Directory therefore cannot accidentally pass
the append gate merely because it is iterable.

`SEND_MESSAGE` remains available for domain behaviour with runtime `hasMethod()` or class
contract evidence, but the Luna tool description explicitly prefers portable semantic
operations when they express the requested concept. This removes unnecessary language API
selection from the model while preserving the raw-message escape hatch for real object
behaviour.

## dev12 — Rexx-native object instrumentation

Workbench instrumentation now lives in ooRexx, where the live semantic objects,
Development Desk tools, and API boundary coexist. `LlmCodingInstrumentation`
retains the actual Rexx object references for object reads, tool calls/results,
model/API turns, Intention decisions, and verification evidence. It does not
serialise those objects merely to observe them.

`LlmCodingTraceEvent~asSummary` is an explicit shallow boundary projection for
logging/UI consumers. Internal tracing continues to hold object identity, so a
semantic object is not flattened into a Python dictionary/JSON record and then
reconstructed later. Python is therefore unnecessary as an instrumentation or
Workbench-control layer; it should remain only where an external model/process
edge genuinely requires it.

## dev13 — explicit Rexx API projection boundary

The Workbench now carries the live `LlmCodingTurn` object all the way to an
object-aware transport. `LlmCodingBoundaryAdapter` is the explicit projection
point for JSON/API/logging edges. The Azure Luna transport implements
`invokeTurn(turn,boundary)` and projects the turn only immediately before
building the external Responses payload.

Legacy directory-based `invoke()` remains as a transport compatibility entry,
but the Workbench no longer chooses that path when an object-native transport
is available. This keeps object identity, tool objects and instrumentation in
Rexx until an external protocol actually requires a flattened representation.

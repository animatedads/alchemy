# Alchemy Spec Framework — Architecture Guide

## Purpose

A language-independent program specification system.
Write what code does once, in JSON. Generate it in any language.
Verify it against business rules. Document it automatically.
Patch security vulnerabilities in one place.

This document describes the complete framework so an AI can use it
to analyse, refactor, and regenerate existing code.

---

## Folder Structure

```
alchemy/
│
├── runner.rex                    ← Composition root. Start here.
│
├── core/                         ← Infrastructure shared by everything
│   ├── Container.cls             ← Dependency container (register, get, reload)
│   ├── LifecycleManager.cls      ← Startup/shutdown sequencing
│   ├── EventTrigger.cls          ← File-touch hot-reload trigger
│   ├── FileLoader.cls            ← Canonical file reading
│   ├── ConfigProvider.cls        ← Config file → Directory
│   ├── Logger.cls                ← Structured logging with levels
│   ├── TempFileManager.cls       ← Create/track/cleanup temp files
│   ├── BufferedWriter.cls        ← Batch output, never lineOut per record
│   └── HealthReporter.cls        ← System status snapshot
│
├── spec/                         ← The specification language engine
│   ├── ProgramSpec.cls           ← Loads and holds a spec JSON document
│   ├── CodeGenerator.cls         ← Abstract base: walks spec, calls emit*
│   ├── ImplAwareGenerator.cls    ← Adds impl/impl_use dispatch
│   ├── PreferredAwareGenerator.cls ← Resolves preferred.* names
│   ├── OORexxGenerator.cls       ← Emits OORexx source
│   ├── PythonGenerator.cls       ← Emits Python source
│   ├── BashGenerator.cls         ← Emits Bash source
│   ├── JavaGenerator.cls         ← Emits Java source
│   ├── GoGenerator.cls           ← Emits Go source
│   ├── DotNetGenerator.cls       ← Emits C# source
│   ├── ImplRegistry.cls          ← Holds named impl definitions
│   └── GeneratorFactory.cls      ← Returns right generator for language
│
├── preferred/                    ← Standard library for the spec language
│   ├── PreferredModule.cls       ← Registry + resolver + version detection
│   └── preferred.capabilities.json ← Capability definitions (hot-reloadable)
│
│   Capability naming: preferred.CATEGORY.OPERATION
│   Categories: hash  crypto  http  json  xml
│               file  string  list  map   time
│               env   log     process
│
├── rules/                        ← Hot-loadable rule engine
│   ├── RuleEngine.cls            ← Base: load JSON rules, evaluate context
│   ├── RTOPolicyEngine.cls       ← RTO trust families, risk classes
│   ├── InspectorRuleEngine.cls   ← OORexx coding standard rules
│   ├── AgentRoutingEngine.cls    ← Which agent handles what message
│   ├── AuthRuleEngine.cls        ← HTTP interface permissions
│   ├── BusinessRuleEngine.cls    ← Runtime business rule monitoring
│   ├── CodingStandardsVerifier.cls ← Static analysis of source files
│   │
│   └── rule-files/               ← JSON rule definitions (hot-reloadable)
│       ├── inspector.rules.json
│       ├── rto.policy.json
│       ├── agent.routing.json
│       ├── auth.rules.json
│       ├── business.rules.json
│       └── coding.standards.json
│
├── contracts/                    ← Design by contract, runtime verification
│   ├── Contract.cls              ← Base: requireMethod, addInvariant, verify
│   ├── RuleEngineContract.cls    ← Must have load, evaluate, reload, version
│   ├── AgentContract.cls         ← Must have poll, send, status, agentId
│   ├── ConfigContract.cls        ← Must have get, load, reload, validate
│   ├── LanguagePackContract.cls  ← Must have load, fwdIdx, revIdx, reload
│   └── HttpHandlerContract.cls   ← Must have handle(request, response)
│
├── external/                     ← Unified external execution model
│   ├── ExternalCall.cls          ← The call: command + args + transport
│   ├── ExternalResult.cls        ← exitCode, stdout, stderr, elapsed, timedOut
│   ├── LocalTransport.cls        ← ADDRESS SYSTEM, captured output
│   ├── IsolatedTransport.cls     ← Subprocess fork, crash-safe
│   ├── TCPTransport.cls          ← Remote executor over socket
│   ├── QueueTransport.cls        ← RXQUEUE submit/reply
│   └── SSHTransport.cls          ← Remote machine via SSH
│
├── api/                          ← Expose any object via multiple transports
│   ├── ApiExposable.cls          ← Mixin: declareApi, apiDispatch, adapters
│   ├── JsonAdapter.cls           ← HTTP/REST transport
│   ├── QueueAdapter.cls          ← RXQUEUE transport
│   ├── SocketAdapter.cls         ← TCP socket transport
│   ├── CommandAdapter.cls        ← Agent plugin command transport
│   ├── HttpServer.cls            ← Single shared HTTP server (rxsock)
│   ├── HttpRequest.cls           ← Parses raw HTTP request string
│   └── HttpResponse.cls          ← Serialises HTTP response string
│
├── agents/                       ← Analysis agents (pluggable)
│   ├── GemmaAgent.cls            ← Local Gemma via Ollama ~query(prompt)
│   ├── StaticTestAgent.cls       ← Canned responses for testing
│   ├── HumanConsoleAgent.cls     ← stdin/stdout: the human reviewer
│   └── RemoteAPIAgent.cls        ← Any HTTP endpoint as agent
│
├── docs/                         ← Documentation and rules verification
│   ├── DocumentationAgent.cls    ← Spec → structured documentation
│   └── BusinessRulesVerifier.cls ← Rules doc ↔ spec coverage report
│
└── monitors/                     ← Runtime observability
    ├── BusinessRulesMonitor.cls  ← Event stream → rule violations
    ├── MetricsCollector.cls      ← Counters, gauges, timings
    └── AlertManager.cls          ← Threshold triggers → notifications
```

---

## Core Concepts

### 1. The Spec Language

A program described in JSON using a fixed set of construct operators.
Platform-independent. Cannot drift from documentation. Cannot hide bugs at boundaries.

```json
{
  "spec": "1.0",
  "module": "MyProgram",
  "nodes": [
    {"op":"impl",    "name":"doX", "abstract":"...", "params":["a"],
     "implementations": {
       "python": {"type":"library","requires":["import x"],"inline":"code {a}"},
       "dotnet": {"type":"library","requires":["using X;"],"inline":"code {a}"},
       "java":   {"type":"library","requires":["import x.Y;"],"inline":"code {a}"},
       "go":     {"type":"library","requires":["\"x\""],    "inline":"code {a}"}
     }},
    {"op":"routine", "name":"main", "params":[], "body":[
      {"op":"declare","name":"v","value":{"op":"impl_use","name":"preferred.file.read","args":[{"op":"literal","value":"input.txt"}]}},
      {"op":"impl_use","name":"doX","args":["v"]}
    ]}
  ]
}
```

**Construct operators:**
```
declare assign const                          Data
literal nil concat add sub mul div           Expressions
eq neq lt gt lte gte and or not              Comparisons
index method call impl_use new               Calls
if select while for_each for_range           Control
return raise break continue                  Flow
try catch                                    Errors
routine impl                                 Structure
read_file write_file output                  I/O
```

**Variable references:** bare string `"myVar"` — NOT `{"op":"literal","value":"myVar"}`
**Literal values:** `{"op":"literal","value":"text"}` or `{"op":"literal","value":42}`

### 2. The Preferred Module

Standard library. Use `preferred.*` for all common operations.
Never write impl blocks for these. The module handles version detection,
library selection, and security guarantees automatically.

```
preferred.hash.sha256        preferred.hash.password  (never md5)
preferred.crypto.random      preferred.crypto.hmac_sha256
preferred.crypto.encrypt_aes preferred.crypto.decrypt_aes
preferred.http.get           preferred.http.post
preferred.json.parse         preferred.json.serialize
preferred.xml.parse
preferred.file.read          preferred.file.write
preferred.file.lines         preferred.file.exists    preferred.file.append
preferred.string.trim        preferred.string.split   preferred.string.replace
preferred.string.from_int    preferred.string.to_int
preferred.time.now           preferred.time.timestamp preferred.time.sleep
preferred.env.get
preferred.log.info           preferred.log.warn       preferred.log.error
preferred.map.create         preferred.map.get        preferred.map.put
preferred.list.create        preferred.list.append    preferred.list.get
preferred.process.run
```

**Write your own impl only for operations specific to your problem domain.**

### 3. The Container

Everything registers by name. Everything is retrieved by name.
No hidden dependencies. Hot-reload checks contract before swap.

```rexx
container~register('myThing', .MyClass~new(container))
container~contract('myThing', .MyThingContract~new)
container~get('myThing')~doSomething
container~reload('myThing')   /* contract verified before swap */
```

### 4. External Calls

Same call surface regardless of where code runs.

```rexx
call = .ExternalCall~new(container)
call~command   = 'python3'
call~args      = .Array~of('script.py', param)
call~transport = container~get('transport.isolated')  /* crash-safe */
call~timeout   = 30
call~run
say call~result~exitCode call~result~stdout
```

Transports: `transport.local` `transport.isolated` `transport.remote` `transport.queue`

### 5. Analysis Agents

Any object answering `~query(prompt)` → string.

```rexx
agent = .GemmaAgent~new(container)           /* local, pocket computer */
agent = .StaticTestAgent~new(responses)      /* canned, for CI testing */
agent = .HumanConsoleAgent~new('Reviewer')   /* human types response   */
agent = .RemoteAPIAgent~new(container, url)  /* any HTTP endpoint      */
```

### 6. Business Rules Verification

```rexx
verifier = .BusinessRulesVerifier~new(container)
verifier~spec = mySpec
verifier~loadRules('requirements.md')
verifier~verify
say verifier~generateReport
verifier~verifyWithGemma(specSummary)  /* Gemma handles ambiguous rules */
```

**The boundary condition rule:** natural language "up to X" is ambiguous.
The spec language forces `lt` or `lte`. Unspecified boundaries become
missing cases. Missing cases are caught by the verifier before they ship.
Brokers find missing cases before your auditors do. The verifier finds
them before the brokers do.

---

## How to Use This to Refactor Existing Code

### Step 1: Analyse the existing code

Ask an agent (Gemma or larger model) to read the existing code and
describe what each function/method does in plain English.

```rexx
analyst = .GemmaAgent~new(container)
description = analyst~query('Describe what each function in this code does:' || existingCode)
```

### Step 2: Identify platform-specific operations

Scan the existing code for:
- HTTP calls (requests, urllib, HttpClient, http.Get)
- File I/O (open, File.ReadAllText, os.ReadFile)
- Crypto (hashlib, SHA256, crypto/sha256)
- JSON (json.loads, JsonSerializer, encoding/json)
- Anything that differs between platforms

These become `impl` blocks OR `preferred.*` calls.
If it's in the preferred module table → use `preferred.*`
If it's domain-specific → write an `impl` block

### Step 3: Write the spec

For each function in the existing code, write a `routine` node.
For each platform-specific call, write an `impl` node or use `preferred.*`.
Use bare variable names for references. Use `{"op":"literal"}` only for constants.

**Common mistakes to avoid:**
- `{"op":"literal","value":"myVar"}` → wrong, this is the string "myVar"
- `"myVar"` → correct, this is the variable myVar
- `"op":"switch"` → wrong, use `"op":"select"`
- Embedding code in `"op":"run"` → wrong, use `impl` blocks

### Step 4: Verify against business rules

Write the business requirements in plain text (one rule per line).
Run the verifier. Fix gaps before generating code.

### Step 5: Generate

```rexx
gen  = .GeneratorFactory~forLanguage('python', container)
spec = .ProgramSpec~new(container)
spec~loadFile('myprogram.spec.json')
say gen~generate(spec)
```

### Step 6: Verify the output

Run `CodingStandardsVerifier` on the generated source.
Use Gemma to confirm the output matches the original description from step 1.

```rexx
doc = .DocumentationAgent~new(container)
doc~spec = spec
doc~generateWithAgent(.GemmaAgent~new(container), 'output_docs.md')
```

---

## The Security Guarantee

Patching a vulnerability:

1. Find the impl block or preferred capability
2. Change what's inside it
3. The interface (name, params, return) stays the same
4. Regenerate all affected programs
5. Done

No grepping. No hunting through generated code.
No hoping you found every instance.

**`preferred.hash.password` will never use md5.** That is unconditional.
**`preferred.crypto.random` will never use `random.random()`.** Unconditional.
The preferred module holds these guarantees. The spec inherits them for free.

---

## Quick Reference: Runner Registration Order

```rexx
/* 1. Infrastructure */
container~register('fileLoader',    .FileLoader~new)
container~register('logger',        .Logger~new('app.log', 'INFO'))
container~register('tempManager',   .TempFileManager~new('/tmp/alchemy'))
container~register('config',        .ConfigProvider~new(container, 'app.config'))

/* 2. Transports */
container~register('transport.local',    .LocalTransport~new(container))
container~register('transport.isolated', .IsolatedTransport~new(container))
container~register('transport.remote',   .TCPTransport~new(container, host, port))

/* 3. Preferred module */
container~register('preferred',     .PreferredModule~new(container))

/* 4. Rule engines */
container~register('businessRules', .BusinessRulesMonitor~new(container))
container~register('authRules',     .AuthRuleEngine~new(container, 'rules/auth.rules.json'))

/* 5. Spec tools */
container~register('specGenerator', .GeneratorFactory~new)
container~register('docAgent',      .DocumentationAgent~new(container))
container~register('rulesVerifier', .BusinessRulesVerifier~new(container))

/* 6. Contracts */
container~contract('config',        .ConfigContract~new)
container~contract('preferred',     .ContainerObjectContract~new)

/* 7. Analysis agents */
container~register('gemma',         .GemmaAgent~new(container))
container~register('testAgent',     .StaticTestAgent~new(.nil))
container~register('humanReviewer', .HumanConsoleAgent~new('Reviewer'))

/* 8. HTTP server + UI */
container~register('httpServer',    .HttpServer~new(container))
httpServer = container~get('httpServer')
httpServer~mount('/health',   .HealthEndpoint~new(container))
httpServer~mount('/api/v1',   .RestApiInterface~new(container))
httpServer~mount('/docs',     .DocumentationInterface~new(container))
```

---

## File Naming Conventions

```
*.cls           OORexx class files
*.rex           OORexx executable scripts
*.spec.json     Program specifications
*.rules.json    Rule engine definitions
*.config        Configuration files (key=value or JSON)
*.capabilities.json  Preferred module capability definitions
```

---

## The Pipeline

```
Business Requirements (plain text)
         │
    BusinessRulesVerifier
         │ gaps found before shipping
         ▼
    Spec JSON  ←──────────────────────── one source of truth
    │         │              │
    │    CodeGenerator   DocumentationAgent
    │         │              │
    │    Python/Java/    Markdown/HTML/
    │    Go/C#/OORexx   Word document
    │         │
    CodingStandardsVerifier
         │
    Gemma verifies output matches requirements
         │
         ▼
    Production code that cannot drift from its spec
```

---

## Linguist / Librarian Subsystem

```
alchemy/
  linguist/
    LibrarianScoring.cls      ← LiteWordIndex: words + etym + scope
                                SoundexKey, FindCognate
    LinguistAgent.cls         ← Translation agent: 3-tier lookup
                                (CorrectionStore → fwdIdx → Soundex)
    CorrectionStore.cls       ← Context-aware TSV store
                                ENWORD TAB fw TAB sentence TAB ctx
    WordIndexProvider.cls     ← Container wrapper for LiteWordIndex
                                registered as 'wordIndex'
    LanguagePackManager.cls   ← Lazy-loads .{lang}eng indexes
                                registered as 'langPack'
    CorrectionStoreManager.cls ← Manages per-language stores
                                registered as 'corrStore'
    TrainerTask.cls           ← ExternalCall wrapper for linguist_trainer
                                registered as 'trainerTask'

  tools/
    linguist_trainer.rex      ← Training runner (Gemma+LLM7, curl only)
    wn_scope_build.rex        ← Builds wn_cache_31.scope from cache
```

### Three-tier word lookup (LinguistAgent)

```
1. CorrectionStore   — context-scored LLM-taught corrections
2. Forward index     — WordNet .{lang}eng first hit
3. Soundex cognate   — etym score ≤ 3 gate + phonetic fallback
```

### Container registration (add to runner.rex section 4)

```rexx
container~register('wordIndex',  .WordIndexProvider~new(container))
container~register('langPack',   .LanguagePackManager~new(container))
container~register('corrStore',  .CorrectionStoreManager~new(container))
container~register('linguist',   .LinguistAgent~new(container))
container~register('trainerTask',.TrainerTask~new(container))
```

### Contracts

```
WordIndexContract    — scopeFor, etymFor, hasWord, reload
LanguagePackContract — fwdIdx, revIdx, reload, languages
CorrectionStoreContract — get, put, load, reload
```

### Lifecycle additions

```rexx
lifecycle~onStartup('wordIndex',  'load')
lifecycle~onStartup('langPack',   'loadAll')
lifecycle~onStartup('corrStore',  'loadAll')
```

### Hot-reload via file touch

```
touch /tmp/alchemy.reload.langpack   → LanguagePackManager~reload
touch /tmp/alchemy.reload.corrstore  → CorrectionStoreManager~reload
```

### Running a training batch

```rexx
trainer = container~get('trainerTask')
trainer~run(10)        /* 10 rounds, random languages */
trainer~run(5, 'EL')   /* 5 rounds, Greek only */
```

### Scope analysis

```
LiteWordIndex~scopeFor(word, contextWords)
  → returns scope keywords for the best-matching WordNet sense
  → context-scored: 'bank' in 'river current water' → 'body water'
  → context-scored: 'bank' in 'money finance loan'  → 'financial institution'
```

### Key files on disk

```
wn_cache_31.words          WordNet canonical word + POS
wn_cache_31.etym           Etymology scores (0-10, lower = more foreign)
wn_cache_31.scope          Sense → scope keywords (built by wn_scope_build)
wn_cache_31.{lang}eng      Foreign word → English pairs per language
corrections/
  wn_corrections.el.tsv    Greek correction store
  wn_corrections.de.tsv    German correction store
  ...
```

---

## Inspector Clouseau — Runtime Verification Layer

```
alchemy/monitors/
  InspectorClouseau.cls     ← Live object graph crawler + evidence engine
                              v1.4.2 — 5600+ lines
  AlchemyInspectorRules.cls ← Alchemy-specific root set, rules, report names
                              Environment-variable gated

alchemy/contracts/
  InspectorContract.cls     ← Contract: snapshot, writeJson, attach, alarms
```

### What Inspector Clouseau does

At runtime, crawls the live OORexx object graph from registered roots,
classifies all reachable methods, detects SIGNAL/CALL ON handlers,
records collection sizes and queue depths, and emits JSON+text snapshots.

This is the runtime complement to the design-time verification pipeline:

```
Design time:
  ProgramSpec → BusinessRulesVerifier
  "does the spec cover all business rules?"

Runtime:
  InspectorClouseau + AlchemyInspectorRules
  "does the running system match what was specified?"
```

### Activation

Inspector is opt-in via environment variable. Zero overhead when disabled.

```bash
ALCHEMY_INSPECTOR=1 rexx runner.rex          # basic
ALCHEMY_INSPECTOR=1 \
  ALCHEMY_INSPECTOR_PROBES=1 \               # in-scope object probes
  ALCHEMY_INSPECTOR_TRACE_SIGNALS=1 \        # capture condition evidence on every signal
  ALCHEMY_INSPECTOR_SNAPSHOT_ALARM_SECONDS=1800 \  # snapshot every 30 min
  rexx runner.rex
```

### Container registration (runner.rex — add after lifecycle setup)

```rexx
/* ── 8. Inspector Clouseau (runtime verification) ─────────────────── */
/* Optional: only installs when ALCHEMY_INSPECTOR=1                    */
if .AlchemyInspectorRules~enabled then do
  dataDir   = container~get('config')~get('data.dir', '.')
  log       = container~get('logger')
  roots     = .Array~of(container, lifecycle)
  inspector = .AlchemyInspectorRules~install('core', roots, log, dataDir)
  if inspector \= .nil then do
    container~register('inspector', inspector)
    container~contract('inspector', .InspectorContract~new)
    /* Attach subsequent registered objects as additional roots        */
    container~register('inspector.roots', roots)
  end
end
```

### Lifecycle integration

```rexx
/* Snapshot on clean shutdown if inspector is active */
lifecycle~onShutdown('inspector', 'snapshot')
```

In practice, `AlchemyInspectorRules~install` handles the startup snapshot
internally. The shutdown snapshot is an additional safety net.

### What AlchemyInspectorRules tracks

Variable patterns reported in every snapshot:
```
*QUEUE*     *AGENT*     *BRIDGE*    *OID*
*TIMER*     *LOGGER*    *SECURITY*  *CODELET*
```

Hot method source trails (where Alchemy crosses process/UI boundaries):
```
ALCHEMYAPPLICATION.SENDMESSAGE    ALCHEMYAPPLICATION.POLLALL
ALCHEMYAPPLICATION.DELIVERRESULT  SIMPLYBRIDGEAGENT.EXECUTEPLUGINCOMMAND
RXQUEUEBRIDGE.*                   STORAGE.*
LOCALLARGELIBRARY.SCAN
```

### Snapshot outputs

```
data/alchemy-inspector-core.json        ← latest JSON evidence
data/alchemy-inspector-core.txt         ← human-readable latest
data/alchemy-inspector-core-20260619T... ← timestamped archive
data/alchemy-inspector-install.log      ← install diagnostic trail
data/inspector-trace-requests/          ← drop JSON files here to trigger live traces
```

### Hot trace requests

Drop a JSON file in the trace-request directory while the system runs.
Inspector picks it up on the next alarm tick (default 5 seconds) and
executes the trace without restarting.

```json
{ "kind": "snapshot", "phase": "live-debug", "roots": ["container"] }
```

### The two inspectors — who does what

```
InspectorClouseau     ← the machinery
                        crawls objects, records evidence, writes files
                        knows nothing about Alchemy specifically

AlchemyInspectorRules ← the policy
                        knows which roots to attach (container, lifecycle)
                        knows which variable patterns matter (*QUEUE* etc)
                        knows which method boundaries to trace (SENDMESSAGE)
                        activated by ALCHEMY_INSPECTOR env var
                        deliberately small — machinery is Clouseau's job
```

This is the correct separation. When the Alchemy application changes,
`AlchemyInspectorRules` changes. `InspectorClouseau` never changes.
`InspectorClouseau` knows nothing about agents, queues, OIDs, or bridges.

### Integration with CodingStandardsVerifier

Inspector's signal detection feeds CodingStandardsVerifier at runtime:

```rexx
inspector = container~get('inspector')
if inspector \= .nil then do
  snap = inspector~snapshot
  /* Extract signal handler evidence and feed to verifier             */
  verifier = container~get('codingVerifier')
  verifier~loadSignalEvidence(snap)
end
```

### Integration with DocumentationAgent

Inspector snapshots are machine-readable evidence of what the system
actually does at runtime. DocumentationAgent can use them to verify
that generated documentation matches observed runtime behaviour:

```rexx
doc      = container~get('docAgent')
inspector = container~get('inspector')
if inspector \= .nil then do
  snap = inspector~snapshot
  doc~verifyAgainstSnapshot(snap)   /* "does the spec describe what we see?" */
end
```

### Security: handcuffs

`AlchemyInspectorRules~attachSecurityManagers` installs security managers
from the file at `ALCHEMY_INSPECTOR_SECURITY_POLICY`. These constrain what
methods may be called on which objects. The policy file is a JSON document
reviewed separately from the spec. Inspector enforces it at runtime.

## Additive Plan42 service integration (October 2026)

The composition root now registers `plan42` as an Alchemy capability. Its semantic API is `discover`, `inspect`, `compile`, and its effects stop at guarded generation into `generated/plan42/`. The compiler, native ooRexx façade, and evidence model are detailed in `docs/PLAN42_ALCHEMY_INTEGRATION.md`. This is an optional local capability, not a second transport framework or permission to activate CODELETs.

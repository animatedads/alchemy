# ooRexx LLM Personal Assistant v0.1-dev9 cognitive-abilities candidate4


## candidate4 — Cognitive Continuity as the durable memory authority

- Vendors the exact `oorexx_cognitive_continuity_v0.1-dev2-exp1` release as a sealed dependency and consumes its native LLMPA adapter; LLMPA does not fork its journal, classifier, projection planner or admission rules.
- Registers `cognitive.records.query`, `cognitive.continuity.query`, `cognitive.context.project`, `cognitive.context.export`, `cognitive.context.explain`, `cognitive.classification.explain`, `cognitive.learning.delta`, and `cognitive.effects.propose` through the existing `abilities.d` registry.
- `cognitive.context.export` returns the exact provider-neutral `cognitive.model-context/0.1` input plus the reason trace showing why each cognitive record was selected.
- `cognitive.effects.propose` is a governed mutation but uses the model actor. Origin, assertion class, epistemic state, verification state and decision authority are server-derived; Codex cannot declare itself `TOOL_VERIFIED` or a project authority.
- `continuity.current` now prefers durable Cognitive Continuity events and includes the older Gemma handoff only as an optional `PROJECTION_ONLY` cache. Inference context may compact; cognitive state does not.
- Adds restart qualification proving a fresh cognitive service reconstructs the same admitted record from the JSONL journal without any chat transcript or continuity brief.
- Keeps Structured Response ownership outside LLMPA. Cognitive Continuity consumes/produces typed cognitive effects at that boundary; the LLMPA ability registry remains only a semantic invocation adapter.

Exact Cognitive Continuity input archive SHA-256: `0e5d3fca25455afa76e0c7742c345fc492c1c7a86353cf95ef0a921bc791708c`.

See `docs/COGNITIVE_ABILITIES.md`.

## candidate3 — directory-loaded named abilities

- Adds `LlmPaAbility`, `LlmPaAbilityContext`, and fail-closed `LlmPaAbilityRegistry`.
- Loads trusted `abilities.d/*.cls` packages dynamically with ooRexx `Package~new()` and discovers public subclasses of `LlmPaAbility`.
- Duplicate IDs/aliases block registry readiness; there is no last-file-wins tool registration.
- Adds one generated catalogue for Codex, LLMPA, CLI and future MCP projection: `pa-tool abilities` / `llmpa abilities`.
- Adds canonical generic invocation: `pa-tool ability ID JSON` / `llmpa ability ID JSON`.
- Registers `ability.catalogue`, `plan.current`, `continuity.current`, `package.stage`, `package.release.analyse`, and `package.release`.
- Ability descriptors declare authority class, mutating status, request/response schemas and required platform primitives.
- Structured Response is an injected producer boundary, not reimplemented locally; `structured_response_emitter` may project detached ability execution records into the estate response contract.
- `continuity.current` explicitly labels the old generated handoff as `PROJECTION_ONLY`; model-context compaction is not a cognitive-state retention rule.

See `docs/ABILITIES.md`.


## dev8 — Gemma gets LLM Gopher

- Bundles the exact `llm_gopher_v0.21-dev1` artifact and the supplied project sphere collection as a **read-only evidence source** for Gemma.
- Adds the controlled `gopher_read` PA function (`READ_ONLY`, `mutating=false`, `eventable=true`, `authority_class=EVIDENCE_ONLY`).
- Adds `llmpa -gopher "query"` for direct, no-model Gopher evidence inspection.
- Ordinary `ask`/`message` turns consult Gopher as a fallback when neither durable PA memory nor approved local knowledge covers the question, or when Codex explicitly asks about Gopher/a sphere.
- Gemma receives the selected sphere/article summary, invariants and provenance; Gopher evidence is explicitly **not live state and not execution authority**.
- User text is never forwarded as an arbitrary Gopher command. ooRexx first scores a static bundled sphere catalogue, then invokes only validated sphere/article IDs. Mutating Gopher surfaces are not exposed to the PA.
- Live chat replies report `gopher_used=true`, `gopher_sphere`, and (when selected) `gopher_article_id`, so Codex can see when project documentation grounded the answer.
- Production daemon startup probes the bundled Gopher and fails before `LLMPA_READY=1` if the read path is unavailable.
- The bundled catalogue currently contains 54 routable sphere entries backed by 53 external sphere archives plus Gopher built-ins.

## dev7 local operational knowledge, grounding, and Gemma-timed reminders

- Adds a read-only local knowledge catalogue at `LLMPA_KNOWLEDGE_ROOT` (default `$LLMPA_STORE_ROOT/knowledge.d`).
- Searches approved `.md`, `.txt`, and `.help` files and injects matched material with source provenance into Gemma's prompt.
- Adds `llmpa -knowledge "query"` for direct, no-model inspection of catalogue matches.
- Tightens grounding: Gemma is told not to invent organisation membership, responsibilities, command syntax, flags, paths, capabilities or live state beyond memory/local documentation.
- Lookup keys remain retrieval metadata and are no longer shown to Gemma during ordinary answers.
- Local knowledge is distinct from durable operator memory and from live tool state.
- Natural `remind` no longer has a CLI time grammar. The exact phrase is sent to real Gemma with the current PA-host time; Gemma must choose `RECALL`, `SCHEDULE|seconds|text`, or `UNRESOLVED|reason`.
- ooRexx validates Gemma's delay (1..31,536,000 seconds) and arms exactly one native Alarm. The model never owns the timer.
- This accepts natural timing and minor typos such as `10 secdonds time, what is ed209e` without silently turning them into memory recall.
- Explicit `-remind-after "IN ..."` remains as a deterministic escape hatch/qualification command.

See `docs/LOCAL_KNOWLEDGE.md`.

Executable asynchronous Codex -> Queue Fabric -> Gemma PA component with durable operator memory, native ooRexx Alarm reminders, and a real local Gemma/Ollama deployment path.

## What changed in dev6

- `remember` is now an ingestion step: when live Gemma is configured, Gemma creates a concise lookup-key list for the fact before it is persisted.
- The original operator wording remains authoritative. The generated index is stored separately as `lookup_keys` with provenance such as `gemma:gemma2:2b`.
- A free-form fact such as `for ssh we have a configured script ./sshnode.sh` can be retrieved by later questions containing `ssh`, `sshnode`, or `sshnode.sh`.
- The remember acknowledgement exposes the chosen keys, making poor indexing visible immediately.
- Existing dev5 calendar/eventable one-shot Alarm semantics are retained unchanged.
- Existing memory journals remain readable; historical rows receive deterministic compatibility keys at read time and are not rewritten.


## Core contract

- asynchronous by design: `llmpa` submission returns a request id immediately; Gemma processing is not on Codex's synchronous execution path.
- requests/replies are detached Queue Fabric payload data with correlation ids and reply queues.
- durable PA memory is append-only and separate from model context/session state.
- `remember` stores operator knowledge with source, request id and timestamp, plus a separate lookup-key index; with live Gemma configured, Gemma authors that index.
- natural `remind` is interpreted by live Gemma: no future intent means memory recall now; clear future intent yields one validated initial Alarm; unresolved future timing fails closed.
- explicit `remind-after "IN N <unit> ..."` retains the deterministic parser for diagnostics/qualification.
- when an Alarm fires it cannot message Codex directly; the target enqueues a fresh persistent `alarm_fire` request onto `LLMPA.REQUEST` as principal `llmpa-alarm`. Gemma later claims that request and writes the eventual reminder.
- model output, praise, PA memory and Alarm expiry never manufacture execution authority. The existing broker/orchestrator seam remains the future tool-execution authority.

## Real Gemma deployment

Set the command bridge token and optionally choose a fixed port:

    export LLMPA_BRIDGE_TOKEN='local-secret'
    export LLMPA_BRIDGE_PORT=38080
    export LLMPA_STORE_ROOT="$PWD/runtime"
    export LLMPA_GEMMA_MODEL='gemma2:2b'
    export LLMPA_OLLAMA_BASE_URL='http://127.0.0.1:11434'

Start the production daemon:

    rexx bin/llmpad.rex

Successful startup includes:

    LLMPA_MODEL=gemma2:2b
    LLMPA_MODEL_VERIFIED=1
    LLMPA_GOPHER=llm_gopher_v0.21-dev1
    LLMPA_GOPHER_READY=1
    LLMPA_READY=1

If Ollama is absent, the requested model is not installed, or a non-Gemma model is configured, startup fails. There is no deterministic chat fallback in `bin/llmpad.rex`.

`bin/llmpad_demo.rex` remains intentionally no-model for deterministic qualification only.

## Commands

With `LLMPA_BRIDGE_HOST`, `LLMPA_BRIDGE_PORT` and `LLMPA_BRIDGE_TOKEN` matching the daemon:

    rexx bin/llmpa.rex '-remember {"ED209E", "Google server; use GCloud tooling"}'
    rexx bin/llmpa.rex '-remember "for ssh we have a configured script ./sshnode.sh"'
    rexx bin/llmpa.rex '-remind "ed209e"'
    rexx bin/llmpa.rex '-ask "What do you remember about ED209E? Separate remembered facts from unknown live status."'
    rexx bin/llmpa.rex '-remind {10 secdonds time, what is ed209e}'
    rexx bin/llmpa.rex 'remind "IN 10 minutes check ed209 finished build"'
    rexx bin/llmpa.rex '-calendar'
    rexx bin/llmpa.rex '-gopher "What does Queue Fabric say about queue authority and claims?"'
    rexx bin/llmpa.rex '-next'

For fleet-wide live questions after seeding memory:

    rexx tools/seed_fleet_memory.rex
    rexx bin/llmpa.rex '-ask "Summarise the ED209 fleet by role, provider and operational cautions. Separate remembered facts from unknown live status."'

The context expansion gives Gemma the ED209 group plus directly referenced operational memories rather than only whichever record happened to match one lexical token.


## Read-only LLM Gopher evidence

Gemma can consult the bundled LLM Gopher when PA memory and approved local knowledge do not already answer a question. This is deliberately an evidence/navigation capability, not an execution bridge.

Direct inspection without a model turn:

    rexx bin/llmpa.rex '-gopher "Queue Fabric authority claims"'
    rexx bin/llmpa.rex '-next'

A normal Gemma question can use the same evidence automatically:

    rexx bin/llmpa.rex '-ask "According to project documentation, what owns Queue Fabric queue mutation authority?"'
    rexx bin/llmpa.rex '-next'

When Gopher was used, the reply includes `gopher_used=true` plus the selected sphere/article identity. The model prompt receives project-grounded summary/invariant/provenance material and is reminded that this material is documentation evidence only: it is not current machine state, credentials, permission, or authority to execute.

The PA wrapper never exposes arbitrary Gopher arguments. It selects from `deps/gopher_catalog.tsv`, activates only the corresponding bundled exact sphere archive, opens a validated article id returned by Gopher context, and flattens the returned evidence into detached Queue Fabric-safe data. `exec`, source editing, sphere editing, package staging and other mutating Gopher surfaces are not exposed.

Because `gopher_read` is eventable, an Alarm-fired PA turn may consult Gopher before Gemma decides what to do next. The Alarm remains one-shot: consulting Gopher does not create recurrence, and another future check still requires Gemma to arm a new Alarm explicitly.

## Indexed durable memory

A live `remember` request first asks Gemma for a small retrieval index. Gemma is instructed to return only short keys that Codex may naturally use later: machine ids, command names, script/path basenames, providers and the main topic. The fact itself is stored unchanged.

Example acknowledgement:

    Remembered for ssh we have a configured script ./sshnode.sh. Indexed under: SSH, sshnode, sshnode.sh, remote access, configured script

A later `-ask "what is the ssh command to use?"` searches those lookup keys before broad lexical fallback and injects the matching original fact into Gemma's prompt. The lookup keys are hints, not facts, and never imply live machine state or execution authority.

If no model is configured (deterministic qualification/demo mode), the PA derives compatibility keys locally and marks their source as `deterministic`. Existing pre-dev6 journal rows are marked `legacy` when read and receive the same compatibility treatment without rewriting them.

## Delayed reminder flow

Natural `remind` timing is deliberately a Gemma decision, not a CLI parser decision:

    Codex -> llmpa -> LLMPA.REQUEST -> Gemma worker
                                  -> Gemma sees current PA-host time + exact phrase
                                  -> RECALL | SCHEDULE seconds/text | UNRESOLVED
                                  -> ooRexx validates decision
                                  -> arm exactly one native Alarm
                                  -> LLMPA.REPLY: REMINDER_SCHEDULED

For example, `-remind {10 secdonds time, what is ed209e}` may be normalised by Gemma to `SCHEDULE|10|what is ed209e`. The original phrase and `schedule_decision_source=gemma:<model>` remain visible in runtime evidence.

At expiry:

    AlarmNotification~triggered
        -> persistent alarm_fire on LLMPA.REQUEST
        -> Gemma worker
        -> live Gemma reminder prompt
        -> LLMPA.REPLY
        -> Codex

The Alarm target has no model, shell or tool authority; it has only queue PUT under `llmpa-alarm`.

### Read-only future calendar

`llmpa -calendar` (aliases `read-calendar` / `read_calendar`) invokes the formal `LlmPaReadCalendarTool`, which is declared `READ_ONLY`, `mutating=false`, and `eventable=true`, and returns the authoritative in-process list of currently armed native ooRexx Alarms. A natural question such as `llmpa -ask "What reminders are currently armed?"` causes the worker to inject the same read-only calendar into Gemma's prompt. Fired alarms disappear from this future view.

Alarms are strictly one-shot. There is no repeat flag and no hidden recurrence. A workflow such as "check every ten minutes until X" is implemented as: one Alarm fires; Gemma performs/requests the authorised check; Gemma decides whether X is final; only if another check is needed does Gemma explicitly arm a new one-shot Alarm for +10 minutes.

As in dev2, an armed native `.Alarm` is process-lifetime state. If the PA daemon stops before expiry, dev8 does not reconstruct that timer. Once the Alarm has fired, its `alarm_fire` Queue Fabric request is persistent. Durable re-arm recovery remains a later cut.

## Validation

`run_tests.sh` is the deterministic gate and includes the real RxSock/API Client transport against an in-process fake Ollama HTTP endpoint. It does not claim a local LLM exists.

On the target machine, run:

    ./run_live_gemma.sh

That gate verifies the configured Gemma through `/api/tags`, checks live Gemma-authored memory indexing plus local-knowledge grounding, verifies that a real Gemma turn can consume project-grounded Queue Fabric evidence from the bundled Gopher, asks Gemma to interpret a typo-bearing three-second reminder and requires `REMINDER_SCHEDULED`, then sends an asynchronous Queue Fabric `ask` containing a random nonce and requires the eventual model reply to contain that nonce. It therefore exercises:

    Queue Fabric -> PA Worker -> AI Access -> API Client -> RxSock -> Ollama -> Gemma

without curl.

## Dependencies

Qualified framework set:

- ooRexx 5.3.0 r13196
- Object Queue Fabric v0.9-dev5
- Alchemy Objects v0.8
- Queue Fabric Web Gateway v0.2
- ooRexx AI Access v0.6
- ooRexx API Client v0.4.1 on the target host (the native PA response wrapper also retains v0.3 setter compatibility)
- RxSock from ooRexx
- LLM Gopher v0.21-dev1 (exact bundled read-only evidence engine)
- ooRexx Cognitive Continuity v0.1-dev2-exp1 (exact bundled durable cognitive-state/admission/projection authority)
- supplied project sphere collection (exact external sphere ZIPs bundled for read-only resolution)
- optional AI Tool Orchestrator v0.3 for the later authorised tool-execution path

## Governed package release

Package release is the governed inverse of package staging.  The normal
command-set surface is:

    pa-tool package release-analyse .
    pa-tool package release . decisions.json

`release-analyse` is read-only.  It inventories the working tree after objective
hygiene exclusions and reports production shadows, competing same-name archive
cuts and non-blocking observations.  It does not guess that a larger version
number supersedes another package.

Release decisions are explicit data carrying an action, authority and reason.
`PRUNE` removes a named path only from the release snapshot; `KEEP_BOTH` may
resolve compatible artifact conflicts; `QUARANTINE_CONFLICT` preserves all
competing bytes beneath `_release_conflicts/<conflict-id>/...`.  Different
production files exporting the same public ooRexx class/routine cannot be waved
through with `KEEP_BOTH`; they must be pruned or quarantined.

The objective hygiene policy still excludes Python bytecode/cache material
(`__pycache__`, `*.pyc`, `*.pyo`), compiled class/object output, editor scratch,
source-control metadata, runtime journals/logs, `tests/live-gemma-store-*`,
`LEDGERPATH`, coverage output and similar execution debris.  None of those
exclusions delete or rewrite the working tree.

A successful release creates a fresh manifest, verifies every released byte,
publishes a content-addressed immutable generation, builds and structurally
checks the ZIP, reopens the ZIP to prove its exact file-member inventory, and
writes an immutable `llm.pa.package.release/0.2` receipt.  See
`docs/PACKAGE_RELEASE.md` for the decision-ledger contract.

# Command launchers

Use the checked-in wrappers from `bin/` so the PA dependency path is assembled
consistently:

```bash
bin/llmpad /path/to/pa-store
bin/llmpa 'ask What remains unresolved in the current plan?'
bin/llmpa next
```

The wrappers preserve a caller-supplied `REXX_PATH` and add the PA's pinned
dependency locations automatically.

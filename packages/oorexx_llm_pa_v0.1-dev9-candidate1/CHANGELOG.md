# Changelog

## 0.1-dev9-candidate1 — SecurityManager delegated machine observations

- Add bounded read-only ED209 machine abilities over the installation-owned `/home/hc3/alchemy-autobuild/sshnode.sh` transport.
- Attach `LlmPaMachineCheckSecurityManager` to the actual floating ooRexx method that owns `ADDRESS SYSTEM`; exact fixed commands are interpreter-gated.
- Gemma receives named abilities and structured observations, never arbitrary shell syntax.
- No transfer, deletion/creation, file output redirection, arbitrary pipes, sudo, process killing, service mutation or QueueBash mutation is delegated; the SecurityManager independently recognizes only the configured sshnode + delegated-node + known-read-probe shape.
- Add memory, filesystem space, process/queue, configuration/file metadata and deployment-state checks; raw process arguments and queue job payloads are withheld from model-facing evidence.
- Deployment observation distinguishes installed/quiescent, in-progress, stuck-suspected and expected-version mismatch without granting deployment authority.
- Machine abilities are eventable under the existing one-shot Alarm contract; a fired check cannot recur unless Gemma explicitly arms a new Alarm.
- Add negative SecurityManager qualification for `rm`, `>`, and `sshnode --transfer`, plus path and deployment-classification regressions.

## 0.1-dev8

- Give Gemma a bounded read-only LLM Gopher evidence capability.
- Bundle exact LLM Gopher v0.21-dev1 and the supplied project sphere collection; build a 54-entry static routing catalogue over the bundled spheres/built-ins.
- Add formal `gopher_read` metadata: `READ_ONLY`, `mutating=false`, `eventable=true`, `authority_class=EVIDENCE_ONLY`.
- Add direct `gopher` / `-gopher` command returning detached project evidence without a model paraphrase.
- Normal Gemma turns consult Gopher only when explicitly requested or when durable memory and local knowledge have no match.
- Route user questions locally to validated sphere/article IDs; never expose arbitrary Gopher command lines or mutating Gopher operations to the model.
- Flatten Gopher JSON helper objects before Queue Fabric persistence so direct evidence replies remain durable/persistable.
- Add `gopher_used`, `gopher_sphere`, and `gopher_article_id` observability on model replies that consumed Gopher evidence.
- Production daemon probes Gopher before READY and reports `LLMPA_GOPHER_READY=1`.
- Extend target-host live qualification so real Gemma must consume Queue Fabric Gopher evidence.

## 0.1-dev7

- Added read-only local operational knowledge catalogue with provenance and a direct `knowledge` CLI command.
- Added strict memory/document grounding instructions and stopped exposing lookup keys to normal model answers.
- Natural `remind` timing is now decided by Gemma from the exact phrase plus current PA-host time; the model emits only `RECALL`, `SCHEDULE|seconds|text`, or `UNRESOLVED|reason`.
- ooRexx validates Gemma's initial schedule and arms one native Alarm; ambiguous timing fails closed and there is still no repeating Alarm primitive.
- Added regression for the observed `10 secdonds time, what is ed209e` case.
- Added a writable PA `ApiResponse` subclass so native transport qualification remains compatible with older API Client v0.3 while matching the target's v0.4.1 elapsed-time contract.
- Preserved dev6 Gemma-authored memory indexing and dev5 one-shot eventable Alarm semantics.

## 0.1-dev6

- `remember` now asks live Gemma to create a compact 3..8-key lookup index for each durable fact.
- Memory records preserve the original operator fact and store `lookup_keys` plus `lookup_keys_source`; Gemma-generated indexes are stamped `gemma:<model>`.
- Free-form memories such as `for ssh we have a configured script ./sshnode.sh` can therefore be found later through keys such as `SSH`, `sshnode`, or `sshnode.sh`.
- `remember` acknowledgements expose the generated lookup keys so Codex can immediately see how Gemma indexed the fact.
- Prompt context retrieval consults lookup keys before broad lexical fallback and shows those keys to Gemma with the remembered fact.
- Legacy five-field memory journals remain readable and acquire deterministic compatibility keys at read time without rewriting historical facts.
- No-model qualification retains a clearly marked deterministic index fallback; production live Gemma uses the model index path.

## 0.1-dev5

- Added authoritative read-only `calendar` / `read_calendar` capability for currently armed native ooRexx Alarms.
- Natural Gemma questions about armed/pending/future reminders receive that live calendar as runtime context rather than guessing from durable memory.
- Calendar entries expose `reminder_id`, message, original delay, scheduled time, bounded remaining seconds and `one_shot=true`.
- Codified eventable one-shot semantics: Alarm firing ends that Alarm; repeated check-until workflows require Gemma to explicitly arm a fresh Alarm after each check.
- Added lifecycle regression proving an armed Alarm appears in the calendar and disappears after firing with no implicit recurrence.

## 0.1-dev4

- Fix Ollama ChatCompletion JSON typing: `stream` is now `.JSON~false` / `.JsonBoolean`, producing literal JSON `false` rather than Rexx numeric `0`.
- Add `test_ollama_json_boolean.rex`, a strict regression fixture that rejects `"stream":0` the way Ollama's Go decoder does.
- Preserve the dev3 native live-model path: AI Access v0.6 -> API Client v0.3 -> loopback RxSock -> Ollama -> exact configured Gemma model.
- No curl or shell HTTP fallback.

## 0.1-dev3

- Add production `bin/llmpad.rex` wired to real local Gemma/Ollama; no chat fallback.
- Verify the exact configured Gemma model through Ollama `/api/tags` before declaring the daemon ready.
- Replace the experimental `OpenAICompatCurlTransport` route with ooRexx AI Access v0.6 + API Client v0.3 + a loopback-only RxSock `ApiTransport`; no curl or shell HTTP commands.
- Require Gemma model identity on both configuration and returned completion metadata.
- Add target-host live qualification with a random nonce through Queue Fabric -> Gemma.
- Add `LlmPaMemoryStore~context`: broad fleet/machine/node prompts expand ED209 group memory and remembered key cross-references while ordinary `remind` stays narrow.
- Add current 24-fact ED209 memory seeder through the normal Queue Fabric `remember` path.
- Run the loopback command listener asynchronously and normalize its `serveAsync` return to a Boolean.
- Add deterministic native transport, model identity, no-curl and memory-context qualification tests.

## 0.1-dev2

- Add native ooRexx Alarm-backed delayed reminders.
- `remind "IN 10 minutes ..."` specializes to the `remind_after` worker command while preserving ordinary `remind` memory lookup.
- Add explicit `-remind-after` / `remind-after` aliases.
- Alarm expiry re-enters Gemma through a fresh persistent `alarm_fire` Queue Fabric request; the alarm never sends directly to Codex.
- Add separate `llmpa-alarm` Queue Fabric principal with request-queue PUT/BROWSE only.
- Add `REMINDER_SCHEDULED` acknowledgement and `reminder_id` correlation across scheduling/firing.
- Add reminder-specific Gemma prompt; alarm expiry grants no tool authority.
- Fix the live-model worker's Rexx special `RESULT` collision by using `modelResult`.

## 0.1-dev1

- First asynchronous Codex/Gemma PA queue contract.
- Durable append-only operator memory with source/request provenance.
- `remember`, `remind`, `ask`/`message` worker commands.
- Queue correlation and reply semantics.
- Optional bounded AI Tool Orchestrator bridge.
- Cheerful/appreciative Gemma prompt while preserving strict execution-authority separation.

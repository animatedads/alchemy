# LLM PA queue protocol 0.1

## Request

`llm.pa.request/0.1` contains detached data only:

- `request_id` — correlation identity
- `command` — `remember`, `remind`, `remind_after`, `calendar`, `knowledge`, `gopher`, `alarm_fire`, `ask` or `message`
- `arg1`, `arg2` — command data
- `submitted_by`
- `reply_to`
- `created_at`

No request carries a model session, API Client handle, broker lease, shell authority or tool authority.

`alarm_fire` is an internal request created only after the native Alarm target fires. `arg1` is reminder text, `arg2` is `reminder_id`, and `submitted_by` is `alarm:<reminder_id>`.

## Reply

`llm.pa.reply/0.1` contains:

- `request_id`
- `status` — `REPLIED` or `FAILED`
- `kind` — `MEMORY`, `REMINDER`, `REMINDER_SCHEDULED`, `CALENDAR`, `KNOWLEDGE`, `GOPHER`, `CHAT` or `ERROR`
- `text`
- `action_taken` — `NONE` or `TOOL`
- live model replies include `model_used=true` and `model_name`
- delayed reminder replies may include `reminder_id`, `delay_seconds` and `reminder_message`
- optional detached memory records; dev6 records include `lookup_keys` and `lookup_keys_source`
- optional `gopher_used`, `gopher_sphere` and `gopher_article_id` when project documentation grounded a model turn
- optional tool identity only when an authorised orchestrator actually executes a tool

## Live Gemma identity contract

The production daemon is not ready until `LlmPaOllamaOrchestrator~verifyModel` has queried local Ollama `/api/tags` through API Client and found the exact configured Gemma model (default `gemma2:2b`). Non-Gemma configuration is rejected. A completion is also rejected if returned model metadata does not identify a Gemma model.

There is no deterministic chat fallback in production `bin/llmpad.rex`; the no-model `llmpad_demo.rex` is a separately named qualification launcher.

Outbound local-model HTTP is owned by ooRexx API Client (v0.4.1 target-host baseline; v0.3-compatible response semantics retained) with a loopback-only RxSock `ApiTransport`. It accepts only local `http://127.0.0.1[:port]` or `http://localhost[:port]` endpoints and never shells out to curl.

## Memory ingestion and context

`remember` preserves the operator's original key/value fact and adds a separate retrieval index. With a live orchestrator configured, Gemma is asked for 3..8 concise lookup keys and the record is stamped `lookup_keys_source=gemma:<model>`. The acknowledgement returns those keys to Codex. No-model qualification uses a marked deterministic fallback; historical pre-dev6 rows are read with `lookup_keys_source=legacy` and are not rewritten.

For a live PA, `remind` is first classified by Gemma as recall-now or future scheduling. A `RECALL` decision then uses the same narrow indexed/lexical memory lookup. Model prompts use `LlmPaMemoryStore~context`:

- ordinary questions start from indexed/lexical matches;
- fleet/machine/node questions additionally include ED209* and FLEET_* records;
- explicit remembered key references are followed, so a node fact mentioning `GCloud` or `SSH` can include those operational records too;
- lookup keys are used internally for retrieval but are not inserted into ordinary Gemma answer prompts;
- returned context remains detached evidence; lookup keys are not facts and are not live status.

Local operational documentation is separately searched from the bounded `LLMPA_KNOWLEDGE_ROOT` catalogue and is injected with file provenance. It is not durable operator memory and it does not imply live state.


## LLM Gopher evidence contract

`gopher` / `gopher_read` is the command surface for the PA's bundled LLM Gopher reader. It is `READ_ONLY`, `mutating=false`, `eventable=true`, and `authority_class=EVIDENCE_ONLY`. The result is detached project documentation/provenance data; it is never live machine state and never confers tool, shell, queue or deployment authority.

The wrapper does not pass arbitrary user text as Gopher arguments. It locally scores the exact request against a static catalogue of known bundled sphere ids, activates only the corresponding exact sphere archive, asks Gopher for that sphere's context, selects a validated article id returned by that context, and opens that article. JSON helper objects are flattened before crossing the persistent Queue Fabric boundary.

Normal `ask`/`message` and `alarm_fire` turns may consult Gopher when memory/local knowledge do not cover the question or when the request explicitly asks for Gopher/sphere evidence. The resulting model reply records `gopher_used=true` and the selected sphere/article identity. Mutating Gopher surfaces such as exec/source-edit/sphere-edit/package staging are not exposed by this PA function.

Eventability does not imply recurrence: a one-shot Alarm may wake Gemma, Gemma may read Gopher evidence during that turn, and a later check occurs only if Gemma explicitly arms a new one-shot Alarm.

## Job closure and lessons

At the end of a substantial job, Codex may submit `lesson "objective | Codex summary"`. Gemma reviews the summary under the normal model/escalation boundary and returns `LESSONS`, `PITFALLS`, `NEXT_TIME`, and `OPEN_FOLLOWUP`. The PA stores the paired Codex summary and Gemma review as durable memory, with request and model provenance, so future plans and continuity briefs can use both perspectives.

## Delayed reminder transition

Natural `remind` does not parse time in the CLI. With real Gemma and the Alarm service configured:

1. Codex submits the exact natural-language `remind` text asynchronously.
2. Gemma receives the exact text plus the current PA-host local timestamp and must return exactly one constrained decision: `RECALL`, `SCHEDULE|<integer seconds>|<reminder text>`, or `UNRESOLVED|<reason>`.
3. ooRexx validates a scheduling decision (positive integer, maximum 365 days, non-empty text) and constructs exactly one native `Alarm`.
4. The immediate reply records `schedule_decision_model_used=true` and `schedule_decision_source=gemma:<model>`.
5. At expiry, the target queues a fresh persistent `alarm_fire` request as principal `llmpa-alarm`.
6. Gemma later claims `alarm_fire`, re-evaluates available memory/local knowledge and returns a `REMINDER` carrying the same `reminder_id`.

A future phrase that Gemma cannot safely resolve fails closed and arms nothing. Minor ordinary typos may be interpreted by Gemma when the timing intent is clear. The explicit `remind_after` command remains a deterministic `IN <integer> <unit> ...` escape hatch for qualification. The scheduling request and alarm-fire request deliberately have different request ids.

## Authority invariant

Queue data, model output, PA memory, praise, recommendations and Alarm expiry are evidence/proposals, never execution authority. The Alarm target is timing plus queue production only. Any future tool execution must acquire authority through the AI Tool Broker/orchestrator at dispatch time.

## Calendar and eventable one-shot work

`calendar` / `read_calendar` is the command surface for `LlmPaReadCalendarTool` (`READ_ONLY`, `mutating=false`, `eventable=true`), a read-only PA capability over the in-process native ooRexx Alarm registry. It returns only currently `ARMED` future events. Fired alarms are not future calendar entries.

One Alarm represents exactly one future PA turn. It never repeats. Eventable checks therefore use this loop:

`Alarm -> Gemma -> read/check authorised function -> decide final OR explicitly arm a new one-shot Alarm`

A `check every 10 minutes until X` request MUST NOT create an implicit recurring timer. After each check Gemma evaluates the latest evidence. If X is not satisfied, a new +10 minute Alarm must be explicitly armed. Failure to arm a new Alarm ends the workflow. Alarm firing itself grants no tool authority.

# LLM PA workflows

The PA is a continuity and workflow service for a stateless LLM. A workflow is
not a conversational reminder. It is a durable, bounded instruction to wake,
perform one authorised fixed operation, evaluate its result, record the
execution, and decide whether a notification is warranted.

## Example

    Run sshnode.sh ed209e /bin/bash df every 15 minutes.
    Notify only if working-space free capacity is below 50%.
    Log every execution.

Gemma may translate the natural-language delegation into a workflow proposal,
but the PA runtime must validate and own the resulting contract:

    workflow_id       durable identity
    action            approved tool identity plus immutable argument vector
    interval          900 seconds
    predicate         deterministic result test: working-space free_percent < 50
    notification      notify on predicate true; remain silent otherwise
    continuation      arm one next one-shot wake-up after each execution
    audit             record every state transition and result

The phrase “space under 50%” must be compiled to an explicit metric and
operator. This first example means free capacity below 50%; it is not left for
the model to reinterpret on each run.

## Runtime ownership

The model does not own scheduling, command text, predicate evaluation,
rescheduling, or audit persistence. The workflow engine does.

1. Gemma proposes a structured workflow.
2. ooRexx validates the schema, interval, fixed action, predicate, limits and
   notification policy.
3. The authorised tool broker executes the immutable action.
4. ooRexx parses the result using a deterministic predicate adapter.
5. ooRexx appends an execution record, including silent/no-match outcomes.
6. The fired Alarm is over. Gemma may explicitly arm a new one-shot Alarm if the workflow is a check-until task.
7. The notification policy emits a message only when its condition is met.

An Alarm firing never grants shell or tool authority. A workflow execution must
reacquire the configured broker authority for that individual run.

## Required safety and lifecycle rules

- Actions are selected from an allowlist; model text cannot introduce a new
  executable, argument, host, or environment variable.
- The argument vector is immutable after activation.
- A workflow has an owner, creation source, expiry/cancel state, maximum run
  time, and overlap policy.
- A second alarm is not armed until the current execution has reached a
  terminal state.
- Missed, timed-out, refused, malformed, and broker-failed executions are
  logged just like successful executions.
- The default failure policy is to log and notify on operational failure; a
  workflow may explicitly choose silent failure, but never silently loses the
  record.
- Notification deduplication is explicit. A continuously-bad check does not
  send an unbounded message stream; recovery and transition policies are
  represented in the workflow.
- Cancellation prevents the next alarm and records who/what cancelled it.
- Restart recovery reconstructs workflow state from the journal and arms only
  the next due execution, with a recovery event in the audit log.

## LLM handoff

At the start of a fresh LLM session, the PA should be able to provide a compact
operating brief containing:

- active workflows and their last outcomes;
- open loops and overdue checks;
- relevant remembered facts with provenance;
- recent failures and approaches not to repeat;
- notifications emitted or suppressed and why;
- the next recommended action.

Gemma is therefore an interpreter and briefing author around a deterministic
workflow substrate, not the scheduler or an unconstrained shell assistant.

## Compaction continuity

Chat compaction is expected: the LLM may lose its conversational transcript
and start again with no reliable sense of location. The PA maintains a
prepared continuity brief at `LLMPA_CONTINUITY_PATH` (by default
`$LLMPA_STORE_ROOT/continuity.brief`).

Gemma refreshes this brief during normal idle/maintenance work from durable
memory, workflow state, open loops, recent failures, armed checks and known
unknowns. The brief is stored with its generation time and model provenance.
It is not composed during recovery.

The `handoff` / `continuity` command reads the latest valid brief directly and
returns it with `delivery=PREPARED_LOCAL_READ`. A fresh LLM can therefore begin
with “I compacted my chat history; where am I again?” without waiting for a
model call. If no valid brief exists, the PA reports that plainly and may then
request a background Gemma refresh.

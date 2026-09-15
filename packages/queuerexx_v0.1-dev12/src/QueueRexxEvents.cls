/* QueueRexxEvents.cls - OO event/trigger contracts, v0.1-dev10.
 * Event persistence is active for the recovery-safe mutation kernel. Durable
 * trigger execution remains disabled until claim/idempotency state is qualified. */

::class QueueEvent public
::constant JOB_SUBMITTED "job_submitted"
::constant JOB_CLAIMED "job_claimed"
::constant JOB_STARTED "job_started"
::constant JOB_LAUNCH_DEFERRED "job_launch_deferred"
::constant JOB_POLICY_CHECKED "job_policy_checked"
::constant JOB_POLICY_BLOCKED "job_policy_blocked"
::constant JOB_COMPLETED "job_completed"
::constant JOB_FAILED "job_failed"
::constant JOB_INTERRUPTED "job_interrupted"
::constant JOB_CANCELLED "job_cancelled"
::constant JOB_RECONCILED "job_reconciled"
::constant JOB_DUPLICATE_DETECTED "job_duplicate_detected"
::constant HEALTH_SCAN_STARTED "health_scan_started"
::constant HEALTH_SCAN_COMPLETED "health_scan_completed"
::constant SENTINEL_PASS_STARTED "sentinel_pass_started"
::constant SENTINEL_PASS_COMPLETED "sentinel_pass_completed"
::constant PROVIDER_HEALTH_CAPTURED "provider_health_captured"
::constant RUNTIME_RECOVERY_STARTED "runtime_recovery_started"
::constant RUNTIME_RECOVERY_COMPLETED "runtime_recovery_completed"
::constant WLU_STAGED "wlu_staged"

::attribute id get
::attribute type get
::attribute qid get
::attribute state get
::attribute occurredAt get
::attribute data get
::method init
  expose id type qid state occurredAt data
  use arg idArg, typeArg, qidArg = "", stateArg = "", occurredAtArg = "", dataArg = .nil
  id = idArg~string; type = typeArg~string; qid = qidArg~string; state = stateArg~string; occurredAt = occurredAtArg~string
  if dataArg == .nil then data = .Directory~new; else data = dataArg
::method asDirectory
  expose id type qid state occurredAt data
  d = .Directory~new
  d["id"] = id; d["type"] = type; d["qid"] = qid; d["state"] = state; d["occurred_at"] = occurredAt; d["data"] = data
  return d

::class QueueEventSink public
::method append abstract

::class QueueTrigger public
::method id abstract
::method eventTypes abstract
::method fire abstract

::class QueueTriggerRegistry public
::method init
  expose triggers
  triggers = .Directory~new
::method register
  expose triggers
  use arg trigger
  triggers[trigger~id] = trigger
  return self
::method get
  expose triggers
  use strict arg triggerId
  if triggers~hasIndex(triggerId~string) then return triggers[triggerId~string]
  return .nil
::method matching
  expose triggers
  use arg eventType
  a = .Array~new
  do id over triggers
    t = triggers[id]
    do et over t~eventTypes
      if et == eventType then do; a~append(t); leave; end
    end
  end
  return a

::class QueueEventBus public
::method init
  expose sinks triggerRegistry
  use arg triggerRegistryArg = .nil
  sinks = .Array~new
  if triggerRegistryArg == .nil then triggerRegistry = .QueueTriggerRegistry~new
  else triggerRegistry = triggerRegistryArg
::method addSink
  expose sinks
  use arg sink
  sinks~append(sink)
  return self
::method publish
  expose triggerRegistry
  use arg event
  self~publishChecked(event)
  /* Trigger execution is intentionally not automatic in dev3. Recovery-safe
   * durable claim/idempotency state must exist before triggers may fire. */
  return triggerRegistry~matching(event~type)

::method publishChecked
  expose sinks
  use arg event
  ok = .true
  do sink over sinks
    if \sink~append(event) then ok = .false
  end
  return ok

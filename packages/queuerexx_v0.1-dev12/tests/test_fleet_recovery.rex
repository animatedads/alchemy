root = "/mnt/data/queuerexx-dev10-fleet-recovery-test"
address system "rm -rf " || root
call SysMkDir root
call SysMkDir root || "/logs"
monitor = .FakeRuntimeMonitor~new
recovery = .FakeRecoveryManager~new
sink = .MemoryEventSink~new
bus = .QueueEventBus~new
bus~addSink(sink)
orchestrator = .QueueFleetRecoveryOrchestrator~new(root, monitor, recovery, bus)
report = orchestrator~run(10)
call must report["schema"] == .QueueSchema~FLEET_RECOVERY, "schema"
call must report["scanned"] == 3, "scanned"
call must report["recovery_count"] == 1, "one deterministic recovery"
call must report["deferred_count"] == 1, "one deferred"
call must report["manual_review_count"] == 1, "one manual review"
call must recovery~calls == 1, "recovery manager called once"
call must recovery~lastQid == "q-reconcile", "correct qid recovered"
call must sink~events~items == 2, "started and completed events"
call must sink~events[1]~type == .QueueEvent~RUNTIME_RECOVERY_STARTED, "start event"
call must sink~events[2]~type == .QueueEvent~RUNTIME_RECOVERY_COMPLETED, "complete event"
say "PASS bounded fleet recovery follows typed runtime recommendations"
exit 0

must: procedure
  parse arg conditionValue, message
  if \conditionValue then do; say "FAIL" message; exit 1; end
  return


::class FleetTestItem public
::method make class
  use strict arg qid, relation, action, state
  d = .Directory~new
  d["qid"] = qid; d["relation"] = relation; d["recommended_action"] = action
  r = .Directory~new; r["state"] = state; d["queue_record"] = r
  return d

::class FakeRuntimeMonitor public
::method scan
  use arg maxRecords
  items = .Array~new
  items~append(.FleetTestItem~make("q-reconcile", .QueueRuntimeRelation~NAME_EXIT_PENDING, .QueueRuntimeAction~NAME_RECONCILE, .QueueState~NAME_RUNNING))
  items~append(.FleetTestItem~make("q-defer", .QueueRuntimeRelation~NAME_OBSERVATION_DEFERRED, .QueueRuntimeAction~NAME_DEFER, .QueueState~NAME_RUNNING))
  items~append(.FleetTestItem~make("q-manual", .QueueRuntimeRelation~NAME_DEAD_WITHOUT_EXIT, .QueueRuntimeAction~NAME_MANUAL_REVIEW, .QueueState~NAME_RUNNING))
  d = .Directory~new; d["items"] = items; d["count"] = items~items
  return d

::class FakeRecoveryManager public
::attribute calls get
::attribute lastQid get
::method init
  expose calls lastQid
  calls = 0; lastQid = ""
::method recoverQid
  expose calls lastQid
  use strict arg qid
  calls += 1; lastQid = qid
  d = .Directory~new
  qr = .Directory~new; qr["state"] = .QueueState~NAME_DONE; d["queue_record"] = qr
  d["qid"] = qid; d["relation"] = .QueueRuntimeRelation~NAME_QUEUE_TERMINAL; d["recommended_action"] = .QueueRuntimeAction~NAME_NONE
  status = .QueueRuntimeStatus~new(qid, .QueueRuntimeRelation~QUEUE_TERMINAL, .QueueRuntimeAction~NONE, d)
  return .QueueRuntimeRecoveryReceipt~new(qid, status, .nil, "fake recovered")

::class MemoryEventSink subclass QueueEventSink
::attribute events get
::method init
  expose events
  events = .Array~new
::method append
  expose events
  use strict arg event
  events~append(event)
  return .true

::requires "QueueRexxFleetRecovery.cls"

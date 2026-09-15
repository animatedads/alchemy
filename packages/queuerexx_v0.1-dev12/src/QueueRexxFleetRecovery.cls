/* QueueRexxFleetRecovery.cls - bounded fleet runtime recovery orchestration, v0.1-dev10.
 *
 * The orchestrator does not diagnose independently.  It consumes the typed
 * QueueRuntimeMonitor projection and only invokes the already-qualified
 * QueueRuntimeRecoveryManager for RECONCILE recommendations.  DEFER and
 * MANUAL_REVIEW are reported, never silently promoted to mutation.
 */

::class QueueFleetRecoveryOrchestrator public
::attribute root get
::attribute monitor get
::attribute recovery get
::attribute eventBus get
::attribute triggerDispatcher get
::method init
  expose root monitor recovery eventBus triggerDispatcher
  use arg rootArg, monitorArg = .nil, recoveryArg = .nil, eventBusArg = .nil, triggerDispatcherArg = .nil
  root = rootArg~string
  if monitorArg == .nil then monitor = .QueueRuntimeMonitor~new(root); else monitor = monitorArg
  if recoveryArg == .nil then recovery = .QueueRuntimeRecoveryManager~new(root, .nil, monitor); else recovery = recoveryArg
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(root))
  end
  else eventBus = eventBusArg
  triggerDispatcher = triggerDispatcherArg

::method run
  expose monitor recovery eventBus triggerDispatcher
  use arg maxRecordsArg = 100
  maxRecords = maxRecordsArg + 0; if maxRecords < 1 then maxRecords = 100
  scan = monitor~scan(maxRecords)
  recovered = .Array~new
  deferred = .Array~new
  manual = .Array~new
  do item over scan["items"]
    action = item["recommended_action"]~string
    if action == .QueueRuntimeAction~NAME_RECONCILE then do
      qid = item["qid"]~string
      startId = "runtime-recovery-" || qid || "-" || item["relation"]~string
      data = .Directory~new
      data["detail"] = "provider-aware fleet recovery relation=" || item["relation"]
      data["runtime_status"] = item
      startedEvent = .QueueEvent~new(startId, .QueueEvent~RUNTIME_RECOVERY_STARTED, qid, item["queue_record"]["state"], .DateTime~new~string, data)
      eventBus~publishChecked(startedEvent)
      if triggerDispatcher \= .nil then triggerDispatcher~dispatch(startedEvent)
      receipt = recovery~recoverQid(qid)
      recovered~append(receipt~asDirectory)
      completedData = .Directory~new
      completedData["detail"] = "provider-aware fleet recovery completed"
      completedData["recovery"] = receipt~asDirectory
      completedEvent = .QueueEvent~new(startId || "-completed", .QueueEvent~RUNTIME_RECOVERY_COMPLETED, qid, receipt~status~asDirectory["queue_record"]["state"], .DateTime~new~string, completedData)
      eventBus~publishChecked(completedEvent)
      if triggerDispatcher \= .nil then triggerDispatcher~dispatch(completedEvent)
    end
    else if action == .QueueRuntimeAction~NAME_DEFER then deferred~append(item)
    else if action == .QueueRuntimeAction~NAME_MANUAL_REVIEW then manual~append(item)
  end
  d = .Directory~new
  d["schema"] = .QueueSchema~FLEET_RECOVERY
  d["bounded"] = .JSONBoolean~true
  d["max_records"] = maxRecords
  d["scanned"] = scan["count"]
  d["recoveries"] = recovered
  d["recovery_count"] = recovered~items
  d["deferred"] = deferred
  d["deferred_count"] = deferred~items
  d["manual_review"] = manual
  d["manual_review_count"] = manual~items
  d["authority_note"] = "fleet orchestration follows QueueRuntimeMonitor recommendations; only RECONCILE may invoke typed recovery"
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxMutation.cls"
::requires "QueueRexxRuntimeRecovery.cls"

/* QueueRexxRuntimeRecovery.cls - provider-aware runtime monitoring/recovery, v0.1-dev9.
 *
 * Runtime status is a read model.  The QueueBash filesystem remains queue-state
 * authority; runner providers supply execution evidence; the immutable
 * QueueExecutionJournal supplies launch/recovery evidence.  Only the separate
 * recovery manager may ask QueueExecutionService to reconcile state.
 */

::class QueueRuntimeRelation public
::constant NONE 0
::constant QUEUE_ONLY 1
::constant PREPARED_ONLY 2
::constant IN_SYNC 3
::constant METADATA_MISSING 4
::constant JOURNAL_MISSING 5
::constant MULTIPLE_ACTIVE 6
::constant EXECUTION_ID_MISMATCH 7
::constant PROVIDER_UNAVAILABLE 8
::constant QUEUE_TERMINAL 9
::constant EXIT_PENDING 10
::constant DEAD_WITHOUT_EXIT 11
::constant OBSERVATION_DEFERRED 12
::constant NAME_NONE "none"
::constant NAME_QUEUE_ONLY "queue_only"
::constant NAME_PREPARED_ONLY "prepared_only"
::constant NAME_IN_SYNC "in_sync"
::constant NAME_METADATA_MISSING "metadata_missing"
::constant NAME_JOURNAL_MISSING "journal_missing"
::constant NAME_MULTIPLE_ACTIVE "multiple_active"
::constant NAME_EXECUTION_ID_MISMATCH "execution_id_mismatch"
::constant NAME_PROVIDER_UNAVAILABLE "provider_unavailable"
::constant NAME_QUEUE_TERMINAL "queue_terminal"
::constant NAME_EXIT_PENDING "exit_pending_reconcile"
::constant NAME_DEAD_WITHOUT_EXIT "dead_without_exit"
::constant NAME_OBSERVATION_DEFERRED "observation_deferred"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg valueArg
  value = valueArg + 0
  select
    when value == self~NONE then return self~NAME_NONE
    when value == self~QUEUE_ONLY then return self~NAME_QUEUE_ONLY
    when value == self~PREPARED_ONLY then return self~NAME_PREPARED_ONLY
    when value == self~IN_SYNC then return self~NAME_IN_SYNC
    when value == self~METADATA_MISSING then return self~NAME_METADATA_MISSING
    when value == self~JOURNAL_MISSING then return self~NAME_JOURNAL_MISSING
    when value == self~MULTIPLE_ACTIVE then return self~NAME_MULTIPLE_ACTIVE
    when value == self~EXECUTION_ID_MISMATCH then return self~NAME_EXECUTION_ID_MISMATCH
    when value == self~PROVIDER_UNAVAILABLE then return self~NAME_PROVIDER_UNAVAILABLE
    when value == self~QUEUE_TERMINAL then return self~NAME_QUEUE_TERMINAL
    when value == self~EXIT_PENDING then return self~NAME_EXIT_PENDING
    when value == self~DEAD_WITHOUT_EXIT then return self~NAME_DEAD_WITHOUT_EXIT
    when value == self~OBSERVATION_DEFERRED then return self~NAME_OBSERVATION_DEFERRED
    otherwise return self~NAME_UNKNOWN
  end

::class QueueRuntimeAction public
::constant NONE 0
::constant RECONCILE 1
::constant DEFER 2
::constant MANUAL_REVIEW 3
::constant NAME_NONE "none"
::constant NAME_RECONCILE "reconcile"
::constant NAME_DEFER "defer"
::constant NAME_MANUAL_REVIEW "manual_review"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg valueArg
  value = valueArg + 0
  select
    when value == self~NONE then return self~NAME_NONE
    when value == self~RECONCILE then return self~NAME_RECONCILE
    when value == self~DEFER then return self~NAME_DEFER
    when value == self~MANUAL_REVIEW then return self~NAME_MANUAL_REVIEW
    otherwise return self~NAME_UNKNOWN
  end

::class QueueRuntimeStatus public
::attribute qid get
::attribute relation get
::attribute action get
::attribute directory get
::method init
  expose qid relation action directory
  use strict arg qidArg, relationArg, actionArg, directoryArg
  qid = qidArg~string
  relation = relationArg + 0
  action = actionArg + 0
  directory = directoryArg
::method asDirectory
  expose directory
  return directory
::method shouldReconcile
  expose action
  return action == .QueueRuntimeAction~RECONCILE
::method ambiguous
  expose action
  return action == .QueueRuntimeAction~MANUAL_REVIEW

::class QueueRuntimeMonitor public
::attribute root get
::attribute store get
::attribute providerRegistry get
::attribute journal get
::method init
  expose root store providerRegistry journal
  use arg rootArg, providerRegistryArg = .nil, journalArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if providerRegistryArg == .nil then providerRegistry = .QueueProviderRegistry~builtins
  else providerRegistry = providerRegistryArg
  if journalArg == .nil then journal = .QueueExecutionJournal~new(root)
  else journal = journalArg

::method project
  expose store providerRegistry journal
  use strict arg qidArg
  qid = qidArg~string
  matches = store~findAll(qid)
  active = self~activeIntents(qid)
  d = .Directory~new
  d["schema"] = .QueueSchema~RUNTIME_STATUS
  d["qid"] = qid
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["queue_record_count"] = matches~items
  d["journal_active_count"] = active~items
  d["journal_execution_ids"] = self~executionIds(active)
  d["authority_note"] = "queue filesystem owns lifecycle; execution journal and runner/provider probes are evidence only"

  if matches~items == 0 then do
    if active~items == 0 then return self~finish(d, .QueueRuntimeRelation~NONE, .QueueRuntimeAction~NONE, .false, "queue record and active QueueRexx execution intent are absent")
    if active~items == 1 then return self~finish(d, .QueueRuntimeRelation~PREPARED_ONLY, .QueueRuntimeAction~MANUAL_REVIEW, .false, "active execution intent exists without an authoritative queue record")
    return self~finish(d, .QueueRuntimeRelation~MULTIPLE_ACTIVE, .QueueRuntimeAction~MANUAL_REVIEW, .false, "multiple active execution intents exist without an authoritative queue record")
  end

  if matches~items > 1 then do
    states = .Array~new
    do r over matches; states~append(r~stateName); end
    d["states_seen"] = states
    return self~finish(d, .QueueRuntimeRelation~MULTIPLE_ACTIVE, .QueueRuntimeAction~MANUAL_REVIEW, .false, "duplicate QueueBash QID state must be diagnosed before runtime recovery")
  end

  record = matches[1]
  self~addRecord(d, record)
  executionId = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  providerId = record~field(.QueueRecord~FIELD_RUNNER_USED, "")

  if record~state \= .QueueState~RUNNING then do
    self~addMatchingJournal(d, active, executionId)
    return self~finish(d, .QueueRuntimeRelation~QUEUE_TERMINAL, .QueueRuntimeAction~NONE, .true, "queue record is non-running; runtime evidence cannot override queue authority")
  end

  if active~items > 1 then return self~finish(d, .QueueRuntimeRelation~MULTIPLE_ACTIVE, .QueueRuntimeAction~MANUAL_REVIEW, .false, "multiple active execution intents for one running QID")

  if executionId == "" then do
    if active~items == 1 then do
      self~addMatchingJournal(d, active, active[1]["execution_id"]~string)
      return self~finish(d, .QueueRuntimeRelation~METADATA_MISSING, .QueueRuntimeAction~RECONCILE, .true, "running record is missing execution metadata but exactly one durable launch intent exists")
    end
    return self~finish(d, .QueueRuntimeRelation~QUEUE_ONLY, .QueueRuntimeAction~DEFER, .true, "running record has no QueueRexx execution metadata or active execution intent")
  end

  matching = self~findIntent(active, executionId)
  if active~items == 1 then do
    if matching == .nil then do
      self~addMatchingJournal(d, active, active[1]["execution_id"]~string)
      return self~finish(d, .QueueRuntimeRelation~EXECUTION_ID_MISMATCH, .QueueRuntimeAction~MANUAL_REVIEW, .false, "queue record execution id disagrees with active execution journal")
    end
    self~addMatchingJournal(d, active, executionId)
  end
  else d["journal_relation"] = .QueueRuntimeRelation~NAME_JOURNAL_MISSING

  exitCode = self~readExitCode(record~field(.QueueRecord~FIELD_EXECUTION_EXIT_FILE, ""))
  if exitCode \== .nil then do
    d["durable_exit_present"] = .JSONBoolean~true
    d["exit_code"] = exitCode
    return self~finish(d, .QueueRuntimeRelation~EXIT_PENDING, .QueueRuntimeAction~RECONCILE, .true, "durable exit evidence is present and should be reconciled into queue authority")
  end
  d["durable_exit_present"] = .JSONBoolean~false
  d["exit_code"] = .nil

  if providerId == "" then return self~finish(d, .QueueRuntimeRelation~PROVIDER_UNAVAILABLE, .QueueRuntimeAction~DEFER, .true, "running QueueRexx execution has no recorded runner provider")
  provider = providerRegistry~get(.QueueProviderCategory~RUNNER, providerId)
  if provider == .nil then return self~finish(d, .QueueRuntimeRelation~PROVIDER_UNAVAILABLE, .QueueRuntimeAction~DEFER, .true, "recorded runner provider is not registered in this process")

  observation = provider~observe(record)
  d["observation"] = observation~asDirectory
  if observation~status == .QueueJobObservation~LIVE then do
    if active~items == 0 then return self~finish(d, .QueueRuntimeRelation~JOURNAL_MISSING, .QueueRuntimeAction~DEFER, .true, "provider reports live execution but immutable execution intent is not available locally")
    return self~finish(d, .QueueRuntimeRelation~IN_SYNC, .QueueRuntimeAction~NONE, .true, "queue metadata, execution journal and provider observation describe a live execution")
  end
  if observation~isDeferred then return self~finish(d, .QueueRuntimeRelation~OBSERVATION_DEFERRED, .QueueRuntimeAction~DEFER, .true, "provider observation is inconclusive; do not manufacture a terminal state")
  return self~finish(d, .QueueRuntimeRelation~DEAD_WITHOUT_EXIT, .QueueRuntimeAction~MANUAL_REVIEW, .false, "provider reports non-live execution but no durable exit result exists")

::method scan
  expose store
  use arg maxRecordsArg = 100
  maxRecords = maxRecordsArg + 0
  if maxRecords < 1 then maxRecords = 100
  out = .Array~new
  seen = .Directory~new
  records = store~records(.QueueState~ALL)
  do record over records
    qid = record~qid
    if seen~hasIndex(qid) then iterate
    seen[qid] = 1
    if record~state \= .QueueState~RUNNING & record~field(.QueueRecord~FIELD_EXECUTION_ID, "") == "" then iterate
    out~append(self~project(qid)~asDirectory)
    if out~items >= maxRecords then leave
  end
  d = .Directory~new
  d["schema"] = .QueueSchema~RUNTIME_SCAN
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["bounded"] = .JSONBoolean~true
  d["max_records"] = maxRecords
  d["items"] = out
  d["count"] = out~items
  return d

::method activeIntents private
  expose journal
  use strict arg qid
  prepared = journal~preparedForQid(qid)
  active = .Array~new
  do doc over prepared
    executionId = doc["execution_id"]~string
    if journal~phaseExists(executionId, .QueueExecutionPhase~ABORTED) then iterate
    if journal~phaseExists(executionId, .QueueExecutionPhase~TERMINAL_RECORDED) then iterate
    active~append(doc)
  end
  return active

::method executionIds private
  use strict arg docs
  ids = .Array~new
  do doc over docs; ids~append(doc["execution_id"]~string); end
  return ids

::method findIntent private
  use strict arg docs, executionId
  do doc over docs
    if doc["execution_id"]~string == executionId then return doc
  end
  return .nil

::method addMatchingJournal private
  expose journal
  use strict arg d, docs, executionId
  doc = self~findIntent(docs, executionId)
  if doc == .nil then return
  x = .Directory~new
  x["execution_id"] = executionId
  x["prepared"] = .JSONBoolean~true
  x["launched"] = .QueueRexxUtil~jsonBoolean(journal~phaseExists(executionId, .QueueExecutionPhase~LAUNCHED))
  x["metadata_recorded"] = .QueueRexxUtil~jsonBoolean(journal~phaseExists(executionId, .QueueExecutionPhase~METADATA_RECORDED))
  x["terminal_recorded"] = .QueueRexxUtil~jsonBoolean(journal~phaseExists(executionId, .QueueExecutionPhase~TERMINAL_RECORDED))
  x["aborted"] = .QueueRexxUtil~jsonBoolean(journal~phaseExists(executionId, .QueueExecutionPhase~ABORTED))
  x["ambiguous"] = .QueueRexxUtil~jsonBoolean(journal~phaseExists(executionId, .QueueExecutionPhase~AMBIGUOUS))
  d["journal"] = x

::method addRecord private
  use strict arg d, record
  x = .Directory~new
  x["state"] = record~stateName
  x["state_code"] = record~state
  x["path"] = record~path
  x["execution_id"] = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  x["provider"] = record~field(.QueueRecord~FIELD_RUNNER_USED, "")
  x["pid"] = record~field(.QueueRecord~FIELD_RUN_PID, "")
  x["pgid"] = record~field(.QueueRecord~FIELD_RUN_PGID, "")
  x["systemd_unit"] = record~field(.QueueRecord~FIELD_SYSTEMD_UNIT, "")
  x["pid_file"] = record~field(.QueueRecord~FIELD_EXECUTION_PID_FILE, "")
  x["exit_file"] = record~field(.QueueRecord~FIELD_EXECUTION_EXIT_FILE, "")
  d["queue_record"] = x

::method finish private
  use strict arg d, relation, action, okValue, detail
  d["relation"] = .QueueRuntimeRelation~name(relation)
  d["relation_code"] = relation
  d["recommended_action"] = .QueueRuntimeAction~name(action)
  d["ok"] = .QueueRexxUtil~jsonBoolean(okValue)
  d["detail"] = detail
  return .QueueRuntimeStatus~new(d["qid"], relation, action, d)

::method readExitCode private
  use strict arg path
  if path == "" then return .nil
  if \SysFileExists(path) then return .nil
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return .nil
  line = s~lineIn~strip
  s~close
  if \line~datatype("W") then return .nil
  return line + 0

::class QueueRuntimeRecoveryReceipt public
::attribute qid get
::attribute status get
::attribute executionReceipt get
::attribute detail get
::method init
  expose qid status executionReceipt detail
  use strict arg qidArg, statusArg, executionReceiptArg = .nil, detailArg = ""
  qid = qidArg~string
  status = statusArg
  executionReceipt = executionReceiptArg
  detail = detailArg~string
::method asDirectory
  expose qid status executionReceipt detail
  d = .Directory~new
  d["schema"] = .QueueSchema~RUNTIME_RECOVERY
  d["qid"] = qid
  d["runtime_status"] = status~asDirectory
  d["detail"] = detail
  if executionReceipt == .nil then d["execution_reconcile"] = .nil
  else d["execution_reconcile"] = executionReceipt~asDirectory
  return d

::class QueueRuntimeRecoveryManager public
::attribute monitor get
::attribute executionService get
::method init
  expose monitor executionService
  use arg rootArg, executionServiceArg = .nil, monitorArg = .nil
  root = rootArg~string
  if executionServiceArg == .nil then executionService = .QueueExecutionService~new(root)
  else executionService = executionServiceArg
  if monitorArg == .nil then monitor = .QueueRuntimeMonitor~new(root)
  else monitor = monitorArg
::method recoverQid
  expose monitor executionService
  use strict arg qidArg
  status = monitor~project(qidArg)
  if \status~shouldReconcile then return .QueueRuntimeRecoveryReceipt~new(qidArg, status, .nil, "projection does not authorize automatic execution reconciliation")
  receipt = executionService~reconcile(qidArg)
  return .QueueRuntimeRecoveryReceipt~new(qidArg, monitor~project(qidArg), receipt, "execution reconciliation requested from typed runtime evidence")
::method recoverRunning
  expose monitor
  use arg maxRecordsArg = 100
  scan = monitor~scan(maxRecordsArg)
  out = .Array~new
  do item over scan["items"]
    if item["recommended_action"] \= .QueueRuntimeAction~NAME_RECONCILE then iterate
    out~append(self~recoverQid(item["qid"])~asDirectory)
  end
  d = .Directory~new
  d["schema"] = .QueueSchema~RUNTIME_RECOVERY
  d["bounded"] = .JSONBoolean~true
  d["max_records"] = maxRecordsArg + 0
  d["recoveries"] = out
  d["count"] = out~items
  return d

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxExecution.cls"

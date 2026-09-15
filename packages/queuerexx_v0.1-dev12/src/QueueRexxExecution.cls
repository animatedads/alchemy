/* QueueRexxExecution.cls - typed recovery-safe execution pilot, v0.1-dev8.
 *
 * Queue state remains authoritative in the shared QueueBash filesystem.
 * Runner providers own launch/observe/terminate mechanics only.  Execution
 * intent and launch locators are journalled so a QueueRexx restart does not
 * have to guess whether a process was started.
 */

::class QueueExecutionStatus public
::constant OK 1
::constant INVALID 2
::constant LOCK_FAILED 3
::constant PROVIDER_UNAVAILABLE 4
::constant PREPARE_FAILED 5
::constant LAUNCH_FAILED 6
::constant METADATA_FAILED 7
::constant STILL_RUNNING 8
::constant DEFERRED 9
::constant TERMINAL 10
::constant AMBIGUOUS 11
::constant LOST_RACE 12
::constant ALREADY_STARTED 13
::constant NO_EXECUTION 14
::constant TERMINATE_FAILED 15
::constant NAME_OK "ok"
::constant NAME_INVALID "invalid"
::constant NAME_LOCK_FAILED "lock_failed"
::constant NAME_PROVIDER_UNAVAILABLE "provider_unavailable"
::constant NAME_PREPARE_FAILED "prepare_failed"
::constant NAME_LAUNCH_FAILED "launch_failed"
::constant NAME_METADATA_FAILED "metadata_failed"
::constant NAME_STILL_RUNNING "still_running"
::constant NAME_DEFERRED "deferred"
::constant NAME_TERMINAL "terminal"
::constant NAME_AMBIGUOUS "ambiguous"
::constant NAME_LOST_RACE "lost_race"
::constant NAME_ALREADY_STARTED "already_started"
::constant NAME_NO_EXECUTION "no_execution"
::constant NAME_TERMINATE_FAILED "terminate_failed"
::method name class
  use strict arg value
  select
    when value == self~OK then return self~NAME_OK
    when value == self~INVALID then return self~NAME_INVALID
    when value == self~LOCK_FAILED then return self~NAME_LOCK_FAILED
    when value == self~PROVIDER_UNAVAILABLE then return self~NAME_PROVIDER_UNAVAILABLE
    when value == self~PREPARE_FAILED then return self~NAME_PREPARE_FAILED
    when value == self~LAUNCH_FAILED then return self~NAME_LAUNCH_FAILED
    when value == self~METADATA_FAILED then return self~NAME_METADATA_FAILED
    when value == self~STILL_RUNNING then return self~NAME_STILL_RUNNING
    when value == self~DEFERRED then return self~NAME_DEFERRED
    when value == self~TERMINAL then return self~NAME_TERMINAL
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    when value == self~LOST_RACE then return self~NAME_LOST_RACE
    when value == self~ALREADY_STARTED then return self~NAME_ALREADY_STARTED
    when value == self~NO_EXECUTION then return self~NAME_NO_EXECUTION
    when value == self~TERMINATE_FAILED then return self~NAME_TERMINATE_FAILED
    otherwise return "unknown"
  end

::class QueueExecutionPhase public
::constant PREPARED 1
::constant LAUNCHED 2
::constant METADATA_RECORDED 3
::constant TERMINAL_RECORDED 4
::constant ABORTED 5
::constant AMBIGUOUS 6
::constant NAME_PREPARED "prepared"
::constant NAME_LAUNCHED "launched"
::constant NAME_METADATA_RECORDED "metadata_recorded"
::constant NAME_TERMINAL_RECORDED "terminal_recorded"
::constant NAME_ABORTED "aborted"
::constant NAME_AMBIGUOUS "ambiguous"
::method name class
  use strict arg value
  select
    when value == self~PREPARED then return self~NAME_PREPARED
    when value == self~LAUNCHED then return self~NAME_LAUNCHED
    when value == self~METADATA_RECORDED then return self~NAME_METADATA_RECORDED
    when value == self~TERMINAL_RECORDED then return self~NAME_TERMINAL_RECORDED
    when value == self~ABORTED then return self~NAME_ABORTED
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    otherwise return "unknown"
  end

::class QueueExecutionCode public
::constant STARTED "EXECUTION_STARTED"
::constant RUNNING "EXECUTION_RUNNING"
::constant EXITED "EXECUTION_EXITED"
::constant DEFERRED "EXECUTION_DEFERRED"
::constant DEAD_WITHOUT_EXIT "EXECUTION_DEAD_WITHOUT_EXIT_EVIDENCE"
::constant RECORD_MISSING "EXECUTION_RECORD_MISSING"
::constant RECORD_DUPLICATE "EXECUTION_RECORD_DUPLICATE"
::constant NOT_RUNNING "EXECUTION_NOT_RUNNING"
::constant ALREADY_STARTED "EXECUTION_ALREADY_STARTED"
::constant PROVIDER_NOT_SELECTED "EXECUTION_PROVIDER_NOT_SELECTED"
::constant PREPARE_FAILED "EXECUTION_PROVIDER_PREPARE_FAILED"
::constant LAUNCH_FAILED "EXECUTION_PROVIDER_LAUNCH_FAILED"
::constant METADATA_FAILED "EXECUTION_METADATA_FAILED"
::constant TERMINATED "EXECUTION_TERMINATED"
::constant TERMINATE_FAILED "EXECUTION_TERMINATE_FAILED"
::constant TERMINATE_UNCONFIRMED "EXECUTION_TERMINATION_UNCONFIRMED"
::constant CANCELLED "EXECUTION_CANCELLED"
::constant WLU_TERMINAL_REQUIRED "EXECUTION_WLU_TERMINAL_REQUIRED"
::constant RECOVERED_LAUNCH "EXECUTION_RECOVERED_LAUNCH"
::constant LOCK_FAILED "EXECUTION_LOCK_FAILED"
::constant WLU_TERMINAL_NOT_COMMITTED "WLU_TERMINAL_NOT_COMMITTED"
::constant TERMINAL_TRANSITION_FAILED "EXECUTION_TERMINAL_TRANSITION_FAILED"
::constant WLU_CANCEL_NOT_COMMITTED "WLU_CANCEL_NOT_COMMITTED"
::constant CANCEL_TRANSITION_FAILED "EXECUTION_CANCEL_TRANSITION_FAILED"

::class QueueExecutionPath public
::constant DIRECTORY_NAME "queuerexx-executions"
::method directory class
  use strict arg root
  return root || "/" || .QueueMutationPath~LOGS || "/" || self~DIRECTORY_NAME
::method pidFile class
  use strict arg root, executionId
  return self~directory(root) || "/" || executionId || ".pid"
::method exitFile class
  use strict arg root, executionId
  return self~directory(root) || "/" || executionId || ".exit"
::method logFile class
  use strict arg root, qid
  return root || "/logs/" || qid || ".log"

::class QueueExecutionName public
::constant SYSTEMD_PREFIX "queuerexx-"
::constant SYSTEMD_SUFFIX ".service"
::constant SYSTEMD_MAX_BASE_LENGTH 180
::method systemdUnit class
  use strict arg qidArg, executionIdArg
  raw = self~SYSTEMD_PREFIX || qidArg~string || "-" || executionIdArg~string~right(12)
  safe = ""
  allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-"
  do i = 1 to raw~length
    c = raw~substr(i, 1)
    if allowed~pos(c) > 0 then safe ||= c
    else safe ||= "_"
  end
  if safe~length > self~SYSTEMD_MAX_BASE_LENGTH then safe = safe~left(self~SYSTEMD_MAX_BASE_LENGTH)
  if safe~right(self~SYSTEMD_SUFFIX~length) \= self~SYSTEMD_SUFFIX then safe ||= self~SYSTEMD_SUFFIX
  return safe

::class QueueExecutionReceipt public
::attribute status get
::attribute qid get
::attribute executionId get
::attribute code get
::attribute detail get
::attribute providerId get
::attribute state get
::attribute exitCode get
::attribute data get
::method init
  expose status qid executionId code detail providerId state exitCode data
  use arg statusArg, qidArg = "", executionIdArg = "", codeArg = "", detailArg = "", providerArg = "", stateArg = (.QueueState~UNKNOWN), exitArg = .nil, dataArg = .nil
  status = statusArg + 0; qid = qidArg~string; executionId = executionIdArg~string
  code = codeArg~string; detail = detailArg~string; providerId = providerArg~string
  state = .QueueState~coerce(stateArg); exitCode = exitArg
  if dataArg == .nil then data = .Directory~new; else data = dataArg
::method ok
  expose status
  return status == .QueueExecutionStatus~OK | status == .QueueExecutionStatus~TERMINAL | status == .QueueExecutionStatus~STILL_RUNNING | status == .QueueExecutionStatus~DEFERRED
::method asDirectory
  expose status qid executionId code detail providerId state exitCode data
  d = .Directory~new
  d["schema"] = .QueueSchema~EXECUTION
  d["status"] = .QueueExecutionStatus~name(status)
  d["qid"] = qid
  d["execution_id"] = executionId
  d["code"] = code
  d["detail"] = detail
  d["provider"] = providerId
  d["state"] = .QueueState~name(state)
  if exitCode == .nil then d["exit_code"] = .nil
  else d["exit_code"] = exitCode + 0
  d["data"] = data
  return d

::class QueueExecutionJournal public
::attribute root get
::attribute fileSystem get
::method init
  expose root fileSystem
  use strict arg rootArg, fileSystemArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new; else fileSystem = fileSystemArg
::method directory
  expose root
  return .QueueExecutionPath~directory(root)
::method newExecutionId
  use strict arg qid
  return qid~string || "." || .QueueKernelTime~nonce || "." || random(0,999999)~right(6,"0")
::method phasePath
  use strict arg executionId, phase
  return self~directory || "/" || executionId || "." || .QueueExecutionPhase~name(phase) || ".json"
::method phaseExists
  use strict arg executionId, phase
  return SysFileExists(self~phasePath(executionId, phase)) == 1
::method writePhase
  expose root fileSystem
  use strict arg executionId, phase, payload
  dir = self~directory
  if \fileSystem~ensureDirectory(dir) then return .false
  path = self~phasePath(executionId, phase)
  if SysFileExists(path) then return .false
  temp = path || ".tmp." || random(0,999999)~right(6,"0")
  doc = .Directory~new
  doc["schema"] = .QueueSchema~EXECUTION
  doc["execution_id"] = executionId
  doc["phase"] = .QueueExecutionPhase~name(phase)
  doc["recorded_at"] = .QueueKernelTime~nowIso
  doc["execution"] = payload
  .QueueSerialization~toJsonFile(doc, temp)
  if \SysFileExists(temp) then return .false
  if \fileSystem~replace(temp, path) then do
    call SysFileDelete temp
    return .false
  end
  fileSystem~ensureOwnerLike(dir, root)
  fileSystem~ensureOwnerLike(path, root)
  return .true
::method readPhase
  use strict arg executionId, phase
  path = self~phasePath(executionId, phase)
  if \SysFileExists(path) then return .nil
  return self~readDocument(path)
::method preparedForQid
  use strict arg qidArg
  qid = qidArg~string
  arr = .Array~new
  dir = self~directory
  if \SysFileExists(dir) then return arr
  drop execfiles.
  call SysFileTree dir || "/*.prepared.json", "execfiles.", "FO"
  do i = 1 to execfiles.0
    doc = self~readDocument(execfiles.i)
    if doc == .nil | \doc~hasIndex("execution") then iterate
    e = doc["execution"]
    if e~hasIndex("qid") & e["qid"]~string == qid then arr~append(doc)
  end
  return arr
::method readDocument private
  use strict arg path
  signal on syntax name malformed
  doc = .QueueSerialization~fromJsonFile(path)
  signal off syntax
  return doc
malformed:
  signal off syntax
  return .nil

/* Runtime metadata is appended via an atomic file replacement.  QueueBash
 * unknown fields and original bytes are preserved; QueueRecord intentionally
 * uses the last occurrence of a scalar field, matching QueueBash append-style
 * runtime metadata. */
::class QueueExecutionMetadataWriter public
::attribute fileSystem get
::method init
  expose fileSystem
  use arg fileSystemArg = .nil
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new; else fileSystem = fileSystemArg
::method writeHandle
  expose fileSystem
  use strict arg record, handle
  path = record~path
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return .false
  content = s~charIn(, s~chars)
  s~close
  if content \= "" & content~right(1) \= "0a"x then content ||= "0a"x
  content ||= .QueueRecord~FIELD_RUNNER_USED || "=" || .QueueBashRecordCodec~quote(handle~providerId) || "0a"x
  if handle~pid \= "" then content ||= .QueueRecord~FIELD_RUN_PID || "=" || .QueueBashRecordCodec~quote(handle~pid) || "0a"x
  if handle~pgid \= "" then content ||= .QueueRecord~FIELD_RUN_PGID || "=" || .QueueBashRecordCodec~quote(handle~pgid) || "0a"x
  if handle~systemdUnit \= "" then content ||= .QueueRecord~FIELD_SYSTEMD_UNIT || "=" || .QueueBashRecordCodec~quote(handle~systemdUnit) || "0a"x
  content ||= .QueueRecord~FIELD_RUN_STARTED_AT || "=" || .QueueBashRecordCodec~quote(handle~startedAt) || "0a"x
  content ||= .QueueRecord~FIELD_EXECUTION_ID || "=" || .QueueBashRecordCodec~quote(handle~executionId) || "0a"x
  content ||= .QueueRecord~FIELD_EXECUTION_PID_FILE || "=" || .QueueBashRecordCodec~quote(handle~pidPath) || "0a"x
  content ||= .QueueRecord~FIELD_EXECUTION_EXIT_FILE || "=" || .QueueBashRecordCodec~quote(handle~exitPath) || "0a"x
  temp = path || ".qrxexec.tmp." || random(0,999999)~right(6,"0")
  out = .Stream~new(temp)
  if out~open("WRITE REPLACE") \= "READY:" then return .false
  out~charOut(content)
  out~close
  fileSystem~ensureOwnerLike(temp, record~root)
  if \fileSystem~replace(temp, path) then do
    call SysFileDelete temp
    return .false
  end
  fileSystem~ensureOwnerLike(path, record~root)
  return .true

::class QueueExecutionService public
::attribute root get
::attribute providerRegistry get
::attribute store get
::attribute lockManager get
::attribute transitionService get
::attribute journal get
::attribute metadataWriter get
::attribute wluTerminalService get
::attribute wluRecovery get
::attribute platformFacts get
::method init
  expose root providerRegistry store lockManager transitionService journal metadataWriter wluTerminalService wluRecovery platformFacts
  use arg rootArg, providerRegistryArg = .nil, lockManagerArg = .nil, transitionArg = .nil, journalArg = .nil, metadataWriterArg = .nil, wluTerminalArg = .nil, wluRecoveryArg = .nil, platformFactsArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if providerRegistryArg == .nil then providerRegistry = .QueueProviderRegistry~builtins; else providerRegistry = providerRegistryArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root); else lockManager = lockManagerArg
  if transitionArg == .nil then transitionService = .QueueTransitionService~new(root, .nil, lockManager); else transitionService = transitionArg
  if journalArg == .nil then journal = .QueueExecutionJournal~new(root); else journal = journalArg
  if metadataWriterArg == .nil then metadataWriter = .QueueExecutionMetadataWriter~new; else metadataWriter = metadataWriterArg
  wluTerminalService = wluTerminalArg
  wluRecovery = wluRecoveryArg
  platformFacts = platformFactsArg
::method start
  expose root providerRegistry store lockManager journal metadataWriter platformFacts
  use strict arg qidArg
  qid = qidArg~string
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~EXECUTION_START, 3)
  if \lockResult~acquired then return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOCK_FAILED, qid, "", .QueueExecutionCode~LOCK_FAILED, lockResult~detail)
  lock = lockResult~handle
  signal on syntax name startFailure
  records = store~findAll(qid)
  if records~items == 0 then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~INVALID, qid, "", .QueueExecutionCode~RECORD_MISSING); end
  if records~items > 1 then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~AMBIGUOUS, qid, "", .QueueExecutionCode~RECORD_DUPLICATE); end
  record = records[1]
  if record~state \= .QueueState~RUNNING then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~INVALID, qid, "", .QueueExecutionCode~NOT_RUNNING, "execution start requires running state", "", record~state); end
  existing = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  if existing \= "" then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~ALREADY_STARTED, qid, existing, .QueueExecutionCode~ALREADY_STARTED, "execution metadata already recorded", record~field(.QueueRecord~FIELD_RUNNER_USED, ""), record~state); end
  requirement = .QueueJobRequirement~fromRecord(record)
  if platformFacts == .nil then facts = .QueuePlatformFacts~probeLocal; else facts = platformFacts
  decision = .QueueRunnerSelector~new(providerRegistry)~select(facts, requirement)
  if \decision~selected then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~PROVIDER_UNAVAILABLE, qid, "", .QueueExecutionCode~PROVIDER_NOT_SELECTED, decision~code || ":" || decision~warning); end
  provider = decision~provider
  executionId = journal~newExecutionId(qid)
  if \journal~fileSystem~ensureDirectory(journal~directory) then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~METADATA_FAILED, qid, executionId, .QueueExecutionCode~METADATA_FAILED, "execution journal directory unavailable", provider~id); end
  pidPath = .QueueExecutionPath~pidFile(root, executionId)
  exitPath = .QueueExecutionPath~exitFile(root, executionId)
  logPath = .QueueExecutionPath~logFile(root, qid)
  startedAt = .QueueKernelTime~nowIso
  unitName = ""
  if provider~id == .QueueRunnerKind~SYSTEMD then unitName = .QueueExecutionName~systemdUnit(qid, executionId)
  context = .QueueRunnerLaunchContext~new(record, root, executionId, logPath, pidPath, exitPath, unitName, startedAt)
  prepDoc = .Directory~new
  prepDoc["qid"] = qid
  prepDoc["provider"] = provider~id
  prepDoc["pid_file"] = pidPath
  prepDoc["exit_file"] = exitPath
  prepDoc["log_file"] = logPath
  prepDoc["systemd_unit"] = unitName
  if \journal~writePhase(executionId, .QueueExecutionPhase~PREPARED, prepDoc) then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~METADATA_FAILED, qid, executionId, .QueueExecutionCode~METADATA_FAILED, "unable to persist execution intent", provider~id); end
  prepared = provider~prepare(context)
  if \prepared~ok then do
    abortDoc = prepDoc~copy; abortDoc["code"] = prepared~code; abortDoc["detail"] = prepared~detail
    journal~writePhase(executionId, .QueueExecutionPhase~ABORTED, abortDoc)
    signal off syntax; lock~release
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~PREPARE_FAILED, qid, executionId, .QueueExecutionCode~PREPARE_FAILED, prepared~code || ":" || prepared~detail, provider~id, record~state)
  end
  launched = provider~launch(context)
  if \launched~ok | launched~data == .nil then do
    abortDoc = prepDoc~copy; abortDoc["code"] = launched~code; abortDoc["detail"] = launched~detail
    journal~writePhase(executionId, .QueueExecutionPhase~ABORTED, abortDoc)
    signal off syntax; lock~release
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~LAUNCH_FAILED, qid, executionId, .QueueExecutionCode~LAUNCH_FAILED, launched~code || ":" || launched~detail, provider~id, record~state)
  end
  handle = launched~data
  launchedDoc = prepDoc~copy; launchedDoc["handle"] = handle~asDirectory
  journal~writePhase(executionId, .QueueExecutionPhase~LAUNCHED, launchedDoc)
  if \metadataWriter~writeHandle(record, handle) then do
    ambiguous = launchedDoc~copy; ambiguous["detail"] = "payload launched but QueueBash record metadata could not be atomically replaced"
    journal~writePhase(executionId, .QueueExecutionPhase~AMBIGUOUS, ambiguous)
    signal off syntax; lock~release
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~METADATA_FAILED, qid, executionId, .QueueExecutionCode~METADATA_FAILED, ambiguous["detail"], provider~id, .QueueState~RUNNING, .nil, handle~asDirectory)
  end
  journal~writePhase(executionId, .QueueExecutionPhase~METADATA_RECORDED, launchedDoc)
  signal off syntax
  lock~release
  return .QueueExecutionReceipt~new(.QueueExecutionStatus~OK, qid, executionId, .QueueExecutionCode~STARTED, "", provider~id, .QueueState~RUNNING, .nil, handle~asDirectory)
startFailure:
  signal off syntax
  lock~release
  raise propagate

::method reconcile
  expose providerRegistry store lockManager transitionService journal metadataWriter wluTerminalService wluRecovery root
  use strict arg qidArg
  qid = qidArg~string
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~EXECUTION_RECONCILE, 3)
  if \lockResult~acquired then return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOCK_FAILED, qid, "", .QueueExecutionCode~LOCK_FAILED, lockResult~detail)
  lock = lockResult~handle
  signal on syntax name reconcileFailure
  records = store~findAll(qid)
  if records~items == 0 then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~INVALID, qid, "", .QueueExecutionCode~RECORD_MISSING); end
  if records~items > 1 then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~AMBIGUOUS, qid, "", .QueueExecutionCode~RECORD_DUPLICATE); end
  record = records[1]
  if record~state \= .QueueState~RUNNING then do
    terminalState = record~state
    managed = record~wluRequirement~managed
    signal off syntax; lock~release
    if managed & wluRecovery \= .nil then wluRecovery~recover
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINAL, qid, record~field(.QueueRecord~FIELD_EXECUTION_ID, ""), .QueueExecutionCode~EXITED, "queue record already terminal or non-running", record~field(.QueueRecord~FIELD_RUNNER_USED, ""), terminalState)
  end
  executionId = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  if executionId == "" then do
    recovered = self~recoverLaunchMetadataLocked(record, lock)
    if \recovered~ok then do; signal off syntax; lock~release; return recovered; end
    record = store~findOne(qid)
    executionId = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  end
  providerId = record~field(.QueueRecord~FIELD_RUNNER_USED, "")
  provider = providerRegistry~get(.QueueProviderCategory~RUNNER, providerId)
  if provider == .nil then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~PROVIDER_UNAVAILABLE, qid, executionId, .QueueExecutionCode~PROVIDER_NOT_SELECTED, "recorded runner provider is not registered", providerId, record~state); end
  exitPath = record~field(.QueueRecord~FIELD_EXECUTION_EXIT_FILE, "")
  exitCode = self~readExitCode(exitPath)
  if exitCode \= .nil then do
    isWlu = record~wluRequirement~managed
    if isWlu then do
      signal off syntax; lock~release
      if wluTerminalService == .nil then return .QueueExecutionReceipt~new(.QueueExecutionStatus~DEFERRED, qid, executionId, .QueueExecutionCode~WLU_TERMINAL_REQUIRED, "WLU-managed terminal state requires QueueWLUTerminalService", providerId, .QueueState~RUNNING, exitCode)
      if exitCode == 0 then terminal = wluTerminalService~complete(qid)
      else terminal = wluTerminalService~fail(qid)
      current = store~findOne(qid)
      if terminal~ok then do
        termDoc = .Directory~new; termDoc["qid"] = qid; termDoc["exit_code"] = exitCode; termDoc["state"] = .QueueState~name(current~state)
        journal~writePhase(executionId, .QueueExecutionPhase~TERMINAL_RECORDED, termDoc)
        return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINAL, qid, executionId, .QueueExecutionCode~EXITED, "", providerId, current~state, exitCode)
      end
      return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOST_RACE, qid, executionId, .QueueExecutionCode~WLU_TERMINAL_NOT_COMMITTED, terminal~detail, providerId, current~state, exitCode)
    end
    if exitCode == 0 then toState = .QueueState~DONE; else toState = .QueueState~FAILED
    if exitCode == 0 then eventType = .QueueEvent~JOB_COMPLETED; else eventType = .QueueEvent~JOB_FAILED
    transition = transitionService~transitionWithLock(lock, qid, .QueueState~RUNNING, toState, eventType, .QueueLockActor~EXECUTION_RECONCILE)
    signal off syntax; lock~release
    if \transition~ok then return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOST_RACE, qid, executionId, .QueueExecutionCode~TERMINAL_TRANSITION_FAILED, transition~detail, providerId, .QueueState~RUNNING, exitCode)
    termDoc = .Directory~new; termDoc["qid"] = qid; termDoc["exit_code"] = exitCode; termDoc["state"] = .QueueState~name(toState); termDoc["queue_transition_id"] = transition~transactionId
    journal~writePhase(executionId, .QueueExecutionPhase~TERMINAL_RECORDED, termDoc)
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINAL, qid, executionId, .QueueExecutionCode~EXITED, "", providerId, toState, exitCode, transition~asDirectory)
  end
  observation = provider~observe(record)
  signal off syntax
  lock~release
  if observation~status == .QueueJobObservation~LIVE then return .QueueExecutionReceipt~new(.QueueExecutionStatus~STILL_RUNNING, qid, executionId, .QueueExecutionCode~RUNNING, observation~detail, providerId, .QueueState~RUNNING, .nil, observation~asDirectory)
  if observation~isDeferred then return .QueueExecutionReceipt~new(.QueueExecutionStatus~DEFERRED, qid, executionId, .QueueExecutionCode~DEFERRED, observation~detail, providerId, .QueueState~RUNNING, .nil, observation~asDirectory)
  return .QueueExecutionReceipt~new(.QueueExecutionStatus~AMBIGUOUS, qid, executionId, .QueueExecutionCode~DEAD_WITHOUT_EXIT, "runner is not live but no durable exit-code locator exists; do not guess terminal result", providerId, .QueueState~RUNNING, .nil, observation~asDirectory)
reconcileFailure:
  signal off syntax
  lock~release
  raise propagate

::method cancel
  expose providerRegistry store lockManager transitionService wluTerminalService journal
  use strict arg qidArg
  qid = qidArg~string
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~EXECUTION_CANCEL, 3)
  if \lockResult~acquired then return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOCK_FAILED, qid, "", .QueueExecutionCode~LOCK_FAILED, lockResult~detail)
  lock = lockResult~handle
  signal on syntax name cancelFailure
  records = store~findAll(qid)
  if records~items \= 1 then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~AMBIGUOUS, qid, "", .QueueExecutionCode~RECORD_DUPLICATE, "cancel requires exactly one authoritative record"); end
  record = records[1]
  fromState = record~state
  if fromState \= .QueueState~PENDING & fromState \= .QueueState~WAITING & fromState \= .QueueState~RUNNING & fromState \= .QueueState~PAUSED then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~INVALID, qid, record~field(.QueueRecord~FIELD_EXECUTION_ID,""), .QueueExecutionCode~NOT_RUNNING, "state is not cancellable", record~field(.QueueRecord~FIELD_RUNNER_USED,""), fromState); end
  providerId = record~field(.QueueRecord~FIELD_RUNNER_USED, "")
  if fromState == .QueueState~RUNNING & providerId \= "" then do
    provider = providerRegistry~get(.QueueProviderCategory~RUNNER, providerId)
    if provider == .nil then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~PROVIDER_UNAVAILABLE, qid, record~field(.QueueRecord~FIELD_EXECUTION_ID,""), .QueueExecutionCode~PROVIDER_NOT_SELECTED, "runner provider unavailable", providerId, fromState); end
    terminated = provider~terminate(record)
    if \terminated~ok then do; signal off syntax; lock~release; return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINATE_FAILED, qid, record~field(.QueueRecord~FIELD_EXECUTION_ID,""), .QueueExecutionCode~TERMINATE_FAILED, terminated~detail, providerId, fromState); end
    terminationObservation = provider~observe(record)
    if terminationObservation~status \= .QueueJobObservation~DEAD then do
      signal off syntax; lock~release
      return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINATE_FAILED, qid, record~field(.QueueRecord~FIELD_EXECUTION_ID,""), .QueueExecutionCode~TERMINATE_UNCONFIRMED, "runner did not provide conclusive DEAD evidence after terminate", providerId, fromState, .nil, terminationObservation~asDirectory)
    end
  end
  managed = record~wluRequirement~managed
  executionId = record~field(.QueueRecord~FIELD_EXECUTION_ID, "")
  if managed then do
    signal off syntax; lock~release
    if wluTerminalService == .nil then return .QueueExecutionReceipt~new(.QueueExecutionStatus~DEFERRED, qid, executionId, .QueueExecutionCode~WLU_TERMINAL_REQUIRED, "WLU-managed cancel requires QueueWLUTerminalService", providerId, fromState)
    terminal = wluTerminalService~cancel(qid)
    current = store~findOne(qid)
    if terminal~ok then do
      if executionId \= "" then do
        termDoc = .Directory~new; termDoc["qid"] = qid; termDoc["state"] = .QueueState~name(current~state); termDoc["cancelled"] = .JSONBoolean~true
        journal~writePhase(executionId, .QueueExecutionPhase~TERMINAL_RECORDED, termDoc)
      end
      return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINAL, qid, executionId, .QueueExecutionCode~CANCELLED, "", providerId, current~state)
    end
    return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOST_RACE, qid, executionId, .QueueExecutionCode~WLU_CANCEL_NOT_COMMITTED, terminal~detail, providerId, current~state)
  end
  transition = transitionService~transitionWithLock(lock, qid, fromState, .QueueState~CANCELLED, .QueueEvent~JOB_CANCELLED, .QueueLockActor~EXECUTION_CANCEL)
  signal off syntax; lock~release
  if \transition~ok then return .QueueExecutionReceipt~new(.QueueExecutionStatus~LOST_RACE, qid, executionId, .QueueExecutionCode~CANCEL_TRANSITION_FAILED, transition~detail, providerId, fromState)
  if executionId \= "" then do
    termDoc = .Directory~new; termDoc["qid"] = qid; termDoc["state"] = .QueueState~name(.QueueState~CANCELLED); termDoc["cancelled"] = .JSONBoolean~true; termDoc["queue_transition_id"] = transition~transactionId
    journal~writePhase(executionId, .QueueExecutionPhase~TERMINAL_RECORDED, termDoc)
  end
  return .QueueExecutionReceipt~new(.QueueExecutionStatus~TERMINAL, qid, executionId, .QueueExecutionCode~CANCELLED, "", providerId, .QueueState~CANCELLED, .nil, transition~asDirectory)
cancelFailure:
  signal off syntax
  lock~release
  raise propagate

::method recoverLaunchMetadataLocked private
  expose providerRegistry journal metadataWriter root
  use strict arg record, lock
  qid = record~qid
  prepared = journal~preparedForQid(qid)
  active = .Array~new
  do doc over prepared
    executionId = doc["execution_id"]~string
    if journal~phaseExists(executionId, .QueueExecutionPhase~ABORTED) | journal~phaseExists(executionId, .QueueExecutionPhase~TERMINAL_RECORDED) then iterate
    active~append(doc)
  end
  if active~items == 0 then return .QueueExecutionReceipt~new(.QueueExecutionStatus~NO_EXECUTION, qid, "", .QueueExecutionCode~RECORD_MISSING, "running record has no QueueRexx execution journal")
  if active~items > 1 then return .QueueExecutionReceipt~new(.QueueExecutionStatus~AMBIGUOUS, qid, "", .QueueExecutionCode~RECORD_DUPLICATE, "multiple active execution intents")
  doc = active[1]; e = doc["execution"]; executionId = doc["execution_id"]~string
  providerId = e["provider"]~string
  pidPath = e["pid_file"]~string; exitPath = e["exit_file"]~string
  unit = e["systemd_unit"]~string; pid = self~readPid(pidPath); pgid = ""
  if pid \= "" then pgid = self~pgidFor(pid)
  if providerId == .QueueRunnerKind~DIRECT & pid == "" then return .QueueExecutionReceipt~new(.QueueExecutionStatus~DEFERRED, qid, executionId, .QueueExecutionCode~DEFERRED, "launch intent exists but provider PID locator is not yet durable", providerId, .QueueState~RUNNING)
  handle = .QueueRunnerLaunchHandle~new(providerId, executionId, pid, pgid, unit, doc["recorded_at"]~string, pidPath, exitPath)
  if \metadataWriter~writeHandle(record, handle) then return .QueueExecutionReceipt~new(.QueueExecutionStatus~METADATA_FAILED, qid, executionId, .QueueExecutionCode~METADATA_FAILED, "unable to recover launch metadata", providerId, .QueueState~RUNNING)
  recoveredDoc = e~copy; recoveredDoc["handle"] = handle~asDirectory; recoveredDoc["recovered"] = .JSONBoolean~true
  journal~writePhase(executionId, .QueueExecutionPhase~METADATA_RECORDED, recoveredDoc)
  return .QueueExecutionReceipt~new(.QueueExecutionStatus~OK, qid, executionId, .QueueExecutionCode~RECOVERED_LAUNCH, "", providerId, .QueueState~RUNNING, .nil, handle~asDirectory)
::method readPid private
  use strict arg path
  if path == "" | \SysFileExists(path) then return ""
  s = .Stream~new(path); if s~open("READ") \= "READY:" then return ""
  line = s~lineIn~strip; s~close
  if line~datatype("W") & line + 0 > 0 then return line
  return ""
::method pgidFor private
  use strict arg pid
  value = .QueueRexxUtil~shellOutput("ps -o pgid= -p " || pid || " 2>/dev/null")
  return value~strip
::method readExitCode private
  use strict arg path
  if path == "" | \SysFileExists(path) then return .nil
  s = .Stream~new(path); if s~open("READ") \= "READY:" then return .nil
  line = s~lineIn~strip; s~close
  if \line~datatype("W") then return .nil
  return line + 0

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxSerialization.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxMutation.cls"
::requires "QueueRexxOperations.cls"

/* QueueRexxOperations.cls - typed operation / worker-admission pilot, v0.1-dev8.
 *
 * This layer deliberately sits above QueueRexxMutation.  It does not invent a
 * second state mechanism.  Every state change goes through QueueTransitionService.
 * No caller gets an implicit allow policy: submission/execution gates fail closed
 * unless an explicit policy implementation is supplied.
 */

::class QueueOperationKind public
::constant SUBMIT 1
::constant CLAIM 2
::constant COMPLETE 3
::constant FAIL 4
::constant CANCEL 5
::constant NAME_SUBMIT "submit"
::constant NAME_CLAIM "claim"
::constant NAME_COMPLETE "complete"
::constant NAME_FAIL "fail"
::constant NAME_CANCEL "cancel"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg value
  select
    when value == self~SUBMIT then return self~NAME_SUBMIT
    when value == self~CLAIM then return self~NAME_CLAIM
    when value == self~COMPLETE then return self~NAME_COMPLETE
    when value == self~FAIL then return self~NAME_FAIL
    when value == self~CANCEL then return self~NAME_CANCEL
    otherwise return self~NAME_UNKNOWN
  end

::class QueueOperationStatus public
::constant OK 1
::constant DENIED 2
::constant INVALID 3
::constant IO_ERROR 4
::constant NO_WORK 5
::constant LOST_RACE 6
::constant UNSUPPORTED 7
::constant NAME_OK "ok"
::constant NAME_DENIED "denied"
::constant NAME_INVALID "invalid"
::constant NAME_IO_ERROR "io_error"
::constant NAME_NO_WORK "no_work"
::constant NAME_LOST_RACE "lost_race"
::constant NAME_UNSUPPORTED "unsupported"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg value
  select
    when value == self~OK then return self~NAME_OK
    when value == self~DENIED then return self~NAME_DENIED
    when value == self~INVALID then return self~NAME_INVALID
    when value == self~IO_ERROR then return self~NAME_IO_ERROR
    when value == self~NO_WORK then return self~NAME_NO_WORK
    when value == self~LOST_RACE then return self~NAME_LOST_RACE
    when value == self~UNSUPPORTED then return self~NAME_UNSUPPORTED
    otherwise return self~NAME_UNKNOWN
  end

::class QueuePolicyCode public
::constant ALLOWED "ALLOWED"
::constant DENIED "DENIED"
::constant NO_SUBMIT_PROVIDER "NO_SUBMIT_POLICY_PROVIDER"
::constant NO_EXECUTION_PROVIDER "NO_EXECUTION_POLICY_PROVIDER"

::class QueueOperationCode public
::constant INVALID_REQUEST "INVALID_REQUEST"
::constant POLICY_DENIED "POLICY_DENIED"
::constant QID_ALLOCATION_FAILED "QID_ALLOCATION_FAILED"
::constant JOB_WRITE_FAILED "JOB_WRITE_FAILED"
::constant SUBMITTED "SUBMITTED"
::constant WLU_STAGED "WLU_STAGED_WAITING"
::constant NO_PENDING_JOB "NO_PENDING_JOB"
::constant CLAIM_LOST "CLAIM_LOST"
::constant CLAIM_RECORD_MISSING "CLAIM_RECORD_MISSING"
::constant POLICY_BLOCK_TRANSITION_FAILED "POLICY_BLOCK_TRANSITION_FAILED"
::constant CLAIMED "CLAIMED"
::constant POLICY_BLOCKED "POLICY_BLOCKED"

::class QueuePolicyVerdict public
::constant ALLOWED 1
::constant DENIED 2
::attribute verdict get
::attribute code get
::attribute detail get
::method init
  expose verdict code detail
  use strict arg verdictArg, codeArg = "", detailArg = ""
  verdict = verdictArg + 0
  code = codeArg~string
  detail = detailArg~string
::method isAllowed
  expose verdict
  return verdict == self~ALLOWED
::method allow class
  use arg codeArg = (.QueuePolicyCode~ALLOWED), detailArg = ""
  return self~new(self~ALLOWED, codeArg, detailArg)
::method deny class
  use arg codeArg = (.QueuePolicyCode~DENIED), detailArg = ""
  return self~new(self~DENIED, codeArg, detailArg)

::class QueueOperationPolicyGate public
::method assessSubmit abstract
::method assessExecution abstract

::class QueueDenyAllOperationPolicyGate public subclass QueueOperationPolicyGate
::method assessSubmit
  return .QueuePolicyVerdict~deny(.QueuePolicyCode~NO_SUBMIT_PROVIDER, "QueueRexx submit requires an explicit policy provider")
::method assessExecution
  return .QueuePolicyVerdict~deny(.QueuePolicyCode~NO_EXECUTION_PROVIDER, "QueueRexx worker admission requires an explicit policy provider")

::class QueueBashRecordCodec public
::constant DEFAULT_RETRIES_MAX 0
::constant DEFAULT_RETRIES_DONE 0
::constant DEFAULT_RETRY_BACKOFF 0
::constant DEFAULT_NOT_BEFORE_EPOCH 0
::constant DEFAULT_MAX_LOG_SIZE_BYTES 52428800
::constant DEFAULT_ALLOW_LARGE_LOG 0
::constant DEFAULT_LOG_OVERFLOW_POLICY "stderr-only"
::constant DEFAULT_SANDBOX_LEVEL "off"

::method quote class
  use strict arg valueArg
  value = valueArg~string
  if value~pos('00'x) > 0 | value~pos('0A'x) > 0 | value~pos('0D'x) > 0 then raise syntax 88.900 array("QueueBash record value contains NUL/CR/LF")
  dq = '22'x; bs = '5C'x; bt = '60'x
  out = dq
  do i = 1 to value~length
    c = value~substr(i, 1)
    if c == dq | c == bs | c == "$" | c == bt then out ||= bs
    out ||= c
  end
  return out || dq

::method array class
  use strict arg values
  out = "("
  do item over values
    out ||= " " || self~quote(item)
  end
  return out || " )"

::class QueueWLUQueueBashFence public
::constant FILE_HEADER "# QueueRexx WLU execution fence - QueueBash must not promote WLU-managed jobs."
::constant PREFLIGHT_LINE "CLASS_PREFLIGHT_CMD=false"
::method classPath class
  use strict arg root
  return root || "/classes/" || .QueueWLUContract~HOLD_CLASS || ".env"
::method ensure class
  use strict arg root, fileSystem = .nil
  if fileSystem == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  classes = root || "/classes"
  if \fileSystem~ensureDirectory(classes) then return .false
  path = self~classPath(root)
  expected = self~FILE_HEADER || "0a"x || "CLASS_ALLOW_PARALLEL=1" || "0a"x || "CLASS_MAX_CONCURRENT=0" || "0a"x || self~PREFLIGHT_LINE || "0a"x
  if SysFileExists(path) then return self~readAll(path) == expected
  s = .Stream~new(path)
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  s~charOut(expected)
  s~close
  fileSystem~ensureOwnerLike(classes, root)
  fileSystem~ensureOwnerLike(path, root)
  return self~readAll(path) == expected
::method readAll class private
  use strict arg path
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return ""
  data = s~charIn(, s~chars)
  s~close
  return data

::class QueueSubmitRequest public
::attribute name get
::attribute command get
::attribute priority get
::attribute jobClass get
::attribute runner get
::attribute pwd get
::attribute wluRequirement get
::method init
  expose name command priority jobClass runner pwd wluRequirement
  use arg nameArg, commandArg, priorityArg = 10, classArg = (.QueueJobClass~DEFAULT), runnerArg = (.QueueRunnerKind~AUTO), pwdArg = "", wluArg = .nil
  name = nameArg~string
  command = commandArg
  priority = priorityArg + 0
  jobClass = classArg~string
  runner = runnerArg~string~lower
  if pwdArg == "" then pwd = directory(); else pwd = pwdArg~string
  if wluArg == .nil then wluRequirement = .QueueWLURequirement~unmanaged
  else wluRequirement = wluArg
::method valid
  expose name command jobClass runner wluRequirement
  if name == "" | jobClass == "" then return .false
  if command == .nil | \command~isA(.Array) | command~items == 0 then return .false
  if runner \= .QueueRunnerKind~AUTO & runner \= .QueueRunnerKind~DIRECT & runner \= .QueueRunnerKind~SYSTEMD then return .false
  if wluRequirement == .nil | \wluRequirement~isA(.QueueWLURequirement) | \wluRequirement~valid then return .false
  return .true

::class QueueOperationReceipt public
::attribute status get
::attribute kind get
::attribute qid get
::attribute state get
::attribute path get
::attribute code get
::attribute detail get
::attribute transition get
::method init
  expose status kind qid state path code detail transition
  use strict arg statusArg, kindArg, qidArg = "", stateArg = (.QueueState~UNKNOWN), pathArg = "", codeArg = "", detailArg = "", transitionArg = .nil
  status = statusArg + 0; kind = kindArg + 0; qid = qidArg~string; state = .QueueState~coerce(stateArg); path = pathArg~string; code = codeArg~string; detail = detailArg~string; transition = transitionArg
::method ok
  expose status
  return status == .QueueOperationStatus~OK
::method asDirectory
  expose status kind qid state path code detail transition
  d = .Directory~new
  d["schema"] = .QueueSchema~OPERATION
  d["ok"] = .QueueRexxUtil~jsonBoolean(status == .QueueOperationStatus~OK)
  d["status"] = .QueueOperationStatus~name(status)
  d["operation"] = .QueueOperationKind~name(kind)
  d["qid"] = qid
  d["state"] = .QueueState~name(state)
  d["job_file"] = path
  d["code"] = code
  d["detail"] = detail
  if transition \= .nil then d["transition"] = transition~asDirectory
  return d

::class QueueBashJobWriter public
::method writeSubmitted
  use strict arg path, request, qid
  s = .Stream~new(path)
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  ignore = self~scalar(s, .QueueRecord~FIELD_JOB_ID, qid)
  ignore = self~scalar(s, .QueueRecord~FIELD_JOB_NAME, request~name)
  ignore = self~scalar(s, .QueueRecord~FIELD_PRIORITY, request~priority)
  ignore = self~scalar(s, .QueueRecord~FIELD_RETRIES_MAX, .QueueBashRecordCodec~DEFAULT_RETRIES_MAX)
  ignore = self~scalar(s, .QueueRecord~FIELD_RETRIES_DONE, .QueueBashRecordCodec~DEFAULT_RETRIES_DONE)
  ignore = self~scalar(s, .QueueRecord~FIELD_RETRY_BACKOFF, .QueueBashRecordCodec~DEFAULT_RETRY_BACKOFF)
  ignore = self~scalar(s, .QueueRecord~FIELD_RETRY_NOT_BEFORE_EPOCH, .QueueBashRecordCodec~DEFAULT_NOT_BEFORE_EPOCH)
  ignore = self~scalar(s, .QueueRecord~FIELD_NOT_BEFORE_EPOCH, .QueueBashRecordCodec~DEFAULT_NOT_BEFORE_EPOCH)
  ignore = self~scalar(s, .QueueRecord~FIELD_CPU_LIMIT, "")
  ignore = self~scalar(s, .QueueRecord~FIELD_MEM_LIMIT, "")
  ignore = self~scalar(s, .QueueRecord~FIELD_MAX_LOG_SIZE_BYTES, .QueueBashRecordCodec~DEFAULT_MAX_LOG_SIZE_BYTES)
  ignore = self~scalar(s, .QueueRecord~FIELD_ALLOW_LARGE_LOG, .QueueBashRecordCodec~DEFAULT_ALLOW_LARGE_LOG)
  ignore = self~scalar(s, .QueueRecord~FIELD_LOG_OVERFLOW_POLICY, .QueueBashRecordCodec~DEFAULT_LOG_OVERFLOW_POLICY)
  ignore = self~scalar(s, .QueueRecord~FIELD_RUNNER, request~runner)
  ignore = self~scalar(s, .QueueRecord~FIELD_SANDBOX_LEVEL, .QueueBashRecordCodec~DEFAULT_SANDBOX_LEVEL)
  ignore = self~scalar(s, .QueueRecord~FIELD_SECURITY_SANDBOX_EXPLICIT, 0)
  ignore = self~scalar(s, .QueueRecord~FIELD_SECURITY_SECCOMP_EXPLICIT, 0)
  wlu = request~wluRequirement
  if wlu~managed then do
    ignore = self~scalar(s, .QueueRecord~FIELD_JOB_CLASS, .QueueWLUContract~HOLD_CLASS)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_ORIGINAL_JOB_CLASS, request~jobClass)
  end
  else ignore = self~scalar(s, .QueueRecord~FIELD_JOB_CLASS, request~jobClass)
  ignore = self~scalar(s, .QueueRecord~FIELD_SUBMITTED_AT, .QueueKernelTime~nowIso)
  ignore = self~scalar(s, .QueueRecord~FIELD_PWD_AT_SUBMIT, request~pwd)
  ignore = self~scalar(s, .QueueRecord~FIELD_WLU_MODE, .QueueWLUMode~name(wlu~mode))
  if wlu~managed then do
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_API_VERSION, .QueueWLUContract~API_VERSION)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_IDENTITY, wlu~identity)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_SCOPE, wlu~scope)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_EXPECTED_MICRO_WLU, wlu~expectedMicroWlu)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_CEILING_MICRO_WLU, wlu~ceilingMicroWlu)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_TARGET_SECONDS, wlu~targetSeconds)
    ignore = self~scalar(s, .QueueRecord~FIELD_WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND, wlu~requestedRateMicroWluPerSecond)
  end
  s~lineOut(.QueueRecord~FIELD_COMMAND || "=" || .QueueBashRecordCodec~array(request~command))
  s~lineOut(.QueueRecord~FIELD_ON_SUCCESS || "=()")
  s~lineOut(.QueueRecord~FIELD_ON_FAILURE || "=()")
  s~lineOut(.QueueRecord~FIELD_ON_RETRY_FAILURE || "=()")
  s~close
  return .true

::method scalar private
  use strict arg stream, key, value
  stream~lineOut(key || "=" || .QueueBashRecordCodec~quote(value))
  return .true

::class QueueBashEventName public
::constant SUBMITTED "submitted"
::constant POL_BLOCKED "pol_blocked"

::class QueueSubmitService public
::attribute root get
::attribute policyGate get
::attribute allocator get
::attribute waitingAllocator get
::method init
  expose root policyGate allocator waitingAllocator writer eventBus
  use arg rootArg, policyGateArg = .nil, allocatorArg = .nil, writerArg = .nil, eventBusArg = .nil, waitingAllocatorArg = .nil
  root = rootArg~string
  if policyGateArg == .nil then policyGate = .QueueDenyAllOperationPolicyGate~new; else policyGate = policyGateArg
  if allocatorArg == .nil then allocator = .QueuePendingAllocator~new(root); else allocator = allocatorArg
  if waitingAllocatorArg == .nil then waitingAllocator = .QueueWaitingAllocator~new(root); else waitingAllocator = waitingAllocatorArg
  if writerArg == .nil then writer = .QueueBashJobWriter~new; else writer = writerArg
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(root))
  end
  else eventBus = eventBusArg

::method submit
  expose root policyGate allocator waitingAllocator writer eventBus
  use strict arg request
  if request == .nil | \request~isA(.QueueSubmitRequest) | \request~valid then return .QueueOperationReceipt~new(.QueueOperationStatus~INVALID, .QueueOperationKind~SUBMIT, "", .QueueState~UNKNOWN, "", .QueueOperationCode~INVALID_REQUEST)
  verdict = policyGate~assessSubmit(request)
  if verdict == .nil | \verdict~isAllowed then do
    code = .QueueOperationCode~POLICY_DENIED; detail = ""
    if verdict \= .nil then do; code = verdict~code; detail = verdict~detail; end
    return .QueueOperationReceipt~new(.QueueOperationStatus~DENIED, .QueueOperationKind~SUBMIT, "", .QueueState~UNKNOWN, "", code, detail)
  end

  wlu = request~wluRequirement
  if wlu~managed then do
    if .QueueWLUQueueBashFence~ensure(root) == .false then return .QueueOperationReceipt~new(.QueueOperationStatus~IO_ERROR, .QueueOperationKind~SUBMIT, "", .QueueState~WAITING, "", .QueueOperationCode~JOB_WRITE_FAILED, "unable to establish QueueBash-visible WLU execution fence")
    reservation = waitingAllocator~reserve(request~priority)
    initialState = .QueueState~WAITING
    opCode = .QueueOperationCode~WLU_STAGED
  end
  else do
    reservation = allocator~reserve(request~priority)
    initialState = .QueueState~PENDING
    opCode = .QueueOperationCode~SUBMITTED
  end
  if reservation == .nil then return .QueueOperationReceipt~new(.QueueOperationStatus~IO_ERROR, .QueueOperationKind~SUBMIT, "", initialState, "", .QueueOperationCode~QID_ALLOCATION_FAILED)
  signal on syntax name submitWriteFailure
  wrote = writer~writeSubmitted(reservation~path, request, reservation~qid)
  signal off syntax
  if \wrote then do
    reservation~release
    return .QueueOperationReceipt~new(.QueueOperationStatus~IO_ERROR, .QueueOperationKind~SUBMIT, reservation~qid, initialState, reservation~path, .QueueOperationCode~JOB_WRITE_FAILED)
  end
  reservation~markCommitted
  reservation~release
  data = .Directory~new
  data["detail"] = "priority=" || request~priority || " wlu=" || .QueueWLUMode~name(wlu~mode)
  event = .QueueEvent~new("submit-" || reservation~qid, .QueueBashEventName~SUBMITTED, reservation~qid, .QueueState~name(initialState), .QueueKernelTime~nowIso, data)
  eventBus~publishChecked(event)
  return .QueueOperationReceipt~new(.QueueOperationStatus~OK, .QueueOperationKind~SUBMIT, reservation~qid, initialState, reservation~path, opCode)
submitWriteFailure:
  signal off syntax
  reservation~release
  raise propagate

::class QueueWorkerAdmission public
::attribute root get
::method init
  expose root policyGate transitionService store providerRegistry platformFacts
  use arg rootArg, policyGateArg = .nil, transitionArg = .nil, providerRegistryArg = .nil, platformFactsArg = .nil
  root = rootArg~string
  if policyGateArg == .nil then policyGate = .QueueDenyAllOperationPolicyGate~new; else policyGate = policyGateArg
  if transitionArg == .nil then transitionService = .QueueTransitionService~new(root); else transitionService = transitionArg
  store = .QueueStateStore~new(root)
  if providerRegistryArg == .nil then providerRegistry = .QueueProviderRegistry~builtins; else providerRegistry = providerRegistryArg
  platformFacts = platformFactsArg

::method nextPending
  expose store
  records = store~records(.QueueState~PENDING)
  best = .nil
  do r over records
    if best == .nil then best = r
    else if r~path < best~path then best = r
  end
  return best

::method claimNext
  candidate = self~nextPending
  if candidate == .nil then return .QueueOperationReceipt~new(.QueueOperationStatus~NO_WORK, .QueueOperationKind~CLAIM, "", .QueueState~PENDING, "", .QueueOperationCode~NO_PENDING_JOB)
  return self~claim(candidate~qid)

::method claim
  expose root policyGate transitionService store providerRegistry platformFacts
  use strict arg qidArg
  qid = qidArg~string
  pending = .nil
  do candidate over store~findAll(qid)
    if candidate~state == .QueueState~PENDING then do; pending = candidate; leave; end
  end
  if pending == .nil then return .QueueOperationReceipt~new(.QueueOperationStatus~NO_WORK, .QueueOperationKind~CLAIM, qid, .QueueState~PENDING, "", .QueueOperationCode~NO_PENDING_JOB)
  receipt = transitionService~transition(qid, .QueueState~PENDING, .QueueState~RUNNING, .QueueEvent~JOB_CLAIMED, "queuerexx-worker-claim")
  if \receipt~ok then return .QueueOperationReceipt~new(.QueueOperationStatus~LOST_RACE, .QueueOperationKind~CLAIM, qid, .QueueState~PENDING, pending~path, .QueueOperationCode~CLAIM_LOST, receipt~detail, receipt)
  running = store~findOne(qid)
  if running == .nil | running~state \= .QueueState~RUNNING then return .QueueOperationReceipt~new(.QueueOperationStatus~IO_ERROR, .QueueOperationKind~CLAIM, qid, .QueueState~UNKNOWN, "", .QueueOperationCode~CLAIM_RECORD_MISSING, "", receipt)
  verdict = policyGate~assessExecution(running)
  if verdict == .nil | \verdict~isAllowed then do
    blocked = transitionService~transition(running~qid, .QueueState~RUNNING, .QueueState~POL_BLOCKED, .QueueBashEventName~POL_BLOCKED, "queuerexx-worker-policy")
    detail = ""
    if verdict \= .nil then detail = verdict~code || ":" || verdict~detail
    if \blocked~ok then return .QueueOperationReceipt~new(.QueueOperationStatus~IO_ERROR, .QueueOperationKind~CLAIM, running~qid, .QueueState~RUNNING, running~path, .QueueOperationCode~POLICY_BLOCK_TRANSITION_FAILED, detail, blocked)
    blockedRecord = store~findOne(running~qid)
    blockedPath = ""; if blockedRecord \= .nil then blockedPath = blockedRecord~path
    return .QueueOperationReceipt~new(.QueueOperationStatus~DENIED, .QueueOperationKind~CLAIM, running~qid, .QueueState~POL_BLOCKED, blockedPath, .QueueOperationCode~POLICY_BLOCKED, detail, blocked)
  end
  requirement = .QueueJobRequirement~fromRecord(running)
  if platformFacts == .nil then facts = .QueuePlatformFacts~probeLocal; else facts = platformFacts
  decision = .QueueRunnerSelector~new(providerRegistry)~select(facts, requirement)
  if \decision~selected then return .QueueOperationReceipt~new(.QueueOperationStatus~UNSUPPORTED, .QueueOperationKind~CLAIM, running~qid, .QueueState~RUNNING, running~path, decision~code, decision~warning, receipt)
  return .QueueOperationReceipt~new(.QueueOperationStatus~OK, .QueueOperationKind~CLAIM, running~qid, .QueueState~RUNNING, running~path, .QueueOperationCode~CLAIMED || ":" || decision~provider~id, decision~warning, receipt)

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxMutation.cls"

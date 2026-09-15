/* QueueRexxWLUBridge.cls - safe adoption of QueueBash-created jobs into WLU management, v0.1-dev10.
 *
 * The bridge does not make QueueBash WLU-aware.  It takes the shared QID lock,
 * writes a QueueBash-visible hold class plus additive WLU declaration fields,
 * then moves the job from pending to waiting under that same lock.  A crash
 * after metadata but before the move leaves a held, non-executable pending job
 * that a later bridge pass can finish safely.
 */

::class QueueWLUBridgeStatus public
::constant STAGED 1
::constant ALREADY_MANAGED 2
::constant INVALID_REQUIREMENT 3
::constant RECORD_NOT_FOUND 4
::constant DUPLICATE_STATE 5
::constant NOT_PENDING 6
::constant LOCK_FAILED 7
::constant FENCE_FAILED 8
::constant WRITE_FAILED 9
::constant TRANSITION_FAILED 10
::constant NAME_STAGED "staged"
::constant NAME_ALREADY_MANAGED "already_managed"
::constant NAME_INVALID_REQUIREMENT "invalid_requirement"
::constant NAME_RECORD_NOT_FOUND "record_not_found"
::constant NAME_DUPLICATE_STATE "duplicate_state"
::constant NAME_NOT_PENDING "not_pending"
::constant NAME_LOCK_FAILED "lock_failed"
::constant NAME_FENCE_FAILED "fence_failed"
::constant NAME_WRITE_FAILED "write_failed"
::constant NAME_TRANSITION_FAILED "transition_failed"
::method name class
  use strict arg value
  select
    when value == self~STAGED then return self~NAME_STAGED
    when value == self~ALREADY_MANAGED then return self~NAME_ALREADY_MANAGED
    when value == self~INVALID_REQUIREMENT then return self~NAME_INVALID_REQUIREMENT
    when value == self~RECORD_NOT_FOUND then return self~NAME_RECORD_NOT_FOUND
    when value == self~DUPLICATE_STATE then return self~NAME_DUPLICATE_STATE
    when value == self~NOT_PENDING then return self~NAME_NOT_PENDING
    when value == self~LOCK_FAILED then return self~NAME_LOCK_FAILED
    when value == self~FENCE_FAILED then return self~NAME_FENCE_FAILED
    when value == self~WRITE_FAILED then return self~NAME_WRITE_FAILED
    when value == self~TRANSITION_FAILED then return self~NAME_TRANSITION_FAILED
    otherwise return "unknown"
  end

::class QueueWLUBridgeReceipt public
::attribute status get
::attribute qid get
::attribute detail get
::attribute transition get
::method init
  expose status qid detail transition
  use strict arg statusArg, qidArg, detailArg = "", transitionArg = .nil
  status = statusArg + 0; qid = qidArg~string; detail = detailArg~string; transition = transitionArg
::method ok
  expose status
  return status == .QueueWLUBridgeStatus~STAGED | status == .QueueWLUBridgeStatus~ALREADY_MANAGED
::method asDirectory
  expose status qid detail transition
  d = .Directory~new
  d["schema"] = .QueueSchema~WLU_BRIDGE
  d["status"] = .QueueWLUBridgeStatus~name(status)
  d["status_code"] = status
  d["qid"] = qid
  d["detail"] = detail
  if transition == .nil then d["transition"] = .nil; else d["transition"] = transition~asDirectory
  return d

::class QueueWLURequirementProvider public
::method requirementFor abstract

::class QueueStaticWLURequirementProvider public subclass QueueWLURequirementProvider
::attribute requirement get
::method init
  expose requirement
  use strict arg requirementArg
  requirement = requirementArg
::method requirementFor
  expose requirement
  use strict arg record
  return requirement

::class QueueWLUBridgeMetadataWriter public
::attribute fileSystem get
::method init
  expose fileSystem
  use arg fileSystemArg = .nil
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new; else fileSystem = fileSystemArg
::method stage
  expose fileSystem
  use strict arg record, requirement
  path = record~path
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return .false
  content = s~charIn(, s~chars)
  s~close
  if content \= "" & content~right(1) \= "0a"x then content ||= "0a"x
  originalClass = record~effectiveJobClass
  content ||= self~scalar(.QueueRecord~FIELD_JOB_CLASS, .QueueWLUContract~HOLD_CLASS)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_ORIGINAL_JOB_CLASS, originalClass)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_MODE, .QueueWLUMode~NAME_MANAGED)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_API_VERSION, .QueueWLUContract~API_VERSION)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_IDENTITY, requirement~identity)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_SCOPE, requirement~scope)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_EXPECTED_MICRO_WLU, requirement~expectedMicroWlu)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_CEILING_MICRO_WLU, requirement~ceilingMicroWlu)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_TARGET_SECONDS, requirement~targetSeconds)
  content ||= self~scalar(.QueueRecord~FIELD_WLU_REQUESTED_RATE_MICRO_WLU_PER_SECOND, requirement~requestedRateMicroWluPerSecond)
  temp = path || ".qrxwlu.tmp." || random(0,999999)~right(6,"0")
  out = .Stream~new(temp)
  if out~open("WRITE REPLACE") \= "READY:" then return .false
  out~charOut(content); out~close
  fileSystem~ensureOwnerLike(temp, record~root)
  if \fileSystem~replace(temp, path) then do; call SysFileDelete temp; return .false; end
  fileSystem~ensureOwnerLike(path, record~root)
  return .true
::method scalar private
  use strict arg key, value
  return key || "=" || .QueueBashRecordCodec~quote(value) || "0a"x

::class QueueBashWLUBridge public
::attribute root get
::attribute requirementProvider get
::method init
  expose root requirementProvider store lockManager transitionService metadataWriter fileSystem
  use arg rootArg, requirementProviderArg, lockManagerArg = .nil, transitionArg = .nil, writerArg = .nil, fileSystemArg = .nil
  root = rootArg~string
  requirementProvider = requirementProviderArg
  store = .QueueStateStore~new(root)
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new; else fileSystem = fileSystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, fileSystem); else lockManager = lockManagerArg
  if transitionArg == .nil then transitionService = .QueueTransitionService~new(root, fileSystem, lockManager); else transitionService = transitionArg
  if writerArg == .nil then metadataWriter = .QueueWLUBridgeMetadataWriter~new(fileSystem); else metadataWriter = writerArg
::method stage
  expose root requirementProvider store lockManager transitionService metadataWriter fileSystem
  use strict arg qidArg
  qid = qidArg~string
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~WLU_BRIDGE, 3)
  if \lockResult~acquired then return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~LOCK_FAILED, qid, lockResult~detail)
  lock = lockResult~handle
  signal on syntax name stageFailure
  matches = store~findAll(qid)
  if matches~items == 0 then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~RECORD_NOT_FOUND, qid); end
  if matches~items > 1 then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~DUPLICATE_STATE, qid); end
  record = matches[1]
  if record~state == .QueueState~WAITING & record~wluRequirement~managed then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~ALREADY_MANAGED, qid, "already staged in waiting"); end
  if record~state \= .QueueState~PENDING then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~NOT_PENDING, qid, record~stateName); end

  requirement = record~wluRequirement
  if requirement~managed then do
    /* Safe crash-resume case: WLU metadata/hold was committed but the state move was not. */
    if record~jobClass \= .QueueWLUContract~HOLD_CLASS | \requirement~valid then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~INVALID_REQUIREMENT, qid, "partial WLU metadata is not a valid hold"); end
  end
  else do
    if requirementProvider == .nil then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~INVALID_REQUIREMENT, qid, "no WLU requirement provider"); end
    requirement = requirementProvider~requirementFor(record)
    if requirement == .nil | \requirement~isA(.QueueWLURequirement) | \requirement~managed | \requirement~valid then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~INVALID_REQUIREMENT, qid, "provider did not return a valid managed WLU requirement"); end
    if \.QueueWLUQueueBashFence~ensure(root, fileSystem) then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~FENCE_FAILED, qid); end
    if \metadataWriter~stage(record, requirement) then do; signal off syntax; lock~release; return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~WRITE_FAILED, qid); end
  end

  transition = transitionService~transitionWithLock(lock, qid, .QueueState~PENDING, .QueueState~WAITING, .QueueEvent~WLU_STAGED, .QueueLockActor~WLU_BRIDGE)
  signal off syntax
  lock~release
  if \transition~ok then return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~TRANSITION_FAILED, qid, transition~detail, transition)
  return .QueueWLUBridgeReceipt~new(.QueueWLUBridgeStatus~STAGED, qid, "QueueBash-created job fenced and staged for WLU admission", transition)
stageFailure:
  signal off syntax
  lock~release
  raise propagate

::requires "QueueRexxCore.cls"
::requires "QueueRexxOperations.cls"
::requires "QueueRexxMutation.cls"

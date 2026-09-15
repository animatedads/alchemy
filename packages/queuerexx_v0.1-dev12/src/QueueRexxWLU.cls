/* QueueRexxWLU.cls - WLU + Job-to-Node authority integration, v0.1-dev11.
 *
 * QueueRexx records WLU work amount and delivery-rate demand as immutable job
 * requirements.  The external WLU v0.12 authority remains authoritative for
 * admission/reservation/settlement.  Job-to-Node remains placement authority.
 *
 * A WLU-managed QueueRexx job is staged in QueueState~WAITING because a plain
 * QueueBash worker cannot enforce WLU.  Only a WLU-aware QueueRexx path may
 * request executable ownership after authoritative WLU + placement admission.
 */

::class QueueWLUCode public
::constant OK "WLU_OK"
::constant UNMANAGED "WLU_UNMANAGED"
::constant INVALID_REQUIREMENT "WLU_QUEUE_REQUIREMENT_INVALID"
::constant RECORD_NOT_FOUND "WLU_QUEUE_RECORD_NOT_FOUND"
::constant NOT_WAITING "WLU_QUEUE_NOT_WAITING"
::constant DEMAND_MISMATCH "WLU_QUEUE_DEMAND_MISMATCH"
::constant API_MISMATCH "WLU_QUEUE_API_MISMATCH"
::constant RESERVATION_UNKNOWN "WLU_RESERVATION_UNKNOWN"
::constant BINDING_WRITE_FAILED "WLU_BINDING_WRITE_FAILED"

::class QueueWLUProjectionAdapter public
::method fromReservationName class
  use strict arg valueArg
  value = valueArg~string~upper
  select
    when value == .WLUReservationState~ACTIVE then return .QueueWLUProjectionState~ACTIVE
    when value == .WLUReservationState~SETTLED then return .QueueWLUProjectionState~SETTLED
    when value == .WLUReservationState~RELEASED then return .QueueWLUProjectionState~RELEASED
    when value == .WLUReservationState~EXPIRED then return .QueueWLUProjectionState~EXPIRED
    otherwise return .QueueWLUProjectionState~UNKNOWN
  end

::class QueueWLUWorkDemandAdapter public
::method toDemand class
  use strict arg requirement
  if requirement == .nil then return .nil
  if \requirement~isA(.QueueWLURequirement) then return .nil
  if \requirement~managed then return .nil
  if \requirement~valid then return .nil
  return .WLUWorkDemand~new(requirement~expectedMicroWlu, requirement~ceilingMicroWlu, requirement~targetSeconds, requirement~requestedRateMicroWluPerSecond)

::class QueueWLUPlacementRequestAdapter public
::method fromRecord class
  use strict arg record, nodeRequirement, ownerNodeId = "", deadlineEpochMs = 0, policyTags = .nil
  requirement = record~wluRequirement
  expected = 0
  rate = 0
  if requirement~managed then do
    if \requirement~valid then raise syntax 88.900 array("invalid managed QueueRexx WLU requirement")
    expected = requirement~expectedMicroWlu
    rate = requirement~requestedRateMicroWluPerSecond
  end
  return .JobPlacementRequest~new(record~qid, nodeRequirement, ownerNodeId, expected, rate, deadlineEpochMs, policyTags)

/* This is a Job-to-Node admission authority, so the resulting WLU reservation
 * is bound into the authoritative JobNodePlacementLease.reservationRef and is
 * naturally carried through Migratable Job's fencing/handoff lifecycle.
 *
 * Unlike the stock JobNodeWLUAdmission adapter, QueueRexx reads the full WLU
 * declaration from the shared queue record so ceilingMicroWlu is not silently
 * collapsed to expectedMicroWlu. */
::class QueueJobNodeWLUAdmission subclass JobNodeWLUAdmission public
::attribute root get
::method init
  expose root store wluAuthority queueIdentity scopePrefixLocal lifecycleJournal lockManager
  use strict arg authorityArg, rootArg, identityArg = "QUEUEREXX", scopePrefixArg = "queue"
  self~init:super(authorityArg, identityArg, scopePrefixArg)
  wluAuthority = authorityArg
  root = rootArg~string
  store = .QueueStateStore~new(root)
  queueIdentity = identityArg~string
  scopePrefixLocal = scopePrefixArg~string
  lifecycleJournal = .QueueWLULifecycleJournal~new(root)
  lockManager = .QueueStateLockManager~new(root)

::method reserve
  expose lockManager
  use strict arg placementRequest, capability, capacity, leaseDurationMs
  lockResult = lockManager~acquireDetailed(placementRequest~jobId, .QueueLockActor~WLU_RESERVATION, 3)
  if \lockResult~acquired then return .JobNodeAdmissionResult~deny("WLU_QUEUE_LOCK_FAILED", lockResult~detail)
  lock = lockResult~handle
  signal on syntax name reserveFailure
  admitted = self~reserveLocked(placementRequest, capability, capacity, leaseDurationMs)
  signal off syntax
  lock~release
  return admitted
reserveFailure:
  signal off syntax
  lock~release
  raise propagate

::method reserveLocked private
  expose store wluAuthority queueIdentity scopePrefixLocal lifecycleJournal
  use strict arg placementRequest, capability, capacity, leaseDurationMs
  matches = store~findAll(placementRequest~jobId)
  if matches~items == 0 then return .JobNodeAdmissionResult~deny(.QueueWLUCode~RECORD_NOT_FOUND, placementRequest~jobId)
  if matches~items > 1 then return .JobNodeAdmissionResult~deny(.QueueMutationStatus~NAME_DUPLICATE_STATE, "QID exists in multiple queue states")
  record = matches[1]
  if record~state \= .QueueState~WAITING then return .JobNodeAdmissionResult~deny(.QueueWLUCode~NOT_WAITING, record~stateName)
  requirement = record~wluRequirement
  if \requirement~managed then return .JobNodeAdmissionResult~allow
  if \requirement~valid then return .JobNodeAdmissionResult~deny(.QueueWLUCode~INVALID_REQUIREMENT, "invalid managed WLU declaration")
  apiVersion = record~field(.QueueRecord~FIELD_WLU_API_VERSION, "")
  if apiVersion \= .QueueWLUContract~API_VERSION then return .JobNodeAdmissionResult~deny(.QueueWLUCode~API_MISMATCH, apiVersion)

  numeric digits 30
  if placementRequest~expectedMicroWlu \= requirement~expectedMicroWlu | placementRequest~requestedRateMicroWluPerSecond \= requirement~requestedRateMicroWluPerSecond then return .JobNodeAdmissionResult~deny(.QueueWLUCode~DEMAND_MISMATCH, "placement request understates or changes queue-declared WLU demand")

  demand = .QueueWLUWorkDemandAdapter~toDemand(requirement)
  if demand == .nil then return .JobNodeAdmissionResult~deny(.QueueWLUCode~INVALID_REQUIREMENT, "unable to construct WLUWorkDemand")
  ttl = (leaseDurationMs + 999) % 1000
  if ttl < 1 then ttl = 1
  effectiveScope = requirement~scope || "/node/" || capability~nodeId
  identity = requirement~identity
  if identity == "" then identity = queueIdentity
  requestId = placementRequest~jobId || ":" || capability~nodeId || ":" || capacity~observationGeneration
  admitted = wluAuthority~reserveDemand(identity, effectiveScope, demand, ttl, requestId)
  if \admitted~ok then return .JobNodeAdmissionResult~deny(admitted~code, admitted~detail)
  reservation = admitted~value
  binding = lifecycleJournal~recordReservation(placementRequest~jobId, reservation, self, capability~nodeId, capacity~observationGeneration)
  if binding == .nil then do
    ignore = wluAuthority~release(reservation)
    return .JobNodeAdmissionResult~deny(.QueueWLUCode~BINDING_WRITE_FAILED, "unable to persist QueueRexx WLU reservation binding")
  end
  return .JobNodeAdmissionResult~allow(reservation, reservation~reservationId)

::method release
  expose wluAuthority lifecycleJournal lockManager
  use strict arg reservation
  if reservation == .nil then return .true
  qid = ""
  bindingTx = ""
  do binding over lifecycleJournal~reservedBindings
    if binding~reservationRef == reservation~reservationId then do
      qid = binding~qid
      bindingTx = binding~transactionId
      leave
    end
  end
  lock = .nil
  if qid \= "" then do
    lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~WLU_RESERVATION_RELEASE, 3)
    if \lockResult~acquired then return .false
    lock = lockResult~handle
  end
  signal on syntax name releaseFailure
  state = wluAuthority~reservationState(reservation~reservationId)
  if state~ok then do
    if state~value == .WLUReservationState~RELEASED | state~value == .WLUReservationState~SETTLED | state~value == .WLUReservationState~EXPIRED then do
      signal off syntax
      if lock \= .nil then lock~release
      return .true
    end
  end
  closed = wluAuthority~release(reservation)
  if closed~ok & bindingTx \= "" then do
    d = .Directory~new
    d["qid"] = qid
    d["reservation_ref"] = reservation~reservationId
    d["wlu_code"] = closed~code
    lifecycleJournal~writePhase(bindingTx, .QueueWLULifecyclePhase~RESERVATION_RELEASED, d)
  end
  signal off syntax
  if lock \= .nil then lock~release
  return closed~ok
releaseFailure:
  signal off syntax
  if lock \= .nil then lock~release
  raise propagate

/* Projection does not become authority.  It asks the WLU authority for the
 * current reservation state when a placement lease supplies reservationRef. */
::class QueueWLUStatusProjection public
::attribute directory get
::method init
  expose directory
  use strict arg directoryArg
  directory = directoryArg
::method asDirectory
  expose directory
  return directory

::class QueueWLUStatusProjector public
::attribute authority get
::method init
  expose authority
  use arg authorityArg = .nil
  authority = authorityArg
::method project
  expose authority
  use strict arg record, placementLease = .nil
  requirement = record~wluRequirement
  d = .Directory~new
  d["schema"] = .QueueSchema~WLU_PROJECTION
  d["qid"] = record~qid
  d["api_version"] = .QueueWLUContract~API_VERSION
  d["requirement"] = requirement~asDirectory
  d["authority_note"] = "WLU authority owns work/capacity admission and settlement; QueueRexx projection is read-only"
  if \requirement~managed then do
    d["state"] = .QueueWLUProjectionState~name(.QueueWLUProjectionState~UNMANAGED)
    d["authoritative"] = .JSONBoolean~false
    return .QueueWLUStatusProjection~new(d)
  end
  d["state"] = .QueueWLUProjectionState~name(.QueueWLUProjectionState~DECLARED)
  d["authoritative"] = .JSONBoolean~false
  if placementLease == .nil | placementLease~reservationRef == "" then return .QueueWLUStatusProjection~new(d)
  d["placement_id"] = placementLease~placementId
  d["reservation_ref"] = placementLease~reservationRef
  if authority == .nil then return .QueueWLUStatusProjection~new(d)
  stateResult = authority~reservationState(placementLease~reservationRef)
  if \stateResult~ok then do
    d["reservation_query_code"] = stateResult~code
    d["reservation_query_detail"] = stateResult~detail
    return .QueueWLUStatusProjection~new(d)
  end
  stateCode = .QueueWLUProjectionAdapter~fromReservationName(stateResult~value)
  d["state"] = .QueueWLUProjectionState~name(stateCode)
  d["reservation_state"] = stateResult~value
  d["authoritative"] = .JSONBoolean~true
  return .QueueWLUStatusProjection~new(d)



/* Durable QueueRexx/WLU composition.  The queue filesystem and the WLU
 * authority intentionally remain separate authorities.  Immutable lifecycle
 * evidence lets restart reconcile whichever side committed before a crash. */
::class QueueWLULifecyclePhase public
::constant RESERVED 1
::constant ACTIVATED 2
::constant TERMINAL_PREPARED 3
::constant QUEUE_COMMITTED 4
::constant WLU_COMMITTED 5
::constant RESERVATION_RELEASED 6
::constant ABORTED 7
::constant AMBIGUOUS 8
::constant NAME_RESERVED "reserved"
::constant NAME_ACTIVATED "activated"
::constant NAME_TERMINAL_PREPARED "terminal_prepared"
::constant NAME_QUEUE_COMMITTED "queue_committed"
::constant NAME_WLU_COMMITTED "wlu_committed"
::constant NAME_RESERVATION_RELEASED "reservation_released"
::constant NAME_ABORTED "aborted"
::constant NAME_AMBIGUOUS "ambiguous"
::method name class
  use strict arg value
  select
    when value == self~RESERVED then return self~NAME_RESERVED
    when value == self~ACTIVATED then return self~NAME_ACTIVATED
    when value == self~TERMINAL_PREPARED then return self~NAME_TERMINAL_PREPARED
    when value == self~QUEUE_COMMITTED then return self~NAME_QUEUE_COMMITTED
    when value == self~WLU_COMMITTED then return self~NAME_WLU_COMMITTED
    when value == self~RESERVATION_RELEASED then return self~NAME_RESERVATION_RELEASED
    when value == self~ABORTED then return self~NAME_ABORTED
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    otherwise return "unknown"
  end

::class QueueWLUTerminalKind public
::constant COMPLETE 1
::constant FAIL 2
::constant CANCEL 3
::constant NAME_COMPLETE "complete"
::constant NAME_FAIL "fail"
::constant NAME_CANCEL "cancel"
::method name class
  use strict arg value
  select
    when value == self~COMPLETE then return self~NAME_COMPLETE
    when value == self~FAIL then return self~NAME_FAIL
    when value == self~CANCEL then return self~NAME_CANCEL
    otherwise return "unknown"
  end
::method toState class
  use strict arg value
  select
    when value == self~COMPLETE then return .QueueState~DONE
    when value == self~FAIL then return .QueueState~FAILED
    when value == self~CANCEL then return .QueueState~CANCELLED
    otherwise return .QueueState~UNKNOWN
  end
::method eventType class
  use strict arg value
  select
    when value == self~COMPLETE then return .QueueEvent~JOB_COMPLETED
    when value == self~FAIL then return .QueueEvent~JOB_FAILED
    when value == self~CANCEL then return .QueueEvent~JOB_CANCELLED
    otherwise return ""
  end

::class QueueWLUCloseAction public
::constant SETTLE 1
::constant RELEASE 2
::constant NAME_SETTLE "settle"
::constant NAME_RELEASE "release"
::method forTerminal class
  use strict arg terminalKind
  if terminalKind == .QueueWLUTerminalKind~CANCEL then return self~RELEASE
  return self~SETTLE
::method name class
  use strict arg value
  if value == self~SETTLE then return self~NAME_SETTLE
  if value == self~RELEASE then return self~NAME_RELEASE
  return "unknown"

::class QueueWLULifecycleStatus public
::constant OK 1
::constant INVALID 2
::constant LOCK_FAILED 3
::constant QUEUE_FAILED 4
::constant WLU_FAILED 5
::constant NO_BINDING 6
::constant AMBIGUOUS 7
::constant RECOVERED 8
::constant ABORTED 9
::constant NAME_OK "ok"
::constant NAME_INVALID "invalid"
::constant NAME_LOCK_FAILED "lock_failed"
::constant NAME_QUEUE_FAILED "queue_failed"
::constant NAME_WLU_FAILED "wlu_failed"
::constant NAME_NO_BINDING "no_binding"
::constant NAME_AMBIGUOUS "ambiguous"
::constant NAME_RECOVERED "recovered"
::constant NAME_ABORTED "aborted"
::method name class
  use strict arg value
  select
    when value == self~OK then return self~NAME_OK
    when value == self~INVALID then return self~NAME_INVALID
    when value == self~LOCK_FAILED then return self~NAME_LOCK_FAILED
    when value == self~QUEUE_FAILED then return self~NAME_QUEUE_FAILED
    when value == self~WLU_FAILED then return self~NAME_WLU_FAILED
    when value == self~NO_BINDING then return self~NAME_NO_BINDING
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    when value == self~RECOVERED then return self~NAME_RECOVERED
    when value == self~ABORTED then return self~NAME_ABORTED
    otherwise return "unknown"
  end

::class QueueWLULifecycleBinding public
::attribute transactionId get
::attribute qid get
::attribute reservationRef get
::attribute reservationSnapshot get
::attribute document get
::method init
  expose transactionId qid reservationRef reservationSnapshot document
  use strict arg transactionIdArg, qidArg, reservationRefArg, reservationSnapshotArg, documentArg
  transactionId = transactionIdArg~string
  qid = qidArg~string
  reservationRef = reservationRefArg~string
  reservationSnapshot = reservationSnapshotArg~string
  document = documentArg

::class QueueWLULifecycleJournal public
::constant DIRECTORY_NAME "queuerexx-wlu-lifecycle"
::attribute root get
::attribute fileSystem get
::method init
  expose root fileSystem
  use strict arg rootArg, fileSystemArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
::method directory
  expose root
  return root || "/" || .QueueMutationPath~LOGS || "/" || self~DIRECTORY_NAME
::method newTransactionId
  use strict arg qid
  return qid~string || "." || .QueueKernelTime~nonce || "." || random(0,999999)~right(6,"0")
::method phasePath
  use strict arg transactionId, phase
  return self~directory || "/" || transactionId || "." || .QueueWLULifecyclePhase~name(phase) || ".json"
::method phaseExists
  use strict arg transactionId, phase
  return SysFileExists(self~phasePath(transactionId, phase)) == 1
::method writePhase
  expose root fileSystem
  use strict arg transactionId, phase, data
  dir = self~directory
  if \fileSystem~ensureDirectory(dir) then return .false
  path = self~phasePath(transactionId, phase)
  if SysFileExists(path) then return .false
  temp = path || ".tmp." || random(0,999999)~right(6,"0")
  doc = .Directory~new
  doc["schema"] = .QueueSchema~WLU_LIFECYCLE
  doc["transaction_id"] = transactionId
  doc["phase"] = .QueueWLULifecyclePhase~name(phase)
  doc["recorded_at"] = .QueueKernelTime~nowIso
  doc["wlu"] = data
  .QueueSerialization~toJsonFile(doc, temp)
  if \SysFileExists(temp) then return .false
  if SysFileMove(temp, path) \= 0 then do
    call SysFileDelete temp
    return .false
  end
  fileSystem~ensureOwnerLike(dir, root)
  fileSystem~ensureOwnerLike(path, root)
  return .true
::method recordReservation
  use strict arg qid, reservation, admission, nodeId = "", observationGeneration = 0
  if reservation == .nil | \reservation~isA(.WLUReservation) then return .nil
  snapshot = admission~snapshotReservation(reservation)
  if snapshot == "" then return .nil
  txid = self~newTransactionId(qid)
  d = .Directory~new
  d["qid"] = qid~string
  d["reservation_ref"] = reservation~reservationId
  d["reservation_snapshot"] = snapshot
  d["expected_micro_wlu"] = reservation~expectedMicroWlu
  d["reserved_micro_wlu"] = reservation~reservedMicroWlu
  d["reserved_rate_micro_wlu_per_second"] = reservation~reservedRateMicroWluPerSecond
  d["node_id"] = nodeId~string
  d["capacity_observation_generation"] = observationGeneration + 0
  if \self~writePhase(txid, .QueueWLULifecyclePhase~RESERVED, d) then return .nil
  return .QueueWLULifecycleBinding~new(txid, qid, reservation~reservationId, snapshot, d)
::method reservedBindings
  arr = .Array~new
  dir = self~directory
  if \SysFileExists(dir) then return arr
  drop files.
  call SysFileTree dir || "/*.reserved.json", "files.", "FO"
  do i = 1 to files.0
    doc = self~readDocument(files.i)
    if doc == .nil | \doc~hasIndex("wlu") then iterate
    d = doc["wlu"]
    if \d~hasIndex("qid") | \d~hasIndex("reservation_ref") | \d~hasIndex("reservation_snapshot") then iterate
    arr~append(.QueueWLULifecycleBinding~new(doc["transaction_id"], d["qid"], d["reservation_ref"], d["reservation_snapshot"], d))
  end
  return arr
::method bindingsFor
  use strict arg qid
  arr = .Array~new
  do binding over self~reservedBindings
    if binding~qid == qid~string then arr~append(binding)
  end
  return arr
::method activeBindingsFor
  use strict arg qid, authority, admission
  arr = .Array~new
  do binding over self~bindingsFor(qid)
    reservation = admission~restoreReservation(binding~reservationSnapshot)
    if reservation == .nil then iterate
    stateResult = authority~reservationState(binding~reservationRef)
    if stateResult~ok then if stateResult~value == .WLUReservationState~ACTIVE then arr~append(binding)
  end
  return arr
::method readPhase
  use strict arg transactionId, phase
  path = self~phasePath(transactionId, phase)
  if \SysFileExists(path) then return .nil
  return self~readDocument(path)
::method readDocument private
  use strict arg path
  signal on syntax name badDoc
  doc = .QueueSerialization~fromJsonFile(path)
  signal off syntax
  return doc
badDoc:
  signal off syntax
  return .nil

::class QueueWLUActivationReceipt public
::attribute status get
::attribute qid get
::attribute transition get
::attribute detail get
::method init
  expose status qid transition detail
  use strict arg statusArg, qidArg, transitionArg = .nil, detailArg = ""
  status = statusArg + 0; qid = qidArg~string; transition = transitionArg; detail = detailArg~string
::method ok
  expose status
  return status == .QueueWLULifecycleStatus~OK

::class QueueWLUActivationService public
::attribute root get
::method init
  expose root authority admission journal lockManager transitionService
  use strict arg rootArg, authorityArg, admissionArg, journalArg = .nil, lockManagerArg = .nil, transitionArg = .nil
  root = rootArg~string; authority = authorityArg; admission = admissionArg
  if journalArg == .nil then journal = .QueueWLULifecycleJournal~new(root); else journal = journalArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root); else lockManager = lockManagerArg
  if transitionArg == .nil then transitionService = .QueueTransitionService~new(root, .nil, lockManager); else transitionService = transitionArg
::method activate
  expose authority admission journal lockManager transitionService
  use strict arg qidArg, placementLease
  qid = qidArg~string
  if placementLease == .nil | placementLease~jobId \= qid | placementLease~reservationRef == "" then return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, .nil, "placement lease does not bind this WLU job")
  bindings = journal~activeBindingsFor(qid, authority, admission)
  if bindings~items == 0 then return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~NO_BINDING, qid, .nil, "no active WLU reservation binding")
  if bindings~items > 1 then return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, qid, .nil, "multiple active WLU reservation bindings")
  binding = bindings[1]
  if binding~reservationRef \= placementLease~reservationRef then return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, .nil, "placement reservationRef differs from durable WLU binding")
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~WLU_ACTIVATION, 3)
  if \lockResult~acquired then return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~LOCK_FAILED, qid, .nil, lockResult~detail)
  lock = lockResult~handle
  signal on syntax name activationFailure
  activeNow = authority~reservationState(binding~reservationRef)
  if \activeNow~ok | activeNow~value \= .WLUReservationState~ACTIVE then do
    signal off syntax
    lock~release
    return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, .nil, "WLU reservation is no longer active")
  end
  transition = transitionService~transitionWithLock(lock, qid, .QueueState~WAITING, .QueueState~RUNNING, .QueueEvent~JOB_CLAIMED, .QueueLockActor~WLU_ACTIVATION)
  if \transition~ok then do
    signal off syntax
    lock~release
    return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~QUEUE_FAILED, qid, transition, transition~detail)
  end
  d = .Directory~new
  d["qid"] = qid
  d["placement_id"] = placementLease~placementId
  d["node_id"] = placementLease~nodeId
  d["reservation_ref"] = placementLease~reservationRef
  d["queue_transition_id"] = transition~transactionId
  journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~ACTIVATED, d)
  signal off syntax
  lock~release
  return .QueueWLUActivationReceipt~new(.QueueWLULifecycleStatus~OK, qid, transition)
activationFailure:
  signal off syntax
  lock~release
  raise propagate

::class QueueWLUUsageService public
::method init
  expose authority admission journal lockManager store
  use strict arg root, authorityArg, admissionArg, journalArg = .nil, lockManagerArg = .nil
  authority = authorityArg; admission = admissionArg; store = .QueueStateStore~new(root)
  if journalArg == .nil then journal = .QueueWLULifecycleJournal~new(root); else journal = journalArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root); else lockManager = lockManagerArg
::method consume
  expose authority admission journal lockManager store
  use strict arg qidArg, microWlu, operationId = ""
  qid = qidArg~string
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~WLU_USAGE, 3)
  if \lockResult~acquired then return .WLUResult~failure("WLU_QUEUE_LOCK_FAILED", lockResult~detail)
  lock = lockResult~handle
  signal on syntax name usageFailure
  record = store~findOne(qid)
  if record == .nil | record~state \= .QueueState~RUNNING then do
    signal off syntax
    lock~release
    return .WLUResult~failure("WLU_QUEUE_NOT_RUNNING", "usage can be recorded only while authoritative queue state is running")
  end
  bindings = journal~activeBindingsFor(qid, authority, admission)
  if bindings~items \= 1 then do
    signal off syntax
    lock~release
    return .WLUResult~failure(.QueueWLUCode~RESERVATION_UNKNOWN, "active QueueRexx WLU reservation is absent or ambiguous")
  end
  reservation = admission~restoreReservation(bindings[1]~reservationSnapshot)
  if reservation == .nil then do
    signal off syntax
    lock~release
    return .WLUResult~failure(.QueueWLUCode~RESERVATION_UNKNOWN, "durable WLU reservation proof cannot be restored")
  end
  consumed = authority~consume(reservation, microWlu, operationId)
  signal off syntax
  lock~release
  return consumed
usageFailure:
  signal off syntax
  lock~release
  raise propagate

::class QueueWLUTerminalReceipt public
::attribute status get
::attribute qid get
::attribute kind get
::attribute transition get
::attribute wluCode get
::attribute detail get
::method init
  expose status qid kind transition wluCode detail
  use strict arg statusArg, qidArg, kindArg, transitionArg = .nil, wluCodeArg = "", detailArg = ""
  status = statusArg + 0; qid = qidArg~string; kind = kindArg + 0; transition = transitionArg; wluCode = wluCodeArg~string; detail = detailArg~string
::method ok
  expose status
  return status == .QueueWLULifecycleStatus~OK | status == .QueueWLULifecycleStatus~RECOVERED
::method asDirectory
  expose status qid kind transition wluCode detail
  d = .Directory~new
  d["schema"] = .QueueSchema~WLU_LIFECYCLE
  d["status"] = .QueueWLULifecycleStatus~name(status)
  d["qid"] = qid
  d["terminal_kind"] = .QueueWLUTerminalKind~name(kind)
  d["wlu_code"] = wluCode
  d["detail"] = detail
  if transition \= .nil then d["transition"] = transition~asDirectory
  return d

::class QueueWLUTerminalService public
::method init
  expose root authority admission journal lockManager transitionService store
  use strict arg rootArg, authorityArg, admissionArg, journalArg = .nil, lockManagerArg = .nil, transitionArg = .nil
  root = rootArg~string; authority = authorityArg; admission = admissionArg; store = .QueueStateStore~new(root)
  if journalArg == .nil then journal = .QueueWLULifecycleJournal~new(root); else journal = journalArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root); else lockManager = lockManagerArg
  if transitionArg == .nil then transitionService = .QueueTransitionService~new(root, .nil, lockManager); else transitionService = transitionArg
::method complete
  use strict arg qid, actualMicroWlu = .nil
  return self~close(qid, .QueueWLUTerminalKind~COMPLETE, actualMicroWlu)
::method fail
  use strict arg qid, actualMicroWlu = .nil
  return self~close(qid, .QueueWLUTerminalKind~FAIL, actualMicroWlu)
::method cancel
  use strict arg qid
  return self~close(qid, .QueueWLUTerminalKind~CANCEL, .nil)
::method close
  expose authority admission journal lockManager transitionService store
  use strict arg qidArg, terminalKind, actualMicroWlu = .nil
  qid = qidArg~string
  toState = .QueueWLUTerminalKind~toState(terminalKind)
  if toState == .QueueState~UNKNOWN then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, terminalKind, .nil, "", "unknown terminal kind")
  bindings = journal~activeBindingsFor(qid, authority, admission)
  if bindings~items == 0 then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~NO_BINDING, qid, terminalKind, .nil, "", "no active WLU reservation binding")
  if bindings~items > 1 then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, qid, terminalKind, .nil, "", "multiple active WLU reservation bindings")
  binding = bindings[1]
  reservation = admission~restoreReservation(binding~reservationSnapshot)
  if reservation == .nil then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~NO_BINDING, qid, terminalKind, .nil, "", "durable WLU reservation proof cannot be restored")
  matches = store~findAll(qid)
  if matches~items \= 1 then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, qid, terminalKind, .nil, "", "queue record missing or duplicated")
  fromState = matches[1]~state
  if terminalKind \= .QueueWLUTerminalKind~CANCEL & fromState \= .QueueState~RUNNING then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, terminalKind, .nil, "", "complete/fail requires running state")
  if terminalKind == .QueueWLUTerminalKind~CANCEL then do
    if fromState \= .QueueState~WAITING & fromState \= .QueueState~RUNNING & fromState \= .QueueState~PAUSED then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, terminalKind, .nil, "", "cancel requires waiting/running/paused state")
  end
  action = .QueueWLUCloseAction~forTerminal(terminalKind)
  prep = .Directory~new
  prep["qid"] = qid
  prep["from_state"] = .QueueState~name(fromState)
  prep["to_state"] = .QueueState~name(toState)
  prep["terminal_kind"] = .QueueWLUTerminalKind~name(terminalKind)
  prep["wlu_action"] = .QueueWLUCloseAction~name(action)
  prep["reservation_ref"] = binding~reservationRef
  if actualMicroWlu == .nil then prep["actual_micro_wlu"] = ""
  else prep["actual_micro_wlu"] = actualMicroWlu + 0
  if journal~phaseExists(binding~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED) then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~INVALID, qid, terminalKind, .nil, "", "terminal operation already prepared; run WLU recovery")
  lockResult = lockManager~acquireDetailed(qid, .QueueLockActor~WLU_TERMINAL, 3)
  if \lockResult~acquired then return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~LOCK_FAILED, qid, terminalKind, .nil, "", lockResult~detail)
  lock = lockResult~handle
  signal on syntax name terminalFailure
  if \journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED, prep) then do
    signal off syntax
    lock~release
    return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~WLU_FAILED, qid, terminalKind, .nil, "WLU_LIFECYCLE_JOURNAL_WRITE_FAILED", "unable to persist WLU terminal intent")
  end
  transition = transitionService~transitionWithLock(lock, qid, fromState, toState, .QueueWLUTerminalKind~eventType(terminalKind), .QueueLockActor~WLU_TERMINAL)
  if \transition~ok then do
    journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~ABORTED, prep)
    signal off syntax
    lock~release
    return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~QUEUE_FAILED, qid, terminalKind, transition, "", transition~detail)
  end
  committed = prep~copy
  committed["queue_transition_id"] = transition~transactionId
  journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~QUEUE_COMMITTED, committed)
  closed = self~closeReservation(reservation, action, actualMicroWlu)
  if \closed~ok then do
    signal off syntax
    lock~release
    return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~WLU_FAILED, qid, terminalKind, transition, closed~code, "queue terminal state committed; WLU closure pending recovery: " || closed~detail)
  end
  committed["wlu_code"] = closed~code
  journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~WLU_COMMITTED, committed)
  signal off syntax
  lock~release
  return .QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~OK, qid, terminalKind, transition, closed~code)
terminalFailure:
  signal off syntax
  lock~release
  raise propagate
::method closeReservation private
  expose authority
  use strict arg reservation, action, actualMicroWlu = .nil
  state = authority~reservationState(reservation~reservationId)
  if \state~ok then return state
  if action == .QueueWLUCloseAction~SETTLE then do
    if state~value == .WLUReservationState~SETTLED then return .WLUResult~success(reservation, "already settled")
    if state~value \= .WLUReservationState~ACTIVE then return .WLUResult~failure("WLU_TERMINAL_STATE_CONFLICT", state~value)
    return authority~settle(reservation, actualMicroWlu)
  end
  if action == .QueueWLUCloseAction~RELEASE then do
    if state~value == .WLUReservationState~RELEASED then return .WLUResult~success(reservation, "already released")
    if state~value \= .WLUReservationState~ACTIVE then return .WLUResult~failure("WLU_TERMINAL_STATE_CONFLICT", state~value)
    return authority~release(reservation)
  end
  return .WLUResult~failure("WLU_TERMINAL_ACTION_INVALID", action)

::class QueueWLULifecycleRecovery public
::method init
  expose root authority admission journal lockManager store
  use strict arg rootArg, authorityArg, admissionArg, journalArg = .nil, lockManagerArg = .nil
  root = rootArg~string; authority = authorityArg; admission = admissionArg; store = .QueueStateStore~new(root)
  if journalArg == .nil then journal = .QueueWLULifecycleJournal~new(root); else journal = journalArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root); else lockManager = lockManagerArg
::method recover
  expose authority admission journal lockManager store
  outcomes = .Array~new
  do binding over journal~reservedBindings
    stateResult = authority~reservationState(binding~reservationRef)
    if \stateResult~ok then iterate
    if stateResult~value \= .WLUReservationState~ACTIVE then iterate
    reservation = admission~restoreReservation(binding~reservationSnapshot)
    if reservation == .nil then do
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, binding~qid, 0, .nil, .QueueWLUCode~RESERVATION_UNKNOWN, "cannot restore reservation proof"))
      iterate
    end
    preparedDoc = journal~readPhase(binding~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED)
    if preparedDoc == .nil then do
      /* Cross-engine terminal recovery.  QueueBash may cancel a QueueRexx-run
       * WLU job even though it does not understand WLU.  A terminal queue
       * state is authoritative evidence; synthesize the missing accounting
       * intent conservatively. */
      matches = store~findAll(binding~qid)
      if matches~items \= 1 then iterate
      state = matches[1]~state
      terminalKind = 0
      if state == .QueueState~DONE then terminalKind = .QueueWLUTerminalKind~COMPLETE
      else if state == .QueueState~FAILED then terminalKind = .QueueWLUTerminalKind~FAIL
      else if state == .QueueState~CANCELLED then terminalKind = .QueueWLUTerminalKind~CANCEL
      else iterate
      d = .Directory~new
      d["qid"] = binding~qid
      d["from_state"] = .QueueState~NAME_RUNNING
      d["to_state"] = .QueueState~name(state)
      d["terminal_kind"] = .QueueWLUTerminalKind~name(terminalKind)
      action = .QueueWLUCloseAction~forTerminal(terminalKind)
      d["wlu_action"] = .QueueWLUCloseAction~name(action)
      d["reservation_ref"] = binding~reservationRef
      d["actual_micro_wlu"] = ""
      if \journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED, d) then iterate
      preparedDoc = journal~readPhase(binding~transactionId, .QueueWLULifecyclePhase~TERMINAL_PREPARED)
    end
    prep = preparedDoc["wlu"]
    toState = .QueueState~fromName(prep["to_state"])
    terminalKindName = prep["terminal_kind"]~string
    if terminalKindName == .QueueWLUTerminalKind~NAME_COMPLETE then terminalKind = .QueueWLUTerminalKind~COMPLETE
    else if terminalKindName == .QueueWLUTerminalKind~NAME_FAIL then terminalKind = .QueueWLUTerminalKind~FAIL
    else if terminalKindName == .QueueWLUTerminalKind~NAME_CANCEL then terminalKind = .QueueWLUTerminalKind~CANCEL
    else do
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, binding~qid, 0, .nil, "", "unknown prepared terminal kind"))
      iterate
    end
    matches = store~findAll(binding~qid)
    if matches~items \= 1 then do
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, binding~qid, terminalKind, .nil, "", "queue state missing or duplicated during WLU recovery"))
      iterate
    end
    if matches[1]~state \= toState then do
      fromState = .QueueState~fromName(prep["from_state"])
      if matches[1]~state == fromState then do
        journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~ABORTED, prep)
        outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~ABORTED, binding~qid, terminalKind, .nil, "", "queue transition did not commit; WLU left active"))
      end
      else outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, binding~qid, terminalKind, .nil, "", "queue state conflicts with prepared WLU terminal intent"))
      iterate
    end
    lockResult = lockManager~acquireDetailed(binding~qid, .QueueLockActor~WLU_RECOVERY, 3)
    if \lockResult~acquired then do
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~LOCK_FAILED, binding~qid, terminalKind, .nil, "", lockResult~detail))
      iterate
    end
    lock = lockResult~handle
    signal on syntax name recoveryFailure
    lockedMatches = store~findAll(binding~qid)
    if lockedMatches~items \= 1 | lockedMatches[1]~state \= toState then do
      signal off syntax
      lock~release
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~AMBIGUOUS, binding~qid, terminalKind, .nil, "", "queue authority changed before WLU recovery lock was acquired"))
      iterate
    end
    journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~QUEUE_COMMITTED, prep)
    actionName = prep["wlu_action"]~string
    if actionName == .QueueWLUCloseAction~NAME_RELEASE then closed = authority~release(reservation)
    else do
      actual = prep["actual_micro_wlu"]
      if actual == "" then closed = authority~settle(reservation)
      else closed = authority~settle(reservation, actual + 0)
    end
    if closed~ok then do
      journal~writePhase(binding~transactionId, .QueueWLULifecyclePhase~WLU_COMMITTED, prep)
      outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~RECOVERED, binding~qid, terminalKind, .nil, closed~code, "completed WLU closure from authoritative terminal queue state"))
    end
    else outcomes~append(.QueueWLUTerminalReceipt~new(.QueueWLULifecycleStatus~WLU_FAILED, binding~qid, terminalKind, .nil, closed~code, closed~detail))
    signal off syntax
    lock~release
  end
  return outcomes
recoveryFailure:
  signal off syntax
  lock~release
  raise propagate


/* WLU-aware scheduling admission.  Priority remains queue priority; WLU is
 * an eligibility/capacity authority and is never converted into priority. */
::class QueueWLUSchedulingAdmission public subclass QueueSchedulingAdmissionProvider
::attribute authority get
::attribute admission get
::attribute journal get
::attribute leaseLookup get
::attribute placementAuthority get
::method init
  expose authority admission journal leaseLookup placementAuthority fallback
  use arg authorityArg, admissionArg, journalArg, leaseLookupArg, placementAuthorityArg = .nil
  authority = authorityArg; admission = admissionArg; journal = journalArg; leaseLookup = leaseLookupArg; placementAuthority = placementAuthorityArg
  fallback = .QueueDefaultSchedulingAdmission~new
::method assess
  expose authority admission journal leaseLookup placementAuthority fallback
  use strict arg record
  if \record~wluRequirement~managed then return fallback~assess(record)
  if record~state \= .QueueState~WAITING then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_RESERVATION_REQUIRED, "managed WLU work must remain waiting until activation")
  bindings = journal~activeBindingsFor(record~qid, authority, admission)
  if bindings~items \= 1 then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_RESERVATION_REQUIRED, "exactly one active WLU reservation is required")
  binding = bindings[1]
  state = authority~reservationState(binding~reservationRef)
  if \state~ok | state~value \= .WLUReservationState~ACTIVE then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_RESERVATION_REQUIRED, "WLU reservation is not active")
  if leaseLookup == .nil then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_PLACEMENT_REQUIRED, "placement lookup is not configured")
  lease = leaseLookup~lookup(record~qid)
  if lease == .nil then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_PLACEMENT_REQUIRED, "no placement lease for WLU job")
  if lease~jobId \= record~qid | lease~reservationRef \= binding~reservationRef then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~WLU_BINDING_MISMATCH, "placement lease and WLU reservation binding differ")
  if placementAuthority == .nil then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~JOB_NODE_AUTHORITY_REQUIRED, "Job-to-Node lease verifier is not configured")
  placementRequest = leaseLookup~lookupRequest(record~qid)
  if placementRequest == .nil then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~JOB_NODE_REQUEST_REQUIRED, "exact Job-to-Node placement request is not retained")
  verification = placementAuthority~verify(record, lease, placementRequest)
  if \verification~verified then return .QueueSchedulingAdmissionVerdict~no(.QueueSchedulingCode~JOB_NODE_LEASE_INVALID, verification~code || ":" || verification~detail, verification~asDirectory)
  d = .Directory~new
  d["reservation_ref"] = binding~reservationRef
  d["placement_id"] = lease~placementId
  d["node_id"] = lease~nodeId
  d["ownership_epoch"] = lease~ownershipEpoch
  d["expected_micro_wlu"] = record~wluRequirement~expectedMicroWlu
  d["ceiling_micro_wlu"] = record~wluRequirement~ceilingMicroWlu
  d["requested_rate_micro_wlu_per_second"] = record~wluRequirement~requestedRateMicroWluPerSecond
  d["job_node_verification"] = verification~asDirectory
  return .QueueSchedulingAdmissionVerdict~yes(.QueueSchedulingCode~ELIGIBLE, "WLU reservation is active and Job-to-Node v0.6 verifies current placement/ownership authority", d, lease)

::requires "QueueRexxScheduling.cls"
::requires "QueueRexxCore.cls"
::requires "QueueRexxMutation.cls"
::requires "WorkLoadUnits.cls"
::requires "JobNodeWLUAdapter.cls"

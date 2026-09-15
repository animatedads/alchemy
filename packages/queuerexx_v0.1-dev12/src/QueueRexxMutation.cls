/* QueueRexxMutation.cls - recovery-safe shared filesystem mutation kernel, v0.1-dev6 */

::class QueueMutationStatus public
::constant OK 1
::constant LOCK_TIMEOUT 2
::constant SOURCE_NOT_FOUND 3
::constant DESTINATION_EXISTS 4
::constant DUPLICATE_STATE 5
::constant IO_ERROR 6
::constant COLLISION 7
::constant AMBIGUOUS 8
::constant ABORTED 9
::constant RECOVERED 10
::constant LOCK_PERMISSION_DENIED 11

::constant NAME_OK "ok"
::constant NAME_LOCK_TIMEOUT "lock_timeout"
::constant NAME_SOURCE_NOT_FOUND "source_not_found"
::constant NAME_DESTINATION_EXISTS "destination_exists"
::constant NAME_DUPLICATE_STATE "duplicate_state"
::constant NAME_IO_ERROR "io_error"
::constant NAME_COLLISION "collision"
::constant NAME_AMBIGUOUS "ambiguous"
::constant NAME_ABORTED "aborted"
::constant NAME_RECOVERED "recovered"
::constant NAME_LOCK_PERMISSION_DENIED "lock_permission_denied"

::method name class
  use arg value
  select
    when value == self~OK then return self~NAME_OK
    when value == self~LOCK_TIMEOUT then return self~NAME_LOCK_TIMEOUT
    when value == self~SOURCE_NOT_FOUND then return self~NAME_SOURCE_NOT_FOUND
    when value == self~DESTINATION_EXISTS then return self~NAME_DESTINATION_EXISTS
    when value == self~DUPLICATE_STATE then return self~NAME_DUPLICATE_STATE
    when value == self~IO_ERROR then return self~NAME_IO_ERROR
    when value == self~COLLISION then return self~NAME_COLLISION
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    when value == self~ABORTED then return self~NAME_ABORTED
    when value == self~RECOVERED then return self~NAME_RECOVERED
    when value == self~LOCK_PERMISSION_DENIED then return self~NAME_LOCK_PERMISSION_DENIED
    otherwise return "unknown"
  end

::class QueueTransitionPhase public
::constant PREPARED 1
::constant COMMITTED 2
::constant ABORTED 3
::constant RECOVERED 4
::constant AMBIGUOUS 5
::constant EVENT_RECORDED 6
::constant NAME_PREPARED "prepared"
::constant NAME_COMMITTED "committed"
::constant NAME_ABORTED "aborted"
::constant NAME_RECOVERED "recovered"
::constant NAME_AMBIGUOUS "ambiguous"
::constant NAME_EVENT_RECORDED "event_recorded"
::method name class
  use arg value
  select
    when value == self~PREPARED then return self~NAME_PREPARED
    when value == self~COMMITTED then return self~NAME_COMMITTED
    when value == self~ABORTED then return self~NAME_ABORTED
    when value == self~RECOVERED then return self~NAME_RECOVERED
    when value == self~AMBIGUOUS then return self~NAME_AMBIGUOUS
    when value == self~EVENT_RECORDED then return self~NAME_EVENT_RECORDED
    otherwise return "unknown"
  end

::class QueueLockActor public
::constant PENDING_ALLOCATOR "queuerexx-pending-allocator"
::constant WLU_WAITING_ALLOCATOR "queuerexx-wlu-waiting-allocator"
::constant WLU_RESERVATION "queuerexx-wlu-reservation"
::constant WLU_RESERVATION_RELEASE "queuerexx-wlu-reservation-release"
::constant WLU_ACTIVATION "queuerexx-wlu-activation"
::constant WLU_USAGE "queuerexx-wlu-usage"
::constant WLU_TERMINAL "queuerexx-wlu-terminal"
::constant WLU_RECOVERY "queuerexx-wlu-recovery"
::constant WLU_BRIDGE "queuerexx-wlu-bridge"
::constant EXECUTION_START "queuerexx-execution-start"
::constant EXECUTION_RECONCILE "queuerexx-execution-reconcile"
::constant EXECUTION_CANCEL "queuerexx-execution-cancel"
::constant MIGRATABLE_START_INTENT "queuerexx-migratable-start-intent"
::constant TRANSITION "queuerexx-transition"
::constant RECOVERY "queuerexx-recovery"

::class QueueMutationPath public
::constant LOCKS "locks"
::constant STATE_LOCKS "state"
::constant LOGS "logs"
::constant TRANSITION_JOURNAL "queuerexx-transitions"
::constant EVENTS_FILE "events.jsonl"
::constant RECONCILE_ARCHIVE "queue-state-reconcile"

::class QueueTransitionSchema public
::constant JOURNAL "queuerexx.transition_journal.v1"
::constant RECEIPT "queuerexx.transition_receipt.v1"
::constant RECOVERY "queuerexx.transition_recovery.v1"

::class QueueAtomicFileSystem public
::method ensureDirectory abstract
::method exclusiveCreate abstract
::method move abstract
::method replace abstract
::method exists abstract
::method removeEmptyLock abstract
::method processId abstract
::method ensureOwnerLike abstract
::method ensureOwnerLikeShallow abstract

::class QueuePosixAtomicFileSystem public subclass QueueAtomicFileSystem
::attribute executor get
::method init
  expose executor
  use arg executorArg = .nil
  if executorArg == .nil then executor = .QueueSystemCommandExecutor~new
  else executor = executorArg

::method ensureDirectory
  expose executor
  use arg path
  if SysFileExists(path) then return .true
  command = "mkdir -p -- " || .QueuePosixShell~quote(path)
  return executor~run(command)~rc == 0

::method exclusiveCreate
  expose executor
  use arg path
  /* POSIX shell noclobber gives the same no-overwrite property used by
   * QueueBash 0.18.144.  It is deliberately isolated behind this provider. */
  body = "set -C; : > " || .QueuePosixShell~quote(path)
  command = "sh -c " || .QueuePosixShell~quote(body)
  return executor~run(command)~rc == 0

::method move
  use arg sourcePath, destinationPath
  if SysFileExists(destinationPath) then return .false
  return SysFileMove(sourcePath, destinationPath) == 0

::method replace
  expose executor
  use arg sourcePath, destinationPath
  command = "mv -f -- " || .QueuePosixShell~quote(sourcePath) || " " || .QueuePosixShell~quote(destinationPath)
  return executor~run(command)~rc == 0

::method exists
  use arg path
  return SysFileExists(path) == 1

::method removeEmptyLock
  use arg lockPath
  meta = lockPath || "/meta"
  if SysFileExists(meta) then call SysFileDelete meta
  return SysRmDir(lockPath) == 0

::method processId
  expose executor
  /* ADDRESS SYSTEM's shell is the direct child of the Rexx process, so PPID
   * is the owning Rexx PID.  Do not add another nested shell here. */
  command = 'printf "%s" "$PPID"'
  r = executor~run(command)
  if r~rc == 0 & r~output~items > 0 then do
    p = r~output[1]~strip
    if p~datatype("W") then return p + 0
  end
  return -1

::method ensureOwnerLike
  expose executor
  use arg path, ownerRoot
  uid = .QueueRexxUtil~shellOutput("id -u 2>/dev/null")
  if uid \= "0" then return .true
  if \SysFileExists(ownerRoot) then return .true
  owner = .QueueRexxUtil~shellOutput("stat -c %U -- " || .QueuePosixShell~quote(ownerRoot) || " 2>/dev/null")
  if owner == "" | owner == "root" then return .true
  command = "chown -R -- " || .QueuePosixShell~quote(owner) || " " || .QueuePosixShell~quote(path)
  return executor~run(command)~rc == 0

::method ensureOwnerLikeShallow
  expose executor
  use arg path, ownerRoot
  uid = .QueueRexxUtil~shellOutput("id -u 2>/dev/null")
  if uid \= "0" then return .true
  if \SysFileExists(ownerRoot) then return .true
  owner = .QueueRexxUtil~shellOutput("stat -c %U -- " || .QueuePosixShell~quote(ownerRoot) || " 2>/dev/null")
  if owner == "" | owner == "root" then return .true
  command = "chown -- " || .QueuePosixShell~quote(owner) || " " || .QueuePosixShell~quote(path)
  return executor~run(command)~rc == 0

::class QueueKernelTime public
::method nowIso class
  value = .QueueRexxUtil~shellOutput("date -Is 2>/dev/null")
  if value == "" then value = .DateTime~new~isoDate
  return value

::method idDate class
  d = .DateTime~new
  return d~standardDate || "_" || d~normalTime~changestr(":", "")

::method nonce class
  d = .DateTime~new
  return d~standardDate || d~longTime~changestr(":", "")~changestr(".", "")

::class QueueLockAcquireStatus public
::constant ACQUIRED 1
::constant TIMEOUT 2
::constant PERMISSION_DENIED 3
::constant IO_ERROR 4
::constant NAME_ACQUIRED "acquired"
::constant NAME_TIMEOUT "timeout"
::constant NAME_PERMISSION_DENIED "permission_denied"
::constant NAME_IO_ERROR "io_error"
::method name class
  use arg value
  select
    when value == self~ACQUIRED then return self~NAME_ACQUIRED
    when value == self~TIMEOUT then return self~NAME_TIMEOUT
    when value == self~PERMISSION_DENIED then return self~NAME_PERMISSION_DENIED
    when value == self~IO_ERROR then return self~NAME_IO_ERROR
    otherwise return "unknown"
  end

::class QueueLockAcquireResult public
::attribute status get
::attribute handle get
::attribute path get
::attribute detail get
::method init
  expose status handle path detail
  use arg statusArg, handleArg = .nil, pathArg = "", detailArg = ""
  status = statusArg + 0
  handle = handleArg
  path = pathArg~string
  detail = detailArg~string
::method acquired
  expose status
  return status == .QueueLockAcquireStatus~ACQUIRED

::class QueueStateLockHandle public
::attribute path get
::attribute qid get
::attribute owned get
::attribute fileSystem get
::method init
  expose path qid owned fileSystem
  use arg pathArg, qidArg, fileSystemArg, ownedArg = .true
  path = pathArg~string
  qid = qidArg~string
  fileSystem = fileSystemArg
  owned = ownedArg
::method release
  expose path owned fileSystem
  if \owned then return .true
  ok = fileSystem~removeEmptyLock(path)
  if ok then owned = .false
  return ok

::class QueueStateLockManager public
::constant DEFAULT_TIMEOUT_SECONDS 3
::constant POLL_SECONDS 0.05
::attribute root get
::attribute fileSystem get
::attribute processProbe get
::method init
  expose root fileSystem processProbe
  use arg rootArg, fileSystemArg = .nil, processProbeArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
  if processProbeArg == .nil then processProbe = .QueueLinuxProcessProbe~new
  else processProbe = processProbeArg

::method locksRoot
  expose root
  return root || "/" || .QueueMutationPath~LOCKS

::method stateLocksRoot
  return self~locksRoot || "/" || .QueueMutationPath~STATE_LOCKS

::method reconcileArchiveRoot
  expose root
  return root || "/" || .QueueMutationPath~LOGS || "/" || .QueueMutationPath~RECONCILE_ARCHIVE

::method prepareTree
  expose root fileSystem
  locks = self~locksRoot
  stateLocks = self~stateLocksRoot
  archive = self~reconcileArchiveRoot
  if \fileSystem~ensureDirectory(locks) then return .false
  if \fileSystem~ensureDirectory(stateLocks) then return .false
  if \fileSystem~ensureDirectory(archive) then return .false
  fileSystem~ensureOwnerLikeShallow(locks, root)
  fileSystem~ensureOwnerLikeShallow(stateLocks, root)
  fileSystem~ensureOwnerLikeShallow(archive, root)
  return .true

::method pathFor
  use arg qid
  return self~stateLocksRoot || "/" || qid || ".lock"

::method writable
  expose fileSystem
  base = self~stateLocksRoot
  if \self~prepareTree then return .false
  probe = base || "/.permission_probe_" || fileSystem~processId || "_" || random(0,999999)~right(6,"0")
  if \fileSystem~exclusiveCreate(probe) then return .false
  call SysFileDelete probe
  return .true

::method acquire
  use arg qidArg, actorArg = .nil, timeoutArg = .nil
  detailed = self~acquireDetailed(qidArg, actorArg, timeoutArg)
  if detailed~acquired then return detailed~handle
  return .nil

::method acquireDetailed
  expose root fileSystem processProbe
  use arg qidArg, actorArg = .nil, timeoutArg = .nil
  qid = qidArg~string
  if actorArg == .nil then actor = .QueueLockActor~TRANSITION
  else actor = actorArg~string
  if timeoutArg == .nil then timeout = self~DEFAULT_TIMEOUT_SECONDS
  else timeout = timeoutArg + 0
  if \self~prepareTree then return .QueueLockAcquireResult~new(.QueueLockAcquireStatus~IO_ERROR, .nil, self~stateLocksRoot, "unable to prepare lock tree")
  if \self~writable then return .QueueLockAcquireResult~new(.QueueLockAcquireStatus~PERMISSION_DENIED, .nil, self~stateLocksRoot, "state lock directory is not writable")
  lockPath = self~pathFor(qid)
  started = time("E")
  do forever
    if SysMkDir(lockPath) == 0 then do
      if \self~writeMeta(lockPath, actor) then do
        fileSystem~removeEmptyLock(lockPath)
        return .QueueLockAcquireResult~new(.QueueLockAcquireStatus~IO_ERROR, .nil, lockPath, "unable to write lock metadata")
      end
      fileSystem~ensureOwnerLike(lockPath, root)
      handle = .QueueStateLockHandle~new(lockPath, qid, fileSystem, .true)
      return .QueueLockAcquireResult~new(.QueueLockAcquireStatus~ACQUIRED, handle, lockPath)
    end
    ownerPid = self~ownerPid(lockPath)
    ownerHost = self~ownerMetaValue(lockPath, "host")
    currentHost = .QueueRexxUtil~shellOutput("hostname 2>/dev/null")
    sameHost = (ownerHost == "" | currentHost == "" | ownerHost == currentHost)
    if ownerPid > 0 & sameHost then do
      if \processProbe~pidAlive(ownerPid) then do
        if fileSystem~removeEmptyLock(lockPath) then iterate
      end
      else do
        recordedCookie = self~ownerMetaValue(lockPath, "process_start_cookie")
        currentCookie = self~processStartCookie(ownerPid)
        if recordedCookie \= "" & currentCookie \= "" & recordedCookie \= currentCookie then do
          if fileSystem~removeEmptyLock(lockPath) then iterate
        end
      end
    end
    if timeout >= 0 & time("E") - started >= timeout then return .QueueLockAcquireResult~new(.QueueLockAcquireStatus~TIMEOUT, .nil, lockPath, "state lock timeout")
    call SysSleep self~POLL_SECONDS
  end

::method writeMeta private
  expose root fileSystem
  use arg lockPath, actor
  pid = fileSystem~processId
  s = .Stream~new(lockPath || "/meta")
  if s~open("WRITE REPLACE") \= "READY:" then return .false
  s~lineOut("pid=" || pid)
  s~lineOut("uid=" || .QueueRexxUtil~shellOutput("id -u 2>/dev/null"))
  s~lineOut("user=" || .QueueRexxUtil~currentUser)
  s~lineOut("host=" || .QueueRexxUtil~shellOutput("hostname 2>/dev/null"))
  s~lineOut("created_at=" || .QueueKernelTime~nowIso)
  s~lineOut("actor=" || actor)
  s~lineOut("queue_root=" || root)
  s~lineOut("process_start_cookie=" || self~processStartCookie(pid))
  s~close
  return .true

::method processStartCookie private
  use arg pid
  if pid <= 0 then return ""
  statPath = "/proc/" || pid || "/stat"
  if \SysFileExists(statPath) then return ""
  stream = .Stream~new(statPath)
  if stream~open("READ") \= "READY:" then return ""
  line = stream~lineIn
  stream~close
  /* /proc/<pid>/stat field 2 is a parenthesized command and may contain
   * spaces.  Everything after its final ')' starts at field 3.  starttime is
   * field 22, therefore word 20 of that suffix. */
  closeParen = line~lastPos(")")
  if closeParen == 0 then return ""
  suffix = line~substr(closeParen + 1)~strip
  if suffix~words < 20 then return ""
  return suffix~word(20)

::method ownerMetaValue private
  use arg lockPath, keyArg
  key = keyArg~string || "="
  p = lockPath || "/meta"
  if \SysFileExists(p) then return ""
  s = .Stream~new(p)
  if s~open("READ") \= "READY:" then return ""
  found = ""
  do while s~lines > 0
    line = s~lineIn
    if line~left(key~length) == key then do
      found = line~substr(key~length + 1)~strip
      leave
    end
  end
  s~close
  return found

::method ownerPid
  use arg lockPath
  text = self~ownerMetaValue(lockPath, "pid")
  if text~datatype("W") then return text + 0
  return -1

::class QueueIdGenerator public
::attribute fileSystem get
::method init
  expose fileSystem
  use arg fileSystemArg = .nil
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
::method next
  expose fileSystem
  return .QueueKernelTime~idDate || "_" || .QueueKernelTime~nonce || "_" || random(0, 999999)~right(6, "0") || "_" || fileSystem~processId

::class QueuePendingPath public
::constant DEFAULT_PRIORITY 10
::method bucketKey class
  use arg priorityArg = .nil
  if priorityArg == .nil then priority = self~DEFAULT_PRIORITY
  else priority = priorityArg
  if \priority~string~datatype("W") then priority = self~DEFAULT_PRIORITY
  n = 1000000000 - (priority + 0)
  return "p" || n~right(10, "0")
::method path class
  use arg root, qid, priority = .nil
  return root || "/" || .QueueState~NAME_PENDING || "/" || self~bucketKey(priority) || "/" || qid || ".job"

::class QueueWaitingPath public
::method path class
  use strict arg root, qid, priority = (.QueuePendingPath~DEFAULT_PRIORITY)
  return root || "/" || .QueueState~NAME_WAITING || "/" || .QueuePendingPath~bucketKey(priority) || "/" || qid || ".job"

::class QueuePendingReservation public
::attribute qid get
::attribute path get
::attribute priority get
::attribute lock get
::attribute committed get
::method init
  expose qid path priority lock committed
  use arg qidArg, pathArg, priorityArg, lockArg
  qid = qidArg~string; path = pathArg~string; priority = priorityArg + 0; lock = lockArg; committed = .false
::method markCommitted
  expose committed
  committed = .true
  return self
::method release
  expose lock
  return lock~release

::class QueuePendingAllocator public
::constant DEFAULT_RETRIES 100
::attribute root get
::attribute fileSystem get
::attribute lockManager get
::attribute idGenerator get
::method init
  expose root fileSystem lockManager idGenerator
  use arg rootArg, fileSystemArg = .nil, lockManagerArg = .nil, idGeneratorArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, fileSystem)
  else lockManager = lockManagerArg
  if idGeneratorArg == .nil then idGenerator = .QueueIdGenerator~new(fileSystem)
  else idGenerator = idGeneratorArg

::method reserve
  expose root fileSystem lockManager idGenerator
  use arg priorityArg = .nil, retriesArg = .nil
  if priorityArg == .nil then priority = .QueuePendingPath~DEFAULT_PRIORITY
  else priority = priorityArg + 0
  if retriesArg == .nil then retries = self~DEFAULT_RETRIES
  else retries = retriesArg + 0
  store = .QueueStateStore~new(root)
  do attempt = 1 to retries
    qid = idGenerator~next
    lock = lockManager~acquire(qid, .QueueLockActor~PENDING_ALLOCATOR, 0)
    if lock == .nil then iterate
    if store~findAll(qid)~items > 0 then do; lock~release; iterate; end
    path = .QueuePendingPath~path(root, qid, priority)
    parent = path~left(path~lastpos("/") - 1)
    if \fileSystem~ensureDirectory(parent) then do; lock~release; return .nil; end
    if fileSystem~exclusiveCreate(path) then do
      fileSystem~ensureOwnerLike(parent, root)
      fileSystem~ensureOwnerLike(path, root)
      return .QueuePendingReservation~new(qid, path, priority, lock)
    end
    lock~release
  end
  return .nil

::class QueueWaitingAllocator public
::constant DEFAULT_RETRIES 100
::attribute root get
::attribute fileSystem get
::attribute lockManager get
::attribute idGenerator get
::method init
  expose root fileSystem lockManager idGenerator
  use arg rootArg, fileSystemArg = .nil, lockManagerArg = .nil, idGeneratorArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, fileSystem)
  else lockManager = lockManagerArg
  if idGeneratorArg == .nil then idGenerator = .QueueIdGenerator~new(fileSystem)
  else idGenerator = idGeneratorArg

::method reserve
  expose root fileSystem lockManager idGenerator
  use arg priorityArg = .nil, retriesArg = .nil
  if priorityArg == .nil then priority = .QueuePendingPath~DEFAULT_PRIORITY
  else priority = priorityArg + 0
  if retriesArg == .nil then retries = self~DEFAULT_RETRIES
  else retries = retriesArg + 0
  store = .QueueStateStore~new(root)
  do attempt = 1 to retries
    qid = idGenerator~next
    lock = lockManager~acquire(qid, .QueueLockActor~WLU_WAITING_ALLOCATOR, 0)
    if lock == .nil then iterate
    if store~findAll(qid)~items > 0 then do; lock~release; iterate; end
    path = .QueueWaitingPath~path(root, qid, priority)
    parent = path~left(path~lastpos("/") - 1)
    if \fileSystem~ensureDirectory(parent) then do; lock~release; return .nil; end
    if fileSystem~exclusiveCreate(path) then do
      fileSystem~ensureOwnerLike(parent, root)
      fileSystem~ensureOwnerLike(path, root)
      return .QueuePendingReservation~new(qid, path, priority, lock)
    end
    lock~release
  end
  return .nil

::class QueueBashEventLog public subclass QueueEventSink
::attribute root get
::attribute fileSystem get
::method init
  expose root fileSystem
  use arg rootArg, fileSystemArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
::method append
  expose root fileSystem
  use arg event
  d = .Directory~new
  d["ts"] = event~occurredAt
  d["event"] = event~type
  d["job_id"] = event~qid
  d["job_name"] = ""
  d["state"] = event~state
  detail = ""
  if event~data~hasIndex("detail") then detail = event~data["detail"]~string
  if detail \= "" then d["detail"] = detail
  line = .QueueSerialization~toJson(d)
  s = .Stream~new(root || "/" || .QueueMutationPath~EVENTS_FILE)
  if s~open("WRITE APPEND") \= "READY:" then return .false
  s~lineOut(line)
  s~close
  fileSystem~ensureOwnerLike(root || "/" || .QueueMutationPath~EVENTS_FILE, root)
  return .true

::method containsTransaction
  expose root
  use arg transactionIdArg
  transactionId = transactionIdArg~string
  path = root || "/" || .QueueMutationPath~EVENTS_FILE
  if \SysFileExists(path) then return .false
  s = .Stream~new(path)
  if s~open("READ") \= "READY:" then return .false
  found = .false
  do while s~lines > 0
    line = s~lineIn
    if line~strip == "" then iterate
    if self~lineContainsTransaction(line, transactionId) then do
      found = .true
      leave
    end
  end
  s~close
  return found

::method lineContainsTransaction private
  use arg line, transactionId
  signal on syntax name malformedEvent
  d = .QueueSerialization~fromJson(line)
  signal off syntax
  if \d~hasIndex("detail") then return .false
  return d["detail"]~string~pos("transaction=" || transactionId) > 0
malformedEvent:
  signal off syntax
  return .false

::class QueueTransitionJournal public
::attribute root get
::attribute fileSystem get
::method init
  expose root fileSystem
  use arg rootArg, fileSystemArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg

::method directory
  expose root
  return root || "/" || .QueueMutationPath~LOGS || "/" || .QueueMutationPath~TRANSITION_JOURNAL

::method newTransactionId
  use arg qid
  return qid || "." || .QueueKernelTime~nonce || "." || random(0,999999)~right(6,"0")

::method phasePath
  use arg transactionId, phase
  return self~directory || "/" || transactionId || "." || .QueueTransitionPhase~name(phase) || ".json"

::method phaseExists
  use arg transactionId, phase
  return SysFileExists(self~phasePath(transactionId, phase)) == 1

::method writePhase
  expose fileSystem
  use arg transactionId, phase, data
  dir = self~directory
  if \fileSystem~ensureDirectory(dir) then return .false
  path = self~phasePath(transactionId, phase)
  if SysFileExists(path) then return .false
  temp = path || ".tmp." || random(0,999999)~right(6,"0")
  doc = .Directory~new
  doc["schema"] = .QueueTransitionSchema~JOURNAL
  doc["transaction_id"] = transactionId
  doc["phase"] = .QueueTransitionPhase~name(phase)
  doc["recorded_at"] = .QueueKernelTime~nowIso
  doc["transition"] = data
  .QueueSerialization~toJsonFile(doc, temp)
  if \SysFileExists(temp) then return .false
  if SysFileMove(temp, path) \= 0 then do
    call SysFileDelete temp
    return .false
  end
  fileSystem~ensureOwnerLike(dir, root)
  fileSystem~ensureOwnerLike(path, root)
  return .true

::method preparedDocuments
  dir = self~directory
  arr = .Array~new
  if \SysFileExists(dir) then return arr
  drop files.
  call SysFileTree dir || "/*.prepared.json", "files.", "FO"
  do i = 1 to files.0
    doc = self~readDocument(files.i)
    if doc \= .nil then arr~append(doc)
  end
  return arr

::method readDocument private
  use arg path
  signal on syntax name badDoc
  doc = .QueueSerialization~fromJsonFile(path)
  signal off syntax
  return doc
badDoc:
  signal off syntax
  return .nil

::class QueueTransitionReceipt public
::attribute status get
::attribute qid get
::attribute fromState get
::attribute toState get
::attribute transactionId get
::attribute sourcePath get
::attribute destinationPath get
::attribute eventCommitted get
::attribute detail get
::method init
  expose status qid fromState toState transactionId sourcePath destinationPath eventCommitted detail
  use arg statusArg, qidArg, fromArg, toArg, transactionArg = "", sourceArg = "", destinationArg = "", eventCommittedArg = .false, detailArg = ""
  status = statusArg + 0; qid = qidArg~string; fromState = fromArg + 0; toState = toArg + 0; transactionId = transactionArg~string
  sourcePath = sourceArg~string; destinationPath = destinationArg~string; eventCommitted = eventCommittedArg; detail = detailArg~string
::method ok
  expose status
  return status == .QueueMutationStatus~OK | status == .QueueMutationStatus~RECOVERED
::method asDirectory
  expose status qid fromState toState transactionId sourcePath destinationPath eventCommitted detail
  d = .Directory~new
  d["schema"] = .QueueTransitionSchema~RECEIPT
  d["status"] = .QueueMutationStatus~name(status)
  d["status_code"] = status
  d["qid"] = qid
  d["from_state"] = .QueueState~name(fromState)
  d["to_state"] = .QueueState~name(toState)
  d["transaction_id"] = transactionId
  d["source_path"] = sourcePath
  d["destination_path"] = destinationPath
  d["event_committed"] = .QueueRexxUtil~jsonBoolean(eventCommitted)
  d["detail"] = detail
  return d

::class QueueTransitionService public
::attribute root get
::attribute store get
::attribute fileSystem get
::attribute lockManager get
::attribute journal get
::attribute eventBus get
::method init
  expose root store fileSystem lockManager journal eventBus
  use arg rootArg, fileSystemArg = .nil, lockManagerArg = .nil, journalArg = .nil, eventBusArg = .nil
  root = rootArg~string
  store = .QueueStateStore~new(root)
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, fileSystem)
  else lockManager = lockManagerArg
  if journalArg == .nil then journal = .QueueTransitionJournal~new(root, fileSystem)
  else journal = journalArg
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(root, fileSystem))
  end
  else eventBus = eventBusArg

::method transition
  expose lockManager
  use arg qidArg, fromStateArg, toStateArg, eventTypeArg = .nil, actorArg = .nil, timeoutArg = .nil
  qid = qidArg~string
  fromState = .QueueState~coerce(fromStateArg)
  toState = .QueueState~coerce(toStateArg)
  if actorArg == .nil then actor = .QueueLockActor~TRANSITION
  else actor = actorArg~string
  lockResult = lockManager~acquireDetailed(qid, actor, timeoutArg)
  if \lockResult~acquired then do
    if lockResult~status == .QueueLockAcquireStatus~PERMISSION_DENIED then return .QueueTransitionReceipt~new(.QueueMutationStatus~LOCK_PERMISSION_DENIED, qid, fromState, toState, "", "", "", .false, lockResult~detail)
    return .QueueTransitionReceipt~new(.QueueMutationStatus~LOCK_TIMEOUT, qid, fromState, toState, "", "", "", .false, lockResult~detail)
  end
  lock = lockResult~handle
  receipt = self~transitionWithLock(lock, qid, fromState, toState, eventTypeArg, actor)
  lock~release
  return receipt

/* Execute a transition while the caller already owns the ordinary per-QID
 * QueueBash-compatible state lock.  This exists for composed authorities such
 * as WLU terminal settlement: they can persist their own intent, perform the
 * queue transition, and settle the external authority without opening a race
 * between those steps.  The caller, not this method, releases the lock. */
::method transitionWithLock
  expose root store fileSystem journal eventBus
  use strict arg lock, qidArg, fromStateArg, toStateArg, eventTypeArg = .nil, actorArg = (.QueueLockActor~TRANSITION)
  qid = qidArg~string
  fromState = .QueueState~coerce(fromStateArg)
  toState = .QueueState~coerce(toStateArg)
  actor = actorArg~string
  if lock == .nil | \lock~isA(.QueueStateLockHandle) | \lock~owned | lock~qid \= qid then return .QueueTransitionReceipt~new(.QueueMutationStatus~LOCK_TIMEOUT, qid, fromState, toState, "", "", "", .false, "caller does not own matching QID lock")

  matches = store~findAll(qid)
  if matches~items == 0 then return .QueueTransitionReceipt~new(.QueueMutationStatus~SOURCE_NOT_FOUND, qid, fromState, toState)
  if matches~items > 1 then return .QueueTransitionReceipt~new(.QueueMutationStatus~DUPLICATE_STATE, qid, fromState, toState, "", "", "", .false, "QID exists in multiple states")
  source = matches[1]
  if source~state \= fromState then return .QueueTransitionReceipt~new(.QueueMutationStatus~SOURCE_NOT_FOUND, qid, fromState, toState, "", source~path, "", .false, "source state changed")
  if toState == .QueueState~PENDING then destination = .QueuePendingPath~path(root, qid, source~priority)
  else if toState == .QueueState~WAITING then destination = .QueueWaitingPath~path(root, qid, source~priority)
  else destination = root || "/" || .QueueState~name(toState) || "/" || qid || ".job"
  destinationDir = destination~left(destination~lastpos("/") - 1)
  if \fileSystem~ensureDirectory(destinationDir) then return .QueueTransitionReceipt~new(.QueueMutationStatus~IO_ERROR, qid, fromState, toState, "", source~path, destination, .false, "destination directory unavailable")
  if fileSystem~exists(destination) then return .QueueTransitionReceipt~new(.QueueMutationStatus~DESTINATION_EXISTS, qid, fromState, toState, "", source~path, destination)

  txid = journal~newTransactionId(qid)
  tdata = self~transitionData(qid, fromState, toState, source~path, destination, actor, eventTypeArg)
  if \journal~writePhase(txid, .QueueTransitionPhase~PREPARED, tdata) then return .QueueTransitionReceipt~new(.QueueMutationStatus~IO_ERROR, qid, fromState, toState, txid, source~path, destination, .false, "unable to persist transition intent")
  if \fileSystem~move(source~path, destination) then do
    journal~writePhase(txid, .QueueTransitionPhase~ABORTED, tdata)
    return .QueueTransitionReceipt~new(.QueueMutationStatus~IO_ERROR, qid, fromState, toState, txid, source~path, destination, .false, "atomic move failed")
  end
  journalCommitted = journal~writePhase(txid, .QueueTransitionPhase~COMMITTED, tdata)
  eventCommitted = .false
  if eventTypeArg \= .nil & eventTypeArg~string \= "" then do
    event = self~transitionEvent(txid, qid, fromState, toState, eventTypeArg~string)
    eventCommitted = eventBus~publishChecked(event)
    if eventCommitted then journal~writePhase(txid, .QueueTransitionPhase~EVENT_RECORDED, tdata)
  end
  detail = ""
  if \journalCommitted then detail = "filesystem transition committed; committed journal marker pending recovery"
  if eventTypeArg \= .nil & eventTypeArg~string \= "" & \eventCommitted then do
    if detail \= "" then detail ||= "; "
    detail ||= "event append pending recovery"
  end
  return .QueueTransitionReceipt~new(.QueueMutationStatus~OK, qid, fromState, toState, txid, source~path, destination, eventCommitted, detail)

::method transitionEvent private
  use arg txid, qid, fromState, toState, eventType
  evdata = .Directory~new
  evdata["detail"] = "queuerexx transition " || .QueueState~name(fromState) || "->" || .QueueState~name(toState) || " transaction=" || txid
  return .QueueEvent~new(txid, eventType, qid, .QueueState~name(toState), .QueueKernelTime~nowIso, evdata)

::method transitionData private
  use arg qid, fromState, toState, sourcePath, destinationPath, actor, eventTypeArg
  d = .Directory~new
  d["qid"] = qid
  d["from_state"] = .QueueState~name(fromState)
  d["to_state"] = .QueueState~name(toState)
  d["source_path"] = sourcePath
  d["destination_path"] = destinationPath
  d["actor"] = actor
  if eventTypeArg == .nil then d["event_type"] = ""
  else d["event_type"] = eventTypeArg~string
  return d

::class QueueTransitionRecovery public
::attribute root get
::attribute fileSystem get
::attribute lockManager get
::attribute journal get
::attribute eventBus get
::method init
  expose root fileSystem lockManager journal eventBus
  use arg rootArg, fileSystemArg = .nil, lockManagerArg = .nil, journalArg = .nil, eventBusArg = .nil
  root = rootArg~string
  if fileSystemArg == .nil then fileSystem = .QueuePosixAtomicFileSystem~new
  else fileSystem = fileSystemArg
  if lockManagerArg == .nil then lockManager = .QueueStateLockManager~new(root, fileSystem)
  else lockManager = lockManagerArg
  if journalArg == .nil then journal = .QueueTransitionJournal~new(root, fileSystem)
  else journal = journalArg
  if eventBusArg == .nil then do
    eventBus = .QueueEventBus~new
    eventBus~addSink(.QueueBashEventLog~new(root, fileSystem))
  end
  else eventBus = eventBusArg

::method recover
  expose root fileSystem lockManager journal eventBus
  outcomes = .Array~new
  eventLog = .QueueBashEventLog~new(root, fileSystem)
  do doc over journal~preparedDocuments
    txid = doc["transaction_id"]~string
    t = doc["transition"]
    qid = t["qid"]~string
    fromState = .QueueState~fromName(t["from_state"])
    toState = .QueueState~fromName(t["to_state"])
    source = t["source_path"]~string
    destination = t["destination_path"]~string
    eventType = t["event_type"]~string

    aborted = journal~phaseExists(txid, .QueueTransitionPhase~ABORTED)
    ambiguous = journal~phaseExists(txid, .QueueTransitionPhase~AMBIGUOUS)
    committed = journal~phaseExists(txid, .QueueTransitionPhase~COMMITTED)
    recovered = journal~phaseExists(txid, .QueueTransitionPhase~RECOVERED)
    eventRecorded = journal~phaseExists(txid, .QueueTransitionPhase~EVENT_RECORDED)
    if aborted | ambiguous then iterate
    if (committed | recovered) & (eventType == "" | eventRecorded) then iterate

    lock = lockManager~acquire(qid, .QueueLockActor~RECOVERY, 0)
    if lock == .nil then iterate
    sourceExists = fileSystem~exists(source)
    destinationExists = fileSystem~exists(destination)

    if destinationExists & \sourceExists then do
      if \committed & \recovered then journal~writePhase(txid, .QueueTransitionPhase~RECOVERED, t)
      eventCommitted = (eventType == "")
      if eventType \= "" then do
        if eventLog~containsTransaction(txid) then eventCommitted = .true
        else do
          event = self~transitionEvent(txid, qid, fromState, toState, eventType)
          eventCommitted = eventBus~publishChecked(event)
        end
        if eventCommitted & \journal~phaseExists(txid, .QueueTransitionPhase~EVENT_RECORDED) then journal~writePhase(txid, .QueueTransitionPhase~EVENT_RECORDED, t)
      end
      outcomes~append(.QueueTransitionReceipt~new(.QueueMutationStatus~RECOVERED, qid, fromState, toState, txid, source, destination, eventCommitted, "destination proves transition committed"))
    end
    else if sourceExists & \destinationExists then do
      /* A committed/event marker contradicting source-only filesystem evidence is
       * not silently downgraded to aborted.  Preserve the conflict for review. */
      if committed | recovered | eventRecorded | eventLog~containsTransaction(txid) then do
        journal~writePhase(txid, .QueueTransitionPhase~AMBIGUOUS, t)
        outcomes~append(.QueueTransitionReceipt~new(.QueueMutationStatus~AMBIGUOUS, qid, fromState, toState, txid, source, destination, .false, "journal/event evidence conflicts with source-only filesystem state"))
      end
      else do
        journal~writePhase(txid, .QueueTransitionPhase~ABORTED, t)
        outcomes~append(.QueueTransitionReceipt~new(.QueueMutationStatus~ABORTED, qid, fromState, toState, txid, source, destination, .false, "source proves transition did not commit"))
      end
    end
    else do
      if \ambiguous then journal~writePhase(txid, .QueueTransitionPhase~AMBIGUOUS, t)
      outcomes~append(.QueueTransitionReceipt~new(.QueueMutationStatus~AMBIGUOUS, qid, fromState, toState, txid, source, destination, .false, "source/destination evidence is ambiguous"))
    end
    lock~release
  end
  return outcomes

::method transitionEvent private
  use arg txid, qid, fromState, toState, eventType
  evdata = .Directory~new
  evdata["detail"] = "queuerexx transition " || .QueueState~name(fromState) || "->" || .QueueState~name(toState) || " transaction=" || txid
  return .QueueEvent~new(txid, eventType, qid, .QueueState~name(toState), .QueueKernelTime~nowIso, evdata)

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"
::requires "QueueRexxEvents.cls"
::requires "QueueRexxSerialization.cls"

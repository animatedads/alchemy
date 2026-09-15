/* QueueRexxProviders.cls - registered capability providers, v0.1-dev6 */

::class QueueProviderCategory public
::constant RUNNER "runner"
::constant PLATFORM_FACT "platform_fact"
::constant ASSET "asset"
::constant ISOLATION "isolation"
::constant RESOURCE_CONTROL "resource_control"
::constant RUNTIME_GUARD "runtime_guard"
::constant PROCESS_OBSERVATION "process_observation"
::constant POLICY "policy"
::constant PLACEMENT "placement"
::constant SERVICE_FACT "service_fact"
::method values class
  return .Array~of(self~RUNNER, self~PLATFORM_FACT, self~ASSET, self~ISOLATION, self~RESOURCE_CONTROL, self~RUNTIME_GUARD, self~PROCESS_OBSERVATION, self~POLICY, self~PLACEMENT, self~SERVICE_FACT)

::class QueueProviderHealthState public
::constant HEALTHY 1
::constant DEGRADED 2
::constant UNAVAILABLE 3
::constant UNKNOWN 4
::constant NAME_HEALTHY "healthy"
::constant NAME_DEGRADED "degraded"
::constant NAME_UNAVAILABLE "unavailable"
::constant NAME_UNKNOWN "unknown"
::method name class
  use strict arg value
  select
    when value == self~HEALTHY then return self~NAME_HEALTHY
    when value == self~DEGRADED then return self~NAME_DEGRADED
    when value == self~UNAVAILABLE then return self~NAME_UNAVAILABLE
    otherwise return self~NAME_UNKNOWN
  end
::method severity class
  use strict arg value
  select
    when value == self~HEALTHY then return 0
    when value == self~DEGRADED then return 1
    when value == self~UNKNOWN then return 2
    when value == self~UNAVAILABLE then return 3
    otherwise return 2
  end

::class QueueProviderHealthReport public
::attribute category get
::attribute providerId get
::attribute version get
::attribute state get
::attribute code get
::attribute detail get
::attribute capabilities get
::attribute evidence get
::attribute capturedAt get
::method init
  expose category providerId version state code detail capabilities evidence capturedAt
  use arg categoryArg, providerArg, versionArg, stateArg, codeArg = "", detailArg = "", capabilitiesArg = .nil, evidenceArg = .nil, capturedArg = ""
  category = categoryArg~string; providerId = providerArg~string; version = versionArg~string
  state = stateArg + 0; code = codeArg~string; detail = detailArg~string
  if capabilitiesArg == .nil then capabilities = .Array~new; else capabilities = capabilitiesArg
  if evidenceArg == .nil then evidence = .Directory~new; else evidence = evidenceArg
  if capturedArg == "" then capturedAt = .DateTime~new~string; else capturedAt = capturedArg~string
::method asDirectory
  expose category providerId version state code detail capabilities evidence capturedAt
  d = .Directory~new
  d["category"] = category
  d["provider"] = providerId
  d["version"] = version
  d["state"] = .QueueProviderHealthState~name(state)
  d["state_code"] = state
  d["code"] = code
  d["detail"] = detail
  d["capabilities"] = capabilities
  d["evidence"] = evidence
  d["captured_at"] = capturedAt
  return d


::class QueueProviderSupport public
::constant CODE_SUPPORTED "SUPPORTED"
::attribute supported get
::attribute code get
::attribute detail get
::method init
  expose supported code detail
  use arg supportedArg, codeArg = "", detailArg = ""
  supported = supportedArg
  code = codeArg~string
  detail = detailArg~string
::method yes class
  use arg codeArg = .nil, detailArg = ""
  if codeArg == .nil then codeArg = self~CODE_SUPPORTED
  return self~new(.true, codeArg, detailArg)
::method no class
  use arg codeArg, detailArg = ""
  return self~new(.false, codeArg, detailArg)
::method asDirectory
  expose supported code detail
  d = .Directory~new
  d["supported"] = .QueueRexxUtil~jsonBoolean(supported)
  d["code"] = code
  d["detail"] = detail
  return d

::class QueueProviderOperationResult public
::constant READ_ONLY "READ_ONLY"
::constant OPERATION_OK "OPERATION_OK"
::constant OPERATION_FAILED "OPERATION_FAILED"
::attribute ok get
::attribute code get
::attribute detail get
::attribute data get
::method init
  expose ok code detail data
  use arg okArg, codeArg, detailArg = "", dataArg = .nil
  ok = okArg; code = codeArg~string; detail = detailArg~string; data = dataArg
::method success class
  use arg dataArg = .nil, codeArg = .nil, detailArg = ""
  if codeArg == .nil then codeArg = self~OPERATION_OK
  return self~new(.true, codeArg, detailArg, dataArg)
::method failure class
  use arg codeArg = .nil, detailArg = "", dataArg = .nil
  if codeArg == .nil then codeArg = self~OPERATION_FAILED
  return self~new(.false, codeArg, detailArg, dataArg)
::method unavailable class
  use arg detailArg = "provider operation is disabled"
  return self~new(.false, self~READ_ONLY, detailArg, .nil)

/* Internal observation values are constants, not comparison strings. */
::class QueueJobObservation public
::constant LIVE 1
::constant DEAD 2
::constant UNKNOWN 3
::constant LAUNCH_PENDING 4
::constant NOT_APPLICABLE 5
::constant LABEL_LIVE "live"
::constant LABEL_DEAD "dead"
::constant LABEL_UNKNOWN "unknown"
::constant LABEL_LAUNCH_PENDING "launch_pending"
::constant LABEL_NOT_APPLICABLE "not_applicable"
::attribute status get
::attribute providerId get
::attribute code get
::attribute detail get
::attribute evidence get
::method init
  expose status providerId code detail evidence
  use arg statusArg, providerArg, codeArg = "", detailArg = "", evidenceArg = .nil
  status = statusArg + 0
  providerId = providerArg~string
  code = codeArg~string
  detail = detailArg~string
  if evidenceArg == .nil then evidence = .Directory~new; else evidence = evidenceArg
::method label class
  use arg statusArg
  select
    when statusArg == self~LIVE then return self~LABEL_LIVE
    when statusArg == self~DEAD then return self~LABEL_DEAD
    when statusArg == self~UNKNOWN then return self~LABEL_UNKNOWN
    when statusArg == self~LAUNCH_PENDING then return self~LABEL_LAUNCH_PENDING
    when statusArg == self~NOT_APPLICABLE then return self~LABEL_NOT_APPLICABLE
    otherwise return self~LABEL_UNKNOWN
  end
::method statusName
  expose status
  return .QueueJobObservation~label(status)
::method isLive
  expose status
  return status == .QueueJobObservation~LIVE
::method isDead
  expose status
  return status == .QueueJobObservation~DEAD
::method isDeferred
  expose status
  return status == .QueueJobObservation~UNKNOWN | status == .QueueJobObservation~LAUNCH_PENDING
::method asDirectory
  expose status providerId code detail evidence
  d = .Directory~new
  d["status"] = .QueueJobObservation~label(status)
  d["status_code"] = status
  d["provider"] = providerId
  d["code"] = code
  d["detail"] = detail
  d["evidence"] = evidence
  return d

::class QueueCommandResult public
::attribute rc get
::attribute output get
::attribute error get
::method init
  expose rc output error
  use arg rcArg, outputArg = .nil, errorArg = .nil
  rc = rcArg + 0
  if outputArg == .nil then output = .Array~new; else output = outputArg
  if errorArg == .nil then error = .Array~new; else error = errorArg

::class QueueCommandExecutor public
::method run abstract

::class QueueSystemCommandExecutor public subclass QueueCommandExecutor
::method run
  use arg command
  out = .Array~new
  err = .Array~new
  address system command with output using (out) error using (err)
  commandRc = rc
  return .QueueCommandResult~new(commandRc, out, err)

::class QueueDetachedCommandExecutor public
::method run abstract

::class QueueSystemDetachedCommandExecutor public subclass QueueDetachedCommandExecutor
::method run
  use arg command
  address system command
  commandRc = rc
  return .QueueCommandResult~new(commandRc)

::class QueuePosixShell public
::method quote class
  use arg valueArg
  value = valueArg~string
  sq = "'"
  dq = '"'
  replacement = sq || dq || sq || dq || sq
  return sq || value~changestr(sq, replacement) || sq

::class QueueClock public
::method now abstract

::class QueueSystemClock public subclass QueueClock
::method now
  return .DateTime~new

::class QueueProcessProbe public
::method pidAlive abstract
::method pgidAlive abstract

::class QueueLinuxProcessProbe public subclass QueueProcessProbe
::attribute executor get
::method init
  expose executor
  use arg executorArg = .nil
  if executorArg == .nil then executor = .QueueSystemCommandExecutor~new; else executor = executorArg
::method pidAlive
  expose executor
  use arg pidArg
  pid = pidArg~string
  if \pid~datatype("W") | pid + 0 <= 0 then return .false
  r = executor~run("ps -o stat= -p " || pid || " 2>/dev/null")
  if r~rc \= 0 then return .false
  do line over r~output
    stat = line~strip
    if stat \= "" & stat~left(1) \= "Z" then return .true
  end
  return .false
::method pgidAlive
  expose executor
  use arg pgidArg
  pgid = pgidArg~string
  if \pgid~datatype("W") | pgid + 0 <= 0 then return .false
  r = executor~run("ps -o stat= -g " || pgid || " 2>/dev/null")
  if r~rc \= 0 then return .false
  do line over r~output
    stat = line~strip
    if stat \= "" & stat~left(1) \= "Z" then return .true
  end
  return .false

::class QueueSystemdProperty public
::constant ACTIVE_STATE "ACTIVESTATE"
::constant SUB_STATE "SUBSTATE"
::constant MAIN_PID "MAINPID"

::class QueueSystemdState public
::constant ACTIVE "active"
::constant ACTIVATING "activating"
::constant RELOADING "reloading"
::constant INACTIVE "inactive"
::constant FAILED "failed"
::constant NOT_FOUND "not-found"
::constant RUNNING "running"
::constant START "start"
::constant AUTO_RESTART "auto-restart"
::constant DEAD "dead"
::constant EXITED "exited"

::class QueueSystemdStatus public
::attribute known get
::attribute activeState get
::attribute subState get
::attribute mainPid get
::method init
  expose known activeState subState mainPid
  use arg knownArg = .false, activeArg = "", subArg = "", mainPidArg = ""
  known = knownArg
  activeState = activeArg~string~lower
  subState = subArg~string~lower
  mainPid = mainPidArg~string
::method asDirectory
  expose known activeState subState mainPid
  d = .Directory~new
  d["known"] = .QueueRexxUtil~jsonBoolean(known)
  d["active_state"] = activeState
  d["sub_state"] = subState
  d["main_pid"] = mainPid
  return d

::class QueueSystemdProbe public
::method status abstract

::class QueueSystemdUserProbe public subclass QueueSystemdProbe
::attribute executor get
::method init
  expose executor
  use arg executorArg = .nil
  if executorArg == .nil then executor = .QueueSystemCommandExecutor~new; else executor = executorArg
::method status
  expose executor
  use arg unitArg
  unit = .QueueRexxUtil~cleanSystemdUnit(unitArg)
  if unit == "" then return .QueueSystemdStatus~new
  activeState = ""
  subState = ""
  mainPid = ""
  command = "systemctl --user show " || .QueuePosixShell~quote(unit) || " -p ActiveState -p SubState -p MainPID --no-pager"
  r = executor~run(command)
  do line over r~output
    p = line~pos("=")
    if p <= 1 then iterate
    key = line~left(p - 1)~upper
    value = line~substr(p + 1)~strip
    select
      when key == .QueueSystemdProperty~ACTIVE_STATE then activeState = value
      when key == .QueueSystemdProperty~SUB_STATE then subState = value
      when key == .QueueSystemdProperty~MAIN_PID then mainPid = value
      otherwise nop
    end
  end
  known = activeState \= "" | subState \= "" | mainPid \= ""
  return .QueueSystemdStatus~new(known, activeState, subState, mainPid)

::class QueueRunnerProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method score abstract
::method prepare abstract
::method launch abstract
::method observe abstract
::method terminate abstract
::method explain abstract

/* Capability contracts preserve QueueBash feature families without giving
 * providers authority over QueueBash filesystem transitions. */
::class QueuePlatformFactProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method probe abstract

::class QueueAssetProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method assess abstract
::method explain abstract

::class QueueIsolationProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method prepare abstract
::method explain abstract

::class QueueResourceControlProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method prepare abstract
::method observe abstract
::method explain abstract

::class QueueRuntimeGuardProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method arm abstract
::method observe abstract
::method disarm abstract
::method explain abstract

::class QueueProcessObservationProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method observe abstract

::class QueuePolicyProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method assess abstract
::method explain abstract

::class QueuePlacementProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method supports abstract
::method select abstract
::method explain abstract

::class QueueServiceFactProvider public
::method id abstract
::method version abstract
::method capabilities abstract
::method probe abstract
::method explain abstract

/* Launch mechanics are objects as well.  The execution service owns queue
 * lifecycle authority; runner backends own only platform process mechanics. */
::class QueueRunnerLaunchContext public
::attribute record get
::attribute root get
::attribute executionId get
::attribute logPath get
::attribute pidPath get
::attribute exitPath get
::attribute unitName get
::attribute startedAt get
::method init
  expose record root executionId logPath pidPath exitPath unitName startedAt
  use strict arg recordArg, rootArg, executionIdArg, logPathArg, pidPathArg, exitPathArg, unitArg = "", startedAtArg = ""
  record = recordArg; root = rootArg~string; executionId = executionIdArg~string
  logPath = logPathArg~string; pidPath = pidPathArg~string; exitPath = exitPathArg~string
  unitName = unitArg~string; startedAt = startedAtArg~string
::method command
  expose record
  return record~arrayField(.QueueRecord~FIELD_COMMAND)
::method cwd
  expose record
  return record~field(.QueueRecord~FIELD_PWD_AT_SUBMIT, directory())
::method runUser
  expose record
  return record~field(.QueueRecord~FIELD_RUN_USER, "")

::class QueueRunnerLaunchHandle public
::attribute providerId get
::attribute executionId get
::attribute pid get
::attribute pgid get
::attribute systemdUnit get
::attribute startedAt get
::attribute pidPath get
::attribute exitPath get
::method init
  expose providerId executionId pid pgid systemdUnit startedAt pidPath exitPath
  use strict arg providerArg, executionIdArg, pidArg = "", pgidArg = "", unitArg = "", startedAtArg = "", pidPathArg = "", exitPathArg = ""
  providerId = providerArg~string; executionId = executionIdArg~string
  pid = pidArg~string; pgid = pgidArg~string; systemdUnit = unitArg~string
  startedAt = startedAtArg~string; pidPath = pidPathArg~string; exitPath = exitPathArg~string
::method asDirectory
  expose providerId executionId pid pgid systemdUnit startedAt pidPath exitPath
  d = .Directory~new
  d["provider"] = providerId
  d["execution_id"] = executionId
  d["pid"] = pid
  d["pgid"] = pgid
  d["systemd_unit"] = systemdUnit
  d["started_at"] = startedAt
  d["pid_file"] = pidPath
  d["exit_file"] = exitPath
  return d

::class QueueRunnerBackend public
::method launchDirect abstract
::method launchSystemd abstract
::method terminateDirect abstract
::method terminateSystemd abstract

::class QueuePosixRunnerBackend public subclass QueueRunnerBackend
::constant CODE_DIRECT_STARTED "DIRECT_STARTED"
::constant CODE_SYSTEMD_STARTED "SYSTEMD_STARTED"
::constant CODE_LAUNCH_FAILED "LAUNCH_FAILED"
::constant CODE_TERMINATED "TERMINATED"
::constant CODE_TERMINATE_FAILED "TERMINATE_FAILED"
::attribute executor get
::attribute detachedExecutor get
::method init
  expose executor detachedExecutor
  use arg executorArg = .nil, detachedExecutorArg = .nil
  if executorArg == .nil then executor = .QueueSystemCommandExecutor~new; else executor = executorArg
  if detachedExecutorArg == .nil then detachedExecutor = .QueueSystemDetachedCommandExecutor~new; else detachedExecutor = detachedExecutorArg
::method commandString private
  use strict arg commandArray
  out = ""
  do a over commandArray
    if out \= "" then out ||= " "
    out ||= .QueuePosixShell~quote(a)
  end
  return out
::method wrapperBody private
  use strict arg context
  command = self~commandString(context~command)
  if command == "" then return ""
  dq = '22'x
  exitTemp = context~exitPath || ".tmp.$$"
  body = "cd -- " || .QueuePosixShell~quote(context~cwd) || " || exit 98; "
  body ||= command || "; qrx_rc=$?; "
  body ||= "printf '%s\n' " || dq || "$qrx_rc" || dq || " > " || .QueuePosixShell~quote(exitTemp) || "; "
  body ||= "mv -f -- " || .QueuePosixShell~quote(exitTemp) || " " || .QueuePosixShell~quote(context~exitPath) || "; exit " || dq || "$qrx_rc" || dq
  return body
::method launchDirect
  expose detachedExecutor
  use strict arg context
  body = self~wrapperBody(context)
  if body == "" then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "empty payload command")
  dq = '22'x
  prefix = ""
  runUser = context~runUser
  if runUser \= "" & runUser \= .QueueRexxUtil~currentUser then prefix = "runuser -u " || .QueuePosixShell~quote(runUser) || " -- "
  pidTemp = context~pidPath || ".tmp.$$"
  launch = "umask 077; if command -v setsid >/dev/null 2>&1; then "
  launch ||= prefix || "setsid -- /bin/sh -c " || .QueuePosixShell~quote(body)
  launch ||= " </dev/null >>" || .QueuePosixShell~quote(context~logPath) || " 2>&1 & else "
  launch ||= prefix || "/bin/sh -c " || .QueuePosixShell~quote(body)
  launch ||= " </dev/null >>" || .QueuePosixShell~quote(context~logPath) || " 2>&1 & fi; "
  launch ||= "qrx_pid=$!; qrx_pgid=$(ps -o pgid= -p " || dq || "$qrx_pid" || dq || " 2>/dev/null | tr -d '[:space:]'); "
  launch ||= "printf '%s\n%s\n' " || dq || "$qrx_pid" || dq || " " || dq || "$qrx_pgid" || dq || " > " || .QueuePosixShell~quote(pidTemp) || "; "
  launch ||= "mv -f -- " || .QueuePosixShell~quote(pidTemp) || " " || .QueuePosixShell~quote(context~pidPath)
  r = detachedExecutor~run(launch)
  if r~rc \= 0 | \SysFileExists(context~pidPath) then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "POSIX direct launch failed rc=" || r~rc)
  s = .Stream~new(context~pidPath)
  if s~open("READ") \= "READY:" then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "unable to read durable PID locator")
  pid = s~lineIn~strip
  pgid = ""; if s~lines > 0 then pgid = s~lineIn~strip
  s~close
  if \pid~datatype("W") | pid + 0 <= 0 then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "launcher did not return a valid PID")
  h = .QueueRunnerLaunchHandle~new(.QueueRunnerKind~DIRECT, context~executionId, pid, pgid, "", context~startedAt, context~pidPath, context~exitPath)
  return .QueueProviderOperationResult~success(h, self~CODE_DIRECT_STARTED)
::method launchSystemd
  expose executor
  use strict arg context
  body = self~wrapperBody(context)
  if body == "" then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "empty payload command")
  unit = context~unitName
  if unit == "" then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "systemd launch requires a deterministic unit name")
  command = "systemd-run --user --collect --unit=" || .QueuePosixShell~quote(unit)
  command ||= " --working-directory=" || .QueuePosixShell~quote(context~cwd)
  command ||= " -p " || .QueuePosixShell~quote("StandardOutput=append:" || context~logPath)
  command ||= " -p " || .QueuePosixShell~quote("StandardError=append:" || context~logPath)
  command ||= " -- /bin/sh -c " || .QueuePosixShell~quote(body)
  r = executor~run(command)
  if r~rc \= 0 then return .QueueProviderOperationResult~failure(self~CODE_LAUNCH_FAILED, "systemd-run failed rc=" || r~rc)
  h = .QueueRunnerLaunchHandle~new(.QueueRunnerKind~SYSTEMD, context~executionId, "", "", unit, context~startedAt, context~pidPath, context~exitPath)
  return .QueueProviderOperationResult~success(h, self~CODE_SYSTEMD_STARTED)
::method terminateDirect
  expose executor
  use strict arg record
  pgid = record~field(.QueueRecord~FIELD_RUN_PGID, "")
  pid = record~field(.QueueRecord~FIELD_RUN_PID, "")
  if pgid~datatype("W") & pgid + 0 > 0 then command = "kill -TERM -" || pgid || " >/dev/null 2>&1"
  else if pid~datatype("W") & pid + 0 > 0 then command = "kill -TERM " || pid || " >/dev/null 2>&1"
  else return .QueueProviderOperationResult~failure(self~CODE_TERMINATE_FAILED, "no safe direct PID/PGID target")
  r = executor~run(command)
  if r~rc == 0 then return .QueueProviderOperationResult~success(.nil, self~CODE_TERMINATED)
  return .QueueProviderOperationResult~failure(self~CODE_TERMINATE_FAILED, "kill failed rc=" || r~rc)
::method terminateSystemd
  expose executor
  use strict arg record
  unit = record~systemdUnit
  if unit == "" then return .QueueProviderOperationResult~failure(self~CODE_TERMINATE_FAILED, "no SYSTEMD_UNIT")
  r = executor~run("systemctl --user stop " || .QueuePosixShell~quote(unit) || " >/dev/null 2>&1")
  if r~rc == 0 then return .QueueProviderOperationResult~success(.nil, self~CODE_TERMINATED)
  return .QueueProviderOperationResult~failure(self~CODE_TERMINATE_FAILED, "systemctl stop failed rc=" || r~rc)

::class DirectRunnerProvider public subclass QueueRunnerProvider
::constant PROVIDER_ID "direct"
::constant PROVIDER_VERSION "queuebash-0.18.144-compatible"
::constant CODE_PID_LIVE "DIRECT_PID_LIVE"
::constant CODE_PGID_LIVE "DIRECT_PGID_LIVE"
::constant CODE_PROCESS_DEAD "DIRECT_PROCESS_DEAD"
::constant CODE_LAUNCH_PENDING "DIRECT_LAUNCH_PENDING"
::constant CODE_LAUNCH_METADATA_UNKNOWN "DIRECT_LAUNCH_METADATA_UNKNOWN"
::attribute processProbe get
::attribute clock get
::attribute launchGraceSeconds get
::attribute backend get
::method init
  expose processProbe clock launchGraceSeconds backend
  use arg processProbeArg = .nil, clockArg = .nil, graceArg = .nil, backendArg = .nil
  if processProbeArg == .nil then processProbe = .QueueLinuxProcessProbe~new; else processProbe = processProbeArg
  if clockArg == .nil then clock = .QueueSystemClock~new; else clock = clockArg
  if graceArg == .nil then do
    envGrace = value("QUEUEBASH_LAUNCH_METADATA_GRACE",, "ENVIRONMENT")
    if envGrace~datatype("W") then launchGraceSeconds = envGrace + 0; else launchGraceSeconds = 300
  end
  else launchGraceSeconds = graceArg + 0
  if backendArg == .nil then backend = .QueuePosixRunnerBackend~new; else backend = backendArg
::method id
  return self~PROVIDER_ID
::method version
  return self~PROVIDER_VERSION
::method capabilities
  return .Array~of("local-process", "pid", "pgid", "foreign-user-via-operator")
::method supports
  use arg platformFacts, jobRequirement
  if platformFacts~osFamily \= .QueuePlatformFacts~OS_LINUX then return .QueueProviderSupport~no("DIRECT_PLATFORM_UNSUPPORTED", platformFacts~osFamily)
  return .QueueProviderSupport~yes("DIRECT_SUPPORTED")
::method score
  use arg platformFacts, jobRequirement
  requested = jobRequirement~requestedRunner
  if requested == .QueueRunnerKind~DIRECT then return 10000
  if platformFacts~rootLaunchingForeignUser(jobRequirement~runUser) then return 1000
  return 100
::method prepare
  use strict arg context
  if context == .nil | context~command~items == 0 then return .QueueProviderOperationResult~failure("DIRECT_PREPARE_INVALID", "missing payload command")
  return .QueueProviderOperationResult~success(.nil, "DIRECT_PREPARED")
::method launch
  expose backend
  use strict arg context
  return backend~launchDirect(context)
::method observe
  expose processProbe clock launchGraceSeconds
  use arg record
  if record~state \= .QueueState~RUNNING then return .QueueJobObservation~new(.QueueJobObservation~NOT_APPLICABLE, self~PROVIDER_ID, "NOT_RUNNING_STATE")
  pid = record~field(.QueueRecord~FIELD_RUN_PID, "")
  pgid = record~field(.QueueRecord~FIELD_RUN_PGID, "")
  evidence = .Directory~new
  evidence["run_pid"] = pid
  evidence["run_pgid"] = pgid
  if pid~datatype("W") then do
    if pid + 0 > 0 then do
      if processProbe~pidAlive(pid) then return .QueueJobObservation~new(.QueueJobObservation~LIVE, self~PROVIDER_ID, self~CODE_PID_LIVE, "RUN_PID is live", evidence)
    end
  end
  if pgid~datatype("W") then do
    if pgid + 0 > 0 then do
      if processProbe~pgidAlive(pgid) then return .QueueJobObservation~new(.QueueJobObservation~LIVE, self~PROVIDER_ID, self~CODE_PGID_LIVE, "a process-group member is live", evidence)
    end
  end
  if pid == "" & pgid == "" then do
    started = record~field(.QueueRecord~FIELD_RUN_STARTED_AT, "")
    if started == "" then started = record~field(.QueueRecord~FIELD_SUBMITTED_AT, "")
    age = .QueueTime~ageSeconds(started, clock~now)
    evidence["launch_timestamp"] = started
    evidence["launch_grace_seconds"] = launchGraceSeconds
    if age == .nil then do
      evidence["age_seconds"] = ""
      return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_LAUNCH_METADATA_UNKNOWN, "missing or unparseable launch timestamp; defer stale decision", evidence)
    end
    evidence["age_seconds"] = age
    if age < launchGraceSeconds then return .QueueJobObservation~new(.QueueJobObservation~LAUNCH_PENDING, self~PROVIDER_ID, self~CODE_LAUNCH_PENDING, "launch metadata is still inside QueueBash grace window", evidence)
    return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_LAUNCH_METADATA_UNKNOWN, "launch metadata remains incomplete after grace; QueueBash 0.18.144 defers rather than interrupts", evidence)
  end
  return .QueueJobObservation~new(.QueueJobObservation~DEAD, self~PROVIDER_ID, self~CODE_PROCESS_DEAD, "recorded RUN_PID/RUN_PGID has no live evidence", evidence)
::method terminate
  expose backend
  use strict arg record
  return backend~terminateDirect(record)
::method health
  use strict arg platformFacts
  evidence = platformFacts~asDirectory
  if platformFacts~osFamily == .QueuePlatformFacts~OS_LINUX then return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~HEALTHY, "DIRECT_READY", "local POSIX direct runner is available", self~capabilities, evidence)
  return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~UNAVAILABLE, "DIRECT_PLATFORM_UNSUPPORTED", platformFacts~osFamily, self~capabilities, evidence)
::method explain
  use arg platformFacts, jobRequirement
  d = .Directory~new
  d["provider"] = self~id
  d["version"] = self~version
  d["supports"] = self~supports(platformFacts, jobRequirement)~asDirectory
  d["selection_rule"] = "QueueBash direct runner compatibility; authoritative liveness is RUN_PID or live RUN_PGID membership"
  return d

::class SystemdRunnerProvider public subclass QueueRunnerProvider
::constant PROVIDER_ID "systemd"
::constant PROVIDER_VERSION "queuebash-0.18.144-compatible"
::constant CODE_MAINPID_LIVE "SYSTEMD_MAINPID_LIVE"
::constant CODE_SUBSTATE_LIVE "SYSTEMD_SUBSTATE_LIVE"
::constant CODE_UNIT_DEAD "SYSTEMD_UNIT_DEAD"
::constant CODE_UNIT_UNKNOWN "SYSTEMD_UNIT_UNKNOWN"
::constant CODE_LEGACY_FALLBACK "SYSTEMD_LEGACY_PID_FALLBACK"
::attribute systemdProbe get
::attribute directFallback get
::attribute backend get
::method init
  expose systemdProbe directFallback backend
  use arg systemdProbeArg = .nil, processProbeArg = .nil, clockArg = .nil, graceArg = .nil, backendArg = .nil
  if systemdProbeArg == .nil then systemdProbe = .QueueSystemdUserProbe~new; else systemdProbe = systemdProbeArg
  directFallback = .DirectRunnerProvider~new(processProbeArg, clockArg, graceArg, backendArg)
  if backendArg == .nil then backend = .QueuePosixRunnerBackend~new; else backend = backendArg
::method id
  return self~PROVIDER_ID
::method version
  return self~PROVIDER_VERSION
::method capabilities
  return .Array~of("local-transient-unit", "systemd-user", "systemd-unit-mainpid")
::method supports
  use arg platformFacts, jobRequirement
  if platformFacts~osFamily \= .QueuePlatformFacts~OS_LINUX then return .QueueProviderSupport~no("SYSTEMD_PLATFORM_UNSUPPORTED", platformFacts~osFamily)
  if platformFacts~rootLaunchingForeignUser(jobRequirement~runUser) then return .QueueProviderSupport~no("SYSTEMD_FOREIGN_USER_NOT_USED", "root launching another Unix user must use direct+runuser compatibility path")
  if \platformFacts~systemdProbeKnown then return .QueueProviderSupport~no("SYSTEMD_UNKNOWN", "systemd user service probe is unknown; fail closed for explicit systemd")
  if \platformFacts~systemdUserAvailable then return .QueueProviderSupport~no("SYSTEMD_UNAVAILABLE", "systemd --user service is unavailable")
  return .QueueProviderSupport~yes("SYSTEMD_SUPPORTED")
::method score
  use arg platformFacts, jobRequirement
  if jobRequirement~requestedRunner == .QueueRunnerKind~SYSTEMD then return 10000
  return 1000
::method prepare
  use strict arg context
  if context == .nil | context~command~items == 0 then return .QueueProviderOperationResult~failure("SYSTEMD_PREPARE_INVALID", "missing payload command")
  if context~unitName == "" then return .QueueProviderOperationResult~failure("SYSTEMD_PREPARE_INVALID", "missing deterministic systemd unit")
  return .QueueProviderOperationResult~success(.nil, "SYSTEMD_PREPARED")
::method launch
  expose backend
  use strict arg context
  return backend~launchSystemd(context)
::method observe
  expose systemdProbe directFallback
  use arg record
  if record~state \= .QueueState~RUNNING then return .QueueJobObservation~new(.QueueJobObservation~NOT_APPLICABLE, self~PROVIDER_ID, "NOT_RUNNING_STATE")
  unit = record~systemdUnit
  if unit == "" then do
    prior = directFallback~observe(record)
    evidence = prior~evidence
    evidence["systemd_unit"] = ""
    evidence["fallback"] = self~CODE_LEGACY_FALLBACK
    return .QueueJobObservation~new(prior~status, self~PROVIDER_ID, self~CODE_LEGACY_FALLBACK || ":" || prior~code, "old systemd record has no SYSTEMD_UNIT; applying QueueBash RUN_PID/RUN_PGID fallback", evidence)
  end
  status = systemdProbe~status(unit)
  evidence = status~asDirectory
  evidence["systemd_unit"] = unit
  if \status~known then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_UNIT_UNKNOWN, "recorded systemd unit is unqueryable; defer stale decision", evidence)
  active = status~activeState
  sub = status~subState
  mainPid = status~mainPid
  if active == .QueueSystemdState~ACTIVE | active == .QueueSystemdState~ACTIVATING | active == .QueueSystemdState~RELOADING then do
    if mainPid~datatype("W") then do
      if mainPid + 0 > 0 then return .QueueJobObservation~new(.QueueJobObservation~LIVE, self~PROVIDER_ID, self~CODE_MAINPID_LIVE, "SYSTEMD_UNIT/MainPID is authoritative live evidence", evidence)
    end
    if sub == .QueueSystemdState~RUNNING | sub == .QueueSystemdState~START | sub == .QueueSystemdState~AUTO_RESTART then return .QueueJobObservation~new(.QueueJobObservation~LIVE, self~PROVIDER_ID, self~CODE_SUBSTATE_LIVE, "systemd substate is authoritative live evidence", evidence)
    return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_UNIT_UNKNOWN, "active systemd unit has no conclusive payload evidence; defer", evidence)
  end
  if active == .QueueSystemdState~INACTIVE | active == .QueueSystemdState~FAILED | active == .QueueSystemdState~NOT_FOUND then return .QueueJobObservation~new(.QueueJobObservation~DEAD, self~PROVIDER_ID, self~CODE_UNIT_DEAD, "systemd ActiveState is terminal", evidence)
  if sub == .QueueSystemdState~DEAD | sub == .QueueSystemdState~FAILED | sub == .QueueSystemdState~EXITED then return .QueueJobObservation~new(.QueueJobObservation~DEAD, self~PROVIDER_ID, self~CODE_UNIT_DEAD, "systemd SubState is terminal", evidence)
  if sub == .QueueSystemdState~RUNNING | sub == .QueueSystemdState~START | sub == .QueueSystemdState~AUTO_RESTART then return .QueueJobObservation~new(.QueueJobObservation~LIVE, self~PROVIDER_ID, self~CODE_SUBSTATE_LIVE, "systemd SubState is live", evidence)
  return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, self~PROVIDER_ID, self~CODE_UNIT_UNKNOWN, "systemd state is not conclusive; defer", evidence)
::method terminate
  expose backend
  use strict arg record
  return backend~terminateSystemd(record)
::method health
  use strict arg platformFacts
  evidence = platformFacts~asDirectory
  if platformFacts~osFamily \= .QueuePlatformFacts~OS_LINUX then return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~UNAVAILABLE, "SYSTEMD_PLATFORM_UNSUPPORTED", platformFacts~osFamily, self~capabilities, evidence)
  if \platformFacts~systemdProbeKnown then return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~UNKNOWN, "SYSTEMD_PROBE_UNKNOWN", "systemd user-service capability could not be established", self~capabilities, evidence)
  if \platformFacts~systemdUserAvailable then return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~UNAVAILABLE, "SYSTEMD_USER_UNAVAILABLE", "systemd --user service is unavailable", self~capabilities, evidence)
  return .QueueProviderHealthReport~new(.QueueProviderCategory~RUNNER, self~id, self~version, .QueueProviderHealthState~HEALTHY, "SYSTEMD_READY", "systemd --user service is available", self~capabilities, evidence)
::method explain
  use arg platformFacts, jobRequirement
  d = .Directory~new
  d["provider"] = self~id
  d["version"] = self~version
  d["supports"] = self~supports(platformFacts, jobRequirement)~asDirectory
  d["selection_rule"] = "QueueBash systemd compatibility; SYSTEMD_UNIT ActiveState/SubState/MainPID is authoritative before RUN_PID"
  return d

::class QueueProviderRegistry public
::method init
  expose categories
  categories = .Directory~new
::method register
  expose categories
  use arg categoryArg, provider
  category = categoryArg~string~lower
  if \categories~hasIndex(category) then categories[category] = .Directory~new
  bucket = categories[category]
  bucket[provider~id~lower] = provider
  return self
::method get
  expose categories
  use arg categoryArg, providerId
  category = categoryArg~string~lower
  if \categories~hasIndex(category) then return .nil
  bucket = categories[category]
  id = providerId~string~lower
  if bucket~hasIndex(id) then return bucket[id]
  return .nil
::method all
  expose categories
  use arg categoryArg
  category = categoryArg~string~lower
  a = .Array~new
  if \categories~hasIndex(category) then return a
  bucket = categories[category]
  do id over bucket
    a~append(bucket[id])
  end
  return a
::method builtins class
  r = self~new
  r~register(.QueueProviderCategory~RUNNER, .DirectRunnerProvider~new)
  r~register(.QueueProviderCategory~RUNNER, .SystemdRunnerProvider~new)
  return r

::class QueueProviderDecision public
::constant CODE_SELECTED "SELECTED"
::attribute selected get
::attribute code get
::attribute provider get
::attribute requested get
::attribute effectiveRequested get
::attribute candidates get
::attribute warning get
::method init
  expose selected code provider requested effectiveRequested candidates warning
  use arg selectedArg, codeArg, providerArg = .nil, requestedArg = "", effectiveArg = "", candidatesArg = .nil, warningArg = ""
  selected = selectedArg; code = codeArg~string; provider = providerArg
  requested = requestedArg~string; effectiveRequested = effectiveArg~string; warning = warningArg~string
  if candidatesArg == .nil then candidates = .Array~new; else candidates = candidatesArg
::method asDirectory
  expose selected code provider requested effectiveRequested candidates warning
  d = .Directory~new
  d["selected"] = .QueueRexxUtil~jsonBoolean(selected)
  d["code"] = code
  d["requested_runner"] = requested
  d["effective_requested_runner"] = effectiveRequested
  if provider == .nil then d["provider"] = ""
  else d["provider"] = provider~id
  d["warning"] = warning
  d["candidates"] = candidates
  return d

::class QueueRunnerSelector public
::attribute registry get
::method init
  expose registry
  use arg registryArg
  registry = registryArg

::method select
  expose registry
  use arg platformFacts, jobRequirement
  requested = jobRequirement~requestedRunner
  if requested == "" then requested = .QueueRunnerKind~AUTO
  effective = requested
  warning = ""
  if requested \= .QueueRunnerKind~AUTO & requested \= .QueueRunnerKind~DIRECT & requested \= .QueueRunnerKind~SYSTEMD then do
    effective = .QueueRunnerKind~DIRECT
    warning = "unknown QueueBash runner token falls back to direct for 0.18.144 compatibility"
  end

  candidateOutput = .Array~new
  best = .nil
  bestScore = -999999999
  explicitFound = .false
  do p over registry~all(.QueueProviderCategory~RUNNER)
    if effective \= .QueueRunnerKind~AUTO & p~id \= effective then iterate
    explicitFound = .true
    support = p~supports(platformFacts, jobRequirement)
    c = .Directory~new
    c["id"] = p~id
    c["version"] = p~version
    c["support"] = support~asDirectory
    score = -1
    if support~supported then score = p~score(platformFacts, jobRequirement)
    c["score"] = score
    candidateOutput~append(c)
    if support~supported & score > bestScore then do
      best = p
      bestScore = score
    end
  end

  if best \= .nil then return .QueueProviderDecision~new(.true, .QueueProviderDecision~CODE_SELECTED, best, requested, effective, candidateOutput, warning)

  code = "NO_RUNNER_PROVIDER"
  if effective == .QueueRunnerKind~SYSTEMD then do
    p = registry~get(.QueueProviderCategory~RUNNER, .QueueRunnerKind~SYSTEMD)
    if p \= .nil then code = p~supports(platformFacts, jobRequirement)~code
  end
  else if \explicitFound then code = "RUNNER_NOT_REGISTERED"
  return .QueueProviderDecision~new(.false, code, .nil, requested, effective, candidateOutput, warning)

::requires "QueueRexxCore.cls"

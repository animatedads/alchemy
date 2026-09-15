/* QueueRexxHealth.cls - read-only health and runner observation parity, v0.1-dev6 */

::class QueueHealthRequiredPath public
::constant LOGS "logs"
::constant WORKERS "workers"
::constant OUTPUTS "outputs"
::constant STREAMS "streams"
::constant LOCKS "locks"
::constant STATE_LOCKS "locks/state"
::constant RECONCILE_ARCHIVE "logs/queue-state-reconcile"
::method names class
  return .Array~of(.QueueState~name(.QueueState~PENDING), .QueueState~name(.QueueState~RUNNING), .QueueState~name(.QueueState~PAUSED), .QueueState~name(.QueueState~DONE), .QueueState~name(.QueueState~FAILED), .QueueState~name(.QueueState~POL_BLOCKED), .QueueState~name(.QueueState~INTERRUPTED), .QueueState~name(.QueueState~CANCELLED), .QueueState~name(.QueueState~DELETED), self~LOGS, self~WORKERS, self~OUTPUTS, self~STREAMS, self~LOCKS, self~STATE_LOCKS, self~RECONCILE_ARCHIVE)

::class QueueHealthFinding public
::constant OK 1
::constant BAD 2
::constant WARN 3
::constant INFO 4
::constant SECTION 5
::attribute level get
::attribute message get
::attribute data get
::method init
  expose level message data
  use arg levelArg, messageArg, dataArg = .nil
  level = levelArg + 0
  message = messageArg~string
  if dataArg == .nil then data = .Directory~new; else data = dataArg
::method levelName class
  use arg levelArg
  select
    when levelArg == self~OK then return "ok"
    when levelArg == self~BAD then return "bad"
    when levelArg == self~WARN then return "warn"
    when levelArg == self~INFO then return "info"
    when levelArg == self~SECTION then return "section"
    otherwise return "detail"
  end
::method asDirectory
  expose level message data
  d = .Directory~new
  d["level"] = .QueueHealthFinding~levelName(level)
  d["message"] = message
  if data~items > 0 then d["data"] = data
  return d

::class QueueHealthReport public
::constant STATUS_OK "ok"
::constant STATUS_DEGRADED "degraded"
::constant STATUS_UNHEALTHY "unhealthy"
::attribute root get
::attribute findings get
::attribute errors get
::attribute warnings get
::attribute fixes get
::attribute deep get
::attribute scannedRecords get
::method init
  expose root findings errors warnings fixes deep scannedRecords
  use arg rootArg, deepArg = .false
  root = rootArg~string
  deep = deepArg
  findings = .Array~new
  errors = 0
  warnings = 0
  fixes = 0
  scannedRecords = 0
::method add
  expose findings errors warnings
  use arg finding
  findings~append(finding)
  if finding~level == .QueueHealthFinding~BAD then errors += 1
  if finding~level == .QueueHealthFinding~WARN then warnings += 1
  return finding
::method incrementScanned
  expose scannedRecords
  scannedRecords += 1
::method ok
  expose errors
  return errors == 0
::method status
  expose errors warnings
  if errors > 0 then return self~STATUS_UNHEALTHY
  if warnings > 0 then return self~STATUS_DEGRADED
  return self~STATUS_OK
::method asDirectory
  expose root findings errors warnings fixes deep scannedRecords
  d = .Directory~new
  d["schema"] = .QueueSchema~HEALTH
  d["ok"] = .QueueRexxUtil~jsonBoolean(self~ok)
  d["status"] = self~status
  d["queue_root"] = root
  d["version"] = .QueueRexxVersion~queueBashCompatibility
  d["fix"] = .JSONBoolean~false
  d["deep"] = .QueueRexxUtil~jsonBoolean(deep)
  d["timestamp"] = .DateTime~new~utcIsoDate
  summary = .Directory~new
  summary["errors"] = errors
  summary["warnings"] = warnings
  summary["fixes"] = fixes
  summary["scanned_records"] = scannedRecords
  d["summary"] = summary
  checks = .Array~new
  do finding over findings
    checks~append(finding~asDirectory)
  end
  d["checks"] = checks
  return d

::class QueueJobObserver public
::attribute registry get
::method init
  expose registry
  use arg registryArg = .nil
  if registryArg == .nil then registry = .QueueProviderRegistry~builtins; else registry = registryArg
::method providerFor
  expose registry
  use arg record
  runnerUsed = record~field(.QueueRecord~FIELD_RUNNER_USED, "")~lower
  unit = record~systemdUnit
  if runnerUsed == .QueueRunnerKind~SYSTEMD | unit \= "" then return registry~get(.QueueProviderCategory~RUNNER, .QueueRunnerKind~SYSTEMD)
  return registry~get(.QueueProviderCategory~RUNNER, .QueueRunnerKind~DIRECT)
::method observe
  use arg record
  provider = self~providerFor(record)
  if provider == .nil then return .QueueJobObservation~new(.QueueJobObservation~UNKNOWN, "", "RUNNER_PROVIDER_MISSING", "no registered runner provider can observe this record")
  return provider~observe(record)
::method asDirectory
  use arg record
  observation = self~observe(record)
  d = .Directory~new
  d["schema"] = .QueueSchema~JOB_OBSERVATION
  d["queuebash_compatibility_baseline"] = .QueueRexxVersion~queueBashCompatibility
  d["qid"] = record~qid
  d["state"] = record~stateName
  d["observation"] = observation~asDirectory
  return d

::class QueueHealthScanner public
::constant DEFAULT_MAX_RECORDS 100000
::attribute store get
::attribute observer get
::attribute maxRecords get
::method init
  expose store observer maxRecords
  use arg storeArg, observerArg = .nil, maxArg = .nil
  store = storeArg
  if observerArg == .nil then observer = .QueueJobObserver~new; else observer = observerArg
  if maxArg == .nil then do
    envMax = value("QUEUEREXX_HEALTH_MAX_RECORDS",, "ENVIRONMENT")
    if envMax~datatype("W") then do
      if envMax + 0 > 0 then maxRecords = envMax + 0; else maxRecords = self~DEFAULT_MAX_RECORDS
    end
    else maxRecords = self~DEFAULT_MAX_RECORDS
  end
  else maxRecords = maxArg + 0

::method directoryExists private
  use arg path
  drop qrxdir.
  call SysFileTree path, "qrxdir.", "DO"
  return qrxdir.0 > 0

::method validateRecord private
  use arg report, record
  problems = .Array~new
  if record~field(.QueueRecord~FIELD_JOB_ID, "") == "" then problems~append("missing JOB_ID")
  if record~field(.QueueRecord~FIELD_JOB_NAME, "") == "" then problems~append("missing JOB_NAME")
  priority = record~field(.QueueRecord~FIELD_PRIORITY, "")
  if priority == "" then problems~append("missing PRIORITY")
  else if \priority~datatype("W") then problems~append("non-integer PRIORITY=" || priority)
  if \record~hasArrayField(.QueueRecord~FIELD_COMMAND) then problems~append("missing COMMAND array")
  if problems~items == 0 then return .true
  data = .Directory~new
  data["qid"] = record~qid
  data["path"] = record~path
  data["problems"] = problems
  report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "malformed job file: " || record~path, data))
  return .false

::method scan
  expose store observer maxRecords
  use arg deepArg = .false
  report = .QueueHealthReport~new(store~root, deepArg)
  root = store~root
  if \self~directoryExists(root) then do
    report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "root missing: " || root))
    return report
  end
  report~add(.QueueHealthFinding~new(.QueueHealthFinding~OK, "root present: " || root))

  do name over .QueueHealthRequiredPath~names
    path = root || "/" || name
    if self~directoryExists(path) then report~add(.QueueHealthFinding~new(.QueueHealthFinding~OK, "directory: " || name))
    else report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "missing directory: " || path))
  end

  records = store~records(.QueueState~ALL, maxRecords + 1)
  if records~items > maxRecords then do
    report~add(.QueueHealthFinding~new(.QueueHealthFinding~WARN, "health record scan bounded at " || maxRecords || " records"))
  end

  byQid = .Directory~new
  scanned = 0
  do record over records
    if scanned >= maxRecords then leave
    scanned += 1
    report~incrementScanned
    self~validateRecord(report, record)
    qid = record~qid
    if \byQid~hasIndex(qid) then byQid[qid] = .Array~new
    byQid[qid]~append(record)
  end

  duplicateFound = .false
  do qid over byQid
    matches = byQid[qid]
    if matches~items <= 1 then iterate
    duplicateFound = .true
    states = .Array~new
    do record over matches
      states~append(record~stateName)
    end
    data = .Directory~new
    data["qid"] = qid
    data["count"] = matches~items
    data["states"] = states
    report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "duplicate QID in multiple states: " || qid || " (" || matches~items || " records)", data))
  end
  if \duplicateFound then report~add(.QueueHealthFinding~new(.QueueHealthFinding~OK, "no duplicate state records"))

  staleFound = .false
  do qid over byQid
    do record over byQid[qid]
      if record~state \= .QueueState~RUNNING then iterate
      observation = observer~observe(record)
      data = .Directory~new
      data["qid"] = record~qid
      data["path"] = record~path
      data["observation"] = observation~asDirectory
      select
        when observation~status == .QueueJobObservation~DEAD then do
          staleFound = .true
          report~add(.QueueHealthFinding~new(.QueueHealthFinding~BAD, "stale running job: " || record~path, data))
        end
        when observation~status == .QueueJobObservation~UNKNOWN then report~add(.QueueHealthFinding~new(.QueueHealthFinding~INFO, "running job liveness deferred: " || record~qid, data))
        when observation~status == .QueueJobObservation~LAUNCH_PENDING then report~add(.QueueHealthFinding~new(.QueueHealthFinding~INFO, "running job launch pending: " || record~qid, data))
        when observation~status == .QueueJobObservation~LIVE then report~add(.QueueHealthFinding~new(.QueueHealthFinding~OK, "running job live: " || record~qid, data))
        otherwise report~add(.QueueHealthFinding~new(.QueueHealthFinding~INFO, "running job observation not applicable: " || record~qid, data))
      end
    end
  end
  if \staleFound then report~add(.QueueHealthFinding~new(.QueueHealthFinding~OK, "no stale running jobs"))

  return report

::requires "QueueRexxCore.cls"
::requires "QueueRexxProviders.cls"

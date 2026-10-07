/*----------------------------------------------------------------------------*/
/* InspectorClouseau.cls                                                       */
/*                                                                            */
/* First-version ooRexx live/source examiner.                                */
/*   v1.4.2: trace request SysFileTree pseudo-entry filter hardening.        */
/*     - attach seeds automatic roots once only.                              */
/*     - stream writes trap NOTREADY as well as SYNTAX.                       */
/*     - signal scanning strips block comments.                               */
/*     - optional .nil condition-equals values no longer create false guards. */
/*     - handler condition evidence is captured before helper method calls.   */
/*                                                                            */
/* Purpose:                                                                   */
/*   - attach to a live ooRexx application object or context                   */
/*   - infer package/class/method closure from source/package metadata         */
/*   - crawl reachable live objects without mutating collections               */
/*   - record collection sizes and queue state                                 */
/*   - classify methods and detect SIGNAL / SIGNAL ON / SIGNAL VALUE / CALL ON */
/*   - emit native ooRexx structures suitable for json.cls                     */
/*                                                                            */
/* Important v1 rule:                                                          */
/*   Runtime probe insertion is implemented but disabled by default. Enable it */
/*   only when the application explicitly accepts temporary method-table       */
/*   mutation on application objects.                                          */
/*----------------------------------------------------------------------------*/

::requires "json.cls"

::class InspectorClouseau public

::constant SCHEMA "alchemy.oorexx.inspector-clouseau.snapshot.v1"
::constant PROBE_PREFIX "__INSPECTOR_CLOUSEAU__"
::constant MAX_DEPTH 10
::constant MAX_COLLECTION_SAMPLE 200

::attribute roots private
::attribute packages private
::attribute packageQueue private
::attribute objects private
::attribute objectQueue private
::attribute edges private
::attribute queues private
::attribute classes private
::attribute methods private
::attribute findings private
::attribute warnings private
::attribute visitedObjects private
::attribute walkedObjects private
::attribute visitedPackages private
::attribute visitedClasses private
::attribute opaqueMethods private
::attribute oidCounter private
::attribute enableInjectedProbes private
::attribute ownPackage private
::attribute ownClassName private
::attribute classSlots private
::attribute probeCounter private
::attribute rules private
::attribute variableReports private
::attribute triggerInstalled private
::attribute triggerCounter private
::attribute triggerEvents private
::attribute triggerActive private
::attribute callChainReports private
::attribute traceReports private
::attribute inheritanceMaps private
::attribute announcementEmitted private
::attribute securityEvents private
::attribute automaticRootsSeeded private
::attribute traceRequestDir private
::attribute traceRequestPrefix private
::attribute traceRequestFiles private
::attribute traceRequestFingerprints private
::attribute traceRequestEvents private
::attribute traceRequestLoadReports private
::attribute traceRequestReportActive private
::attribute traceRequestDirectorySignatureLast private
::attribute traceRequestScanActive private
::attribute traceRequestAlarm private
::attribute traceRequestAlarmTarget private
::attribute traceRequestAlarmSeconds private
::attribute traceRequestAlarmActive private
::attribute traceRequestLastSummary private
::attribute snapshotAlarm private
::attribute snapshotAlarmTarget private
::attribute snapshotAlarmSeconds private
::attribute snapshotAlarmActive private
::attribute snapshotAlarmPhase private
::attribute snapshotAlarmPrefix private
::attribute scheduledSnapshotEvents private
::attribute returnProxyEvents private
::attribute unknownMethodEvents private

::method init public
  expose roots packages packageQueue objects objectQueue edges queues classes methods findings warnings visitedObjects walkedObjects visitedPackages visitedClasses opaqueMethods oidCounter enableInjectedProbes ownPackage ownClassName classSlots probeCounter rules variableReports triggerInstalled triggerCounter triggerEvents triggerActive callChainReports traceReports inheritanceMaps announcementEmitted securityEvents automaticRootsSeeded traceRequestDir traceRequestPrefix traceRequestFiles traceRequestFingerprints traceRequestEvents traceRequestLoadReports traceRequestReportActive traceRequestDirectorySignatureLast traceRequestScanActive traceRequestAlarm traceRequestAlarmTarget traceRequestAlarmSeconds traceRequestAlarmActive traceRequestLastSummary snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix scheduledSnapshotEvents returnProxyEvents unknownMethodEvents

  roots = .array~new
  packages = .array~new
  packageQueue = .queue~new
  objects = .directory~new
  objectQueue = .queue~new
  edges = .array~new
  queues = .array~new
  classes = .directory~new
  methods = .array~new
  findings = .array~new
  warnings = .array~new
  visitedObjects = .identityTable~new
  walkedObjects = .identityTable~new
  visitedPackages = .identityTable~new
  visitedClasses = .identityTable~new
  opaqueMethods = .array~new
  oidCounter = 0
  enableInjectedProbes = .false
  ownPackage = .context~package
  ownClassName = self~class~id~translate
  classSlots = .directory~new
  probeCounter = 0
  rules = .array~new
  variableReports = .array~new
  triggerInstalled = .identityTable~new
  triggerCounter = 0
  triggerEvents = .array~new
  triggerActive = .false
  callChainReports = .array~new
  traceReports = .array~new
  inheritanceMaps = .directory~new
  announcementEmitted = .false
  securityEvents = .array~new
  automaticRootsSeeded = .false
  traceRequestDir = ""
  traceRequestPrefix = "inspector-clouseau-trace-request"
  traceRequestFiles = .directory~new
  traceRequestFingerprints = .directory~new
  traceRequestEvents = .array~new
  traceRequestLoadReports = .array~new
  traceRequestReportActive = .false
  traceRequestDirectorySignatureLast = ""
  traceRequestScanActive = .false
  traceRequestAlarm = .nil
  traceRequestAlarmTarget = .nil
  traceRequestAlarmSeconds = 0
  traceRequestAlarmActive = .false
  traceRequestLastSummary = .directory~new
  snapshotAlarm = .nil
  snapshotAlarmTarget = .nil
  snapshotAlarmSeconds = 0
  snapshotAlarmActive = .false
  snapshotAlarmPhase = "scheduled"
  snapshotAlarmPrefix = "inspector-clouseau-snapshot"
  scheduledSnapshotEvents = .array~new
  returnProxyEvents = .array~new
  unknownMethodEvents = .array~new
  self~reportCollectionSizes(.true)
  self~reportQueueItems(.true)
  self~suppressInternalClassMethods(.true)
  self~reportInheritanceMap(.true)

  self~addWarning("conservative mode: injected in-scope probes are disabled unless enableProbes(.true) is called.")


::method setTraceRequestDirectory public
  expose traceRequestDir traceRequestPrefix
  dir = ""
  prefix = "inspector-clouseau-trace-request"
  if arg() >= 1 then dir = arg(1)
  if arg() >= 2 then prefix = arg(2)
  if dir == .nil then dir = ""
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-trace-request"
  traceRequestDir = "" || dir
  traceRequestPrefix = "" || prefix
  return self

::method checkTraceRequestsNow public
  expose traceRequestDir traceRequestPrefix traceRequestDirectorySignatureLast traceRequestScanActive
  if traceRequestDir == .nil then return 0
  if traceRequestDir = "" then return 0
  if traceRequestScanActive == .true then return 0
  traceRequestScanActive = .true
  signal on syntax name checkTraceRequestsFailed
  signal on any name checkTraceRequestsFailed
  newSig = self~traceRequestDirectorySignature(traceRequestDir)
  if newSig = traceRequestDirectorySignatureLast then do
    traceRequestScanActive = .false
    return 0
  end
  traceRequestDirectorySignatureLast = newSig
  loaded = self~loadTraceRequestsFromDirectory(traceRequestDir, traceRequestPrefix)
  traceRequestScanActive = .false
  return loaded

checkTraceRequestsFailed:
  traceRequestScanActive = .false
  self~addWarning("Trace request alarm scan failed condition=" || condition("C") || " description=" || condition("D"))
  return 0

::method startTraceRequestAlarm public
  expose traceRequestAlarm traceRequestAlarmTarget traceRequestAlarmSeconds traceRequestAlarmActive traceRequestLastSummary snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix scheduledSnapshotEvents
  seconds = 5
  if arg() >= 1 then seconds = arg(1)
  if seconds == .nil | seconds = "" then seconds = 5
  seconds = seconds + 0
  if seconds < 1 then seconds = 1
  self~stopTraceRequestAlarm
  traceRequestAlarmSeconds = seconds
  traceRequestAlarmActive = .true
  traceRequestAlarmTarget = .InspectorTraceRequestAlarmTarget~new(self)
  traceRequestAlarm = .Alarm~new(seconds, traceRequestAlarmTarget, "triggered")
  return .true

::method stopTraceRequestAlarm public
  expose traceRequestAlarm traceRequestAlarmTarget traceRequestAlarmActive
  signal on syntax name stopTraceAlarmDone
  if traceRequestAlarm \== .nil then traceRequestAlarm~cancel
stopTraceAlarmDone:
  signal off syntax
  traceRequestAlarm = .nil
  traceRequestAlarmTarget = .nil
  traceRequestAlarmActive = .false
  return .true

::method traceRequestAlarmFired public
  expose traceRequestAlarm traceRequestAlarmTarget traceRequestAlarmSeconds traceRequestAlarmActive traceRequestLastSummary snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix scheduledSnapshotEvents
  if traceRequestAlarmActive \== .true then return .false
  self~checkTraceRequestsNow
  if traceRequestAlarmActive == .true then do
    traceRequestAlarmTarget = .InspectorTraceRequestAlarmTarget~new(self)
    traceRequestAlarm = .Alarm~new(traceRequestAlarmSeconds, traceRequestAlarmTarget, "triggered")
  end
  return .true

::method startSnapshotAlarm public
  expose snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix
  seconds = 1800
  phase = "scheduled"
  prefix = "inspector-clouseau-snapshot"
  if arg() >= 1 then seconds = arg(1)
  if arg() >= 2 then phase = arg(2)
  if arg() >= 3 then prefix = arg(3)
  if seconds == .nil | seconds = "" then seconds = 1800
  seconds = seconds + 0
  if seconds < 1 then seconds = 1
  if phase == .nil | phase = "" then phase = "scheduled"
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-snapshot"
  self~stopSnapshotAlarm
  snapshotAlarmSeconds = seconds
  snapshotAlarmPhase = "" || phase
  snapshotAlarmPrefix = "" || prefix
  snapshotAlarmActive = .true
  snapshotAlarmTarget = .InspectorSnapshotAlarmTarget~new(self)
  snapshotAlarm = .Alarm~new(seconds, snapshotAlarmTarget, "triggered")
  return .true

::method stopSnapshotAlarm public
  expose snapshotAlarm snapshotAlarmTarget snapshotAlarmActive
  signal on syntax name stopSnapshotAlarmDone
  if snapshotAlarm \== .nil then snapshotAlarm~cancel
stopSnapshotAlarmDone:
  signal off syntax
  snapshotAlarm = .nil
  snapshotAlarmTarget = .nil
  snapshotAlarmActive = .false
  return .true

::method snapshotAlarmFired public
  expose snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix
  if snapshotAlarmActive \== .true then return .false
  self~writeTimestampedSnapshot(snapshotAlarmPhase, snapshotAlarmPrefix, .true)
  if snapshotAlarmActive == .true then do
    snapshotAlarmTarget = .InspectorSnapshotAlarmTarget~new(self)
    snapshotAlarm = .Alarm~new(snapshotAlarmSeconds, snapshotAlarmTarget, "triggered")
  end
  return .true

::method writeTimestampedSnapshot public
  expose scheduledSnapshotEvents
  phase = "snapshot"
  prefix = "inspector-clouseau-snapshot"
  writeLatest = .false
  if arg() >= 1 then phase = arg(1)
  if arg() >= 2 then prefix = arg(2)
  if arg() >= 3 then writeLatest = arg(3)
  if phase == .nil | phase = "" then phase = "snapshot"
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-snapshot"

  signal on syntax name writeTimestampedSnapshotFailed
  signal on notready name writeTimestampedSnapshotFailed
  snap = self~snapshot
  phaseToken = self~safeToken(phase)
  stamp = self~timestampToken
  base = prefix || "-" || phaseToken || "-" || stamp
  jsonPath = snap~writeJson(base || ".json")
  textPath = snap~writeText(base || ".txt")
  latestJson = ""
  latestText = ""
  if writeLatest == .true then do
    latestBase = prefix || "-" || phaseToken
    latestJson = snap~writeJson(latestBase || ".json")
    latestText = snap~writeText(latestBase || ".txt")
  end
  ev = .directory~new
  ev~put(self~nowIso, "time")
  ev~put("written", "status")
  ev~put(phase, "phase")
  ev~put(prefix, "prefix")
  ev~put(base, "base")
  ev~put(jsonPath, "json_path")
  ev~put(textPath, "text_path")
  if latestJson \= "" then ev~put(latestJson, "latest_json_path")
  if latestText \= "" then ev~put(latestText, "latest_text_path")
  scheduledSnapshotEvents~append(ev)
  signal off syntax
  signal off notready
  return ev

writeTimestampedSnapshotFailed:
  ev = .directory~new
  ev~put(self~nowIso, "time")
  ev~put("failed", "status")
  ev~put(phase, "phase")
  ev~put(prefix, "prefix")
  ev~put(condition("C"), "condition")
  ev~put(condition("D"), "description")
  scheduledSnapshotEvents~append(ev)
  self~addWarning("Timestamped snapshot write failed phase=" || phase || " condition=" || condition("C"))
  signal off syntax
  signal off notready
  return ev

::method loadConfiguredTraceRequests private
  return self~checkTraceRequestsNow

::method loadTraceRequestsFromDirectory public
  expose traceRequestFiles traceRequestFingerprints traceRequestEvents traceRequestPrefix traceRequestDirectorySignatureLast traceRequestLastSummary
  dir = ""
  prefix = traceRequestPrefix
  forceLoad = .false
  if arg() >= 1 then dir = arg(1)
  if arg() >= 2 then prefix = arg(2)
  if arg() >= 3 then forceLoad = arg(3)
  if dir == .nil | dir = "" then return 0
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-trace-request"

  summary = self~newTraceRequestScanSummary(dir, prefix, forceLoad)
  traceRequestLastSummary = summary

  signal on syntax name loadTraceDirFailed
  signal on any name loadTraceDirFailed

  currentSig = self~traceRequestDirectorySignature(dir)
  traceRequestDirectorySignatureLast = currentSig
  summary~put(currentSig, "directory_signature")

  files = self~traceRequestFileList(dir)
  if files == .nil then do
    summary~put("directory-empty-or-unreadable", "reason")
    self~reportTraceRequestLoad(dir, prefix, 0, "directory-empty-or-unreadable")
    return 0
  end
  summary~put(files~items, "candidate_files")

  loaded = 0
  seen = 0
  skippedUnchanged = 0
  zeroRuleFiles = 0
  loadedFiles = 0
  do i = 1 to files~items
    path = files~at(i)
    if path == .nil | path = "" then iterate
    summary~put(seen + 1, "considered_files")
    name = self~fileNameFromPath(path)
    if \self~isTraceRequestFileName(name) then do
      summary~put(summary~at("skipped_bad_name") + 1, "skipped_bad_name")
      iterate
    end
    fingerprint = self~traceRequestPathFingerprint(path)
    if forceLoad \== .true then do
      if traceRequestFingerprints~hasIndex(path) then do
        if traceRequestFingerprints~at(path) = fingerprint then do
          skippedUnchanged = skippedUnchanged + 1
          iterate
        end
      end
    end
    seen = seen + 1
    summary~put(seen, "files_loaded_attempted")
    count = self~loadTraceRequestFile(path, prefix)
    traceRequestFiles~put(count, path)
    traceRequestFingerprints~put(fingerprint, path)
    if count > 0 then do
      loaded = loaded + count
      loadedFiles = loadedFiles + 1
    end
    else zeroRuleFiles = zeroRuleFiles + 1
  end

  summary~put(seen, "files_seen")
  summary~put(skippedUnchanged, "skipped_unchanged")
  summary~put(zeroRuleFiles, "zero_rule_files")
  summary~put(loadedFiles, "loaded_files")
  summary~put(loaded, "rules_loaded")
  summary~put("directory-load", "reason")
  summary~put("ok", "status")
  traceRequestLastSummary = summary

  if loaded > 0 then self~refreshObjectWalkForNewRules
  self~reportTraceRequestLoad(dir, prefix, loaded, "directory-load")
  return loaded

loadTraceDirFailed:
  summary~put("failed", "status")
  summary~put(condition("C"), "condition")
  summary~put(condition("D"), "description")
  traceRequestLastSummary = summary
  self~reportTraceRequestLoad(dir, prefix, 0, "directory-load-failed")
  self~addWarning("Trace request directory load failed: " || dir || " condition=" || condition("C"))
  return 0

::method traceRequestFileList private
  use strict arg dir
  signal on syntax name traceRequestFileListFailed
  files. = ""
  mask = self~joinPath(dir, "*.json")
  call SysFileTree mask, "files.", "FO"
  out = .array~new
  if \datatype(files.0, "W") then return out
  do i = 1 to files.0
    raw = "" || files.i
    if raw = "" then iterate
    path = self~normalizeTraceRequestPath(raw, dir)
    if path = "" then iterate
    name = self~fileNameFromPath(path)
    if \self~isTraceRequestFileName(name) then iterate
    -- SysFileTree is the native ooRexx authority for this scanner.  Do not
    -- re-certify the path through BSF/Java here: early Inspector startup may
    -- not have the same Java path semantics.  Normalize the entry first,
    -- because some SysFileTree configurations can return a basename or a
    -- decorated line rather than the exact stream path.
    out~append(path)
  end
  return out

traceRequestFileListFailed:
  return .array~new

::method isTraceRequestFileName private
  use strict arg name
  if name == .nil then return .false
  -- SysFileTree may return relative paths such as ./inspector-trace-requests/trace1.json.
  -- Hidden filtering must therefore be applied only to the basename, not the
  -- complete path, otherwise the leading ./ makes every relative request hidden.
  n = self~fileNameFromPath("" || name)
  if n = "" then return .false
  if n = "." | n = ".." then return .false
  if self~isHiddenName(n) then return .false
  upperName = translate(n)
  if right(upperName, 5) \= ".JSON" then return .false
  if upperName~pos(".RECEIPT.JSON") > 0 then return .false
  return .true

::method normalizeTraceRequestPath private
  use arg entry, dir
  if entry == .nil then return ""
  raw = "" || entry
  if raw = "" then return ""
  if self~isTraceRequestFileName(raw) then do
    if raw~pos("/") = 0 & raw~pos("\") = 0 then return self~joinPath(dir, raw)
    return raw
  end
  lastMatch = ""
  rest = raw
  do while rest \= ""
    parse var rest token rest
    if token = "" then iterate
    if self~isTraceRequestFileName(token) then lastMatch = token
  end
  if lastMatch \= "" then do
    if lastMatch~pos("/") = 0 & lastMatch~pos("\") = 0 then return self~joinPath(dir, lastMatch)
    return lastMatch
  end
  return ""

::method newTraceRequestScanSummary private
  use arg dir, prefix, forceLoad
  d = .directory~new
  d~put(self~nowIso, "time")
  d~put(dir, "directory")
  d~put(prefix, "prefix")
  d~put(forceLoad, "force_load")
  d~put(0, "candidate_files")
  d~put(0, "considered_files")
  d~put(0, "files_loaded_attempted")
  d~put(0, "files_seen")
  d~put(0, "loaded_files")
  d~put(0, "zero_rule_files")
  d~put(0, "skipped_unchanged")
  d~put(0, "skipped_bad_name")
  d~put(0, "rules_loaded")
  d~put("pending", "status")
  return d

::method traceRequestLastSummaryText public
  expose traceRequestLastSummary
  if traceRequestLastSummary == .nil then return "trace_request_scan=none"
  signal on syntax name traceSummaryTextFailed
  d = traceRequestLastSummary
  text = "scan="
  val = d~at("status"); if val \== .nil then text = text || val
  val = d~at("candidate_files"); if val \== .nil then text = text || " candidates=" || val
  val = d~at("files_seen"); if val \== .nil then text = text || " seen=" || val
  val = d~at("loaded_files"); if val \== .nil then text = text || " loaded_files=" || val
  val = d~at("zero_rule_files"); if val \== .nil then text = text || " zero_rule_files=" || val
  val = d~at("skipped_unchanged"); if val \== .nil then text = text || " skipped_unchanged=" || val
  val = d~at("skipped_bad_name"); if val \== .nil then text = text || " skipped_bad_name=" || val
  val = d~at("rules_loaded"); if val \== .nil then text = text || " rules=" || val
  val = d~at("condition"); if val \== .nil then text = text || " condition=" || val
  return text
traceSummaryTextFailed:
  return "trace_request_scan=summary_failed"
::method isRegularFilePath private
  use strict arg path
  signal on syntax name regularFilePathFailed
  f = .AlchemyBsfGuard~javaFile(path, "InspectorClouseau.javaFile")
  if f == .nil then return .false
  if \f~exists then return .false
  if \f~isFile then return .false
  return .true

regularFilePathFailed:
  return .false

::method traceRequestDirectorySignature private
  use strict arg dir
  files = self~traceRequestFileList(dir)
  sig = ""
  do i = 1 to files~items
    path = files~at(i)
    name = self~fileNameFromPath(path)
    if self~isHiddenName(name) then iterate
    upperName = translate(name)
    if right(upperName, 5) \= ".JSON" then iterate
    if upperName~pos(".RECEIPT.JSON") > 0 then iterate
    sig = sig || path || "|" || self~traceRequestPathFingerprint(path) || '0a'x
  end
  return sig

::method traceRequestPathFingerprint private
  use strict arg path
  signal on syntax name pathFingerprintFailed
  f = .AlchemyBsfGuard~javaFile(path, "InspectorClouseau.javaFile")
  return ("" || f~lastModified) || ":" || ("" || f~length)
pathFingerprintFailed:
  return "unknown:" || self~nowIso

::method joinPath private
  use strict arg dir, name
  if dir = "" then return name
  last = dir~right(1)
  if last = "/" | last = "\" then return dir || name
  return dir || "/" || name

::method fileNameFromPath private
  use strict arg path
  p = "" || path
  slash = p~lastPos("/")
  bslash = p~lastPos("\")
  cut = slash
  if bslash > cut then cut = bslash
  if cut > 0 then return p~substr(cut + 1)
  return p

::method loadTraceRequestFile private
  expose traceRequestEvents
  use strict arg path, defaultPrefix

  /* --- parse JSON directly from file, with progressive fallback ---
     Preferred: json~fromFile(path) — class or instance method.
     Fallback:  manual stream read + json~fromJson(txt).
     The manual read uses the line-by-line idiom: f~charin(,f~chars) raises
     NOTREADY on this OORexx build after a line-mode open. */

  data = .nil
  parseStatus = ""

  /* 1. class-method fromFile */
  signal on syntax name loadTraceFromFileInstance
  if .stream~new(path)~query("exists") = "" then return 0
  data = .json~fromFile(path)
  signal off syntax
  parseStatus = "fromFile-class"
  signal loadTraceParseDone

loadTraceFromFileInstance:
  /* 2. instance-method fromFile */
  signal off syntax
  signal on syntax name loadTraceManualRead
  if .stream~new(path)~query("exists") = "" then return 0
  j = .json~new
  data = j~fromFile(path)
  signal off syntax
  parseStatus = "fromFile-instance"
  signal loadTraceParseDone

loadTraceManualRead:
  /* 3. manual read + class-method fromJson */
  signal off syntax
  signal on syntax   name loadTraceFileFailed
  signal on notready name loadTraceFileFailed
  if .stream~new(path)~query("exists") = "" then return 0
  data = .json~fromFile(path)
  signal off syntax
  signal off notready
  signal on syntax name loadTraceFromJsonInstance
  data = .json~fromJson(txt)
  signal off syntax
  parseStatus = "fromJson-class"
  signal loadTraceParseDone

loadTraceFromJsonInstance:
  /* 4. manual read + instance-method fromJson */
  signal off syntax
  signal on syntax name loadTraceParseGiveUp
  j = .json~new
  data = j~fromJson(txt)
  signal off syntax
  parseStatus = "fromJson-instance"
  signal loadTraceParseDone

loadTraceParseGiveUp:
  signal off syntax
  parseStatus = "parse-failed"

loadTraceParseDone:
  count = 0
  if data \== .nil then do
    signal on syntax name loadTraceApplyFailed
    count = self~applyTraceRequestData(data, defaultPrefix, path)
    signal off syntax
  end

  ev = .directory~new
  ev~put(self~nowIso,   "time")
  ev~put(path,          "path")
  ev~put(count,         "rules_loaded")
  ev~put("loaded",      "status")
  ev~put(parseStatus,   "parse_status")
  ev~put(defaultPrefix, "report_prefix")
  traceRequestEvents~append(ev)
  self~writeTraceRequestReceipt(path, ev)
  return count

loadTraceApplyFailed:
  signal off syntax
  ev = .directory~new
  ev~put(self~nowIso,                    "time")
  ev~put(path,                           "path")
  ev~put("apply-failed",                 "status")
  ev~put(parseStatus,                    "parse_status")
  ev~put(self~safeString(condition("C")), "condition")
  ev~put(self~safeString(condition("D")), "description")
  ev~put(defaultPrefix, "report_prefix")
  traceRequestEvents~append(ev)
  self~writeTraceRequestReceipt(path, ev)
  self~addWarning("Trace request apply failed: " || path || " parse=" || parseStatus || " condition=" || condition("C"))
  return 0

loadTraceFileFailed:
  signal off syntax
  signal off notready
  ev = .directory~new
  ev~put(self~nowIso,                    "time")
  ev~put(path,                           "path")
  ev~put("failed",                       "status")
  ev~put(self~safeString(condition("C")), "condition")
  ev~put(self~safeString(condition("D")), "description")
  ev~put(defaultPrefix, "report_prefix")
  traceRequestEvents~append(ev)
  self~writeTraceRequestReceipt(path, ev)
  self~addWarning("Trace request file load failed: " || path || " condition=" || condition("C") || " description=" || condition("D"))
  return 0

::method traceRequestFileFingerprint private
  use strict arg f
  signal on syntax name fingerprintFailed
  return ("" || f~lastModified) || ":" || ("" || f~length)
fingerprintFailed:
  return self~nowIso

::method writeTraceRequestReceipt private
  use arg path, ev

  if path == .nil | path = "" then return .false
  if ev == .nil then return .false
  signal on syntax name receiptFailed
  signal on notready name receiptFailed

  base = self~traceRequestReceiptBase(path)
  jsonPath = base || ".receipt.json"
  textPath = base || ".receipt.txt"

  rep = .directory~new
  rep~put("alchemy.oorexx.inspector-clouseau.trace-request-receipt.v1", "schema")
  rep~put(self~nowIso, "generated_at")
  rep~put(path, "request_path")
  rep~put(ev, "event")

  writer = .InspectorJsonWriter~new
  js = .stream~new(jsonPath)
  js~open("write replace")
  js~charout(writer~encode(rep))
  js~close

  ts = .stream~new(textPath)
  ts~open("write replace")
  ts~charout(self~traceRequestReceiptText(rep))
  ts~close
  return .true

receiptFailed:
  signal off syntax
  signal off notready
  self~addWarning("Trace request receipt write failed: " || path || " condition=" || condition("C"))
  return .false

::method traceRequestReceiptBase private
  use strict arg path
  slash = path~lastPos("/")
  if slash <= 0 then do
    dir = "."
    name = path
  end
  else do
    dir = path~left(slash - 1)
    name = path~substr(slash + 1)
  end
  if translate(right(name, 5)) = ".JSON" then name = name~left(name~length - 5)
  if name = "" then name = "request"
  return dir || "/." || name

::method traceRequestReceiptText private
  use strict arg rep
  text = "Inspector Clouseau trace request receipt" || "0a"x
  text = text || "schema: " || rep~at("schema") || "0a"x
  text = text || "generated_at: " || rep~at("generated_at") || "0a"x
  text = text || "request_path: " || rep~at("request_path") || "0a"x
  ev = rep~at("event")
  if ev \== .nil then do
    val = ev~at("status"); if val \== .nil then text = text || "status: " || val || "0a"x
    val = ev~at("rules_loaded"); if val \== .nil then text = text || "rules_loaded: " || val || "0a"x
    val = ev~at("condition"); if val \== .nil then text = text || "condition: " || val || "0a"x
    val = ev~at("description"); if val \== .nil then text = text || "description: " || val || "0a"x
    val = ev~at("report_prefix"); if val \== .nil then text = text || "report_prefix: " || val || "0a"x
  end
  return text
::method reportTraceRequestLoad private
  expose traceRequestEvents traceRequestLoadReports traceRequestReportActive traceRequestLastSummary traceRequestDirectorySignatureLast traceRequestScanActive traceRequestAlarm traceRequestAlarmTarget traceRequestAlarmSeconds traceRequestAlarmActive snapshotAlarm snapshotAlarmTarget snapshotAlarmSeconds snapshotAlarmActive snapshotAlarmPhase snapshotAlarmPrefix scheduledSnapshotEvents rules
  use arg dir, prefix, loaded, reason

  if traceRequestReportActive == .true then return .false
  if loaded == .nil then loaded = 0
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-trace-request"
  if reason == .nil | reason = "" then reason = "trace-request-load"

  traceRequestReportActive = .true
  signal on syntax name reportTraceRequestFailed
  signal on notready name reportTraceRequestFailed

  rep = .directory~new
  rep~put("alchemy.oorexx.inspector-clouseau.trace-request-load.v1", "schema")
  rep~put(self~nowIso, "generated_at")
  rep~put(dir, "directory")
  rep~put(reason, "reason")
  rep~put(loaded, "rules_loaded")
  rep~put(rules~items, "total_rule_count")
  if traceRequestLastSummary \== .nil then rep~put(traceRequestLastSummary, "scan_summary")

  events = .array~new
  do ev over traceRequestEvents
    events~append(ev)
  end
  rep~put(events, "trace_request_events")

  token = self~safeToken(self~nowIso)
  base = prefix || "-loaded-" || token
  jsonPath = base || ".json"
  textPath = base || ".txt"

  writer = .InspectorJsonWriter~new
  jsonText = writer~encode(rep)
  js = .stream~new(jsonPath)
  js~open("write replace")
  js~charout(jsonText)
  js~close

  text = self~traceRequestLoadText(rep)
  ts = .stream~new(textPath)
  ts~open("write replace")
  ts~charout(text)
  ts~close

  loadReport = .directory~new
  loadReport~put(self~nowIso, "time")
  loadReport~put("written", "status")
  loadReport~put(dir, "directory")
  loadReport~put(loaded, "rules_loaded")
  loadReport~put(jsonPath, "json_path")
  loadReport~put(textPath, "text_path")
  loadReport~put(reason, "reason")
  traceRequestLoadReports~append(loadReport)
  traceRequestReportActive = .false
  signal off syntax
  signal off notready
  return .true

reportTraceRequestFailed:
  ev = .directory~new
  ev~put(self~nowIso, "time")
  ev~put("failed", "status")
  ev~put(dir, "directory")
  ev~put(loaded, "rules_loaded")
  ev~put(reason, "reason")
  ev~put(condition("C"), "condition")
  ev~put(condition("D"), "description")
  traceRequestLoadReports~append(ev)
  self~addWarning("Trace request load report failed dir=" || dir || " condition=" || condition("C"))
  traceRequestReportActive = .false
  signal off syntax
  signal off notready
  return .false

::method traceRequestLoadText private
  use strict arg rep

  text = "Inspector Clouseau trace request load" || "0a"x
  text = text || "schema: " || rep~at("schema") || "0a"x
  text = text || "generated_at: " || rep~at("generated_at") || "0a"x
  text = text || "directory: " || rep~at("directory") || "0a"x
  text = text || "reason: " || rep~at("reason") || "0a"x
  text = text || "rules_loaded: " || rep~at("rules_loaded") || "0a"x
  text = text || "total_rule_count: " || rep~at("total_rule_count") || "0a"x
  ss = rep~at("scan_summary")
  if ss \== .nil then do
    text = text || "candidate_files: " || ss~at("candidate_files") || "0a"x
    text = text || "files_seen: " || ss~at("files_seen") || "0a"x
    text = text || "loaded_files: " || ss~at("loaded_files") || "0a"x
    text = text || "zero_rule_files: " || ss~at("zero_rule_files") || "0a"x
    text = text || "skipped_bad_name: " || ss~at("skipped_bad_name") || "0a"x
    text = text || "skipped_unchanged: " || ss~at("skipped_unchanged") || "0a"x
  end
  text = text || "0a"x || "Trace request events:" || "0a"x
  events = rep~at("trace_request_events")
  if events \== .nil then do
    do ev over events
      line = "  "
      val = ev~at("status"); if val \== .nil then line = line || val
      val = ev~at("rules_loaded"); if val \== .nil then line = line || " rules=" || val
      val = ev~at("path"); if val \== .nil then line = line || " path=" || val
      val = ev~at("condition"); if val \== .nil then line = line || " condition=" || val
      text = text || line || "0a"x
    end
  end
  return text
::method applyTraceRequestData public
  data = .nil
  defaultPrefix = "inspector-clouseau-trace-request"
  sourcePath = ""
  if arg() >= 1 then data = arg(1)
  if arg() >= 2 then defaultPrefix = arg(2)
  if arg() >= 3 then sourcePath = arg(3)
  if data == .nil then return 0

  count = 0
  signal on syntax name applyTraceDataFailed
  cName = self~safeClassName(data)~translate
  if cName~pos("ARRAY") > 0 then do
    do rec over data
      count = count + self~applyTraceRequestRecord(rec, defaultPrefix, sourcePath)
    end
    return count
  end
  reqs = data~at("requests")
  if reqs == .nil then reqs = data~at("trace_requests")
  if reqs \== .nil then do
    do rec over reqs
      self~inheritTraceBundleMetadata(data, rec)
      count = count + self~applyTraceRequestRecord(rec, defaultPrefix, sourcePath)
    end
    return count
  end
  return self~applyTraceRequestRecord(data, defaultPrefix, sourcePath)

applyTraceDataFailed:
  self~addWarning("Trace request data apply failed source=" || sourcePath || " condition=" || condition("C"))
  return count
::method inheritTraceBundleMetadata private
  use arg parent, rec
  if parent == .nil | rec == .nil then return .false
  signal on syntax name inheritTraceMetaDone
  keys = .array~of("trace_group", "bundle_id", "trace_goal", "path_from", "path_to", "planner", "planner_reason")
  do k over keys
    val = parent~at(k)
    if val \== .nil then do
      existing = rec~at(k)
      if existing == .nil then rec~put(val, k)
    end
  end
  bundleId = parent~at("bundle_id")
  if bundleId \== .nil then do
    traceGroup = rec~at("trace_group")
    if traceGroup == .nil then rec~put(bundleId, "trace_group")
  end
inheritTraceMetaDone:
  signal off syntax
  return .true
::method decorateTraceRuleFromRequest private
  use arg rule, request, sourcePath
  if rule == .nil | request == .nil then return rule
  signal on syntax name decorateTraceRuleDone
  keys = .array~of("trace_group", "bundle_id", "trace_goal", "trace_step", "trace_role", "path_from", "path_to", "planner", "planner_reason", "route_class", "route_object_path")
  do k over keys
    val = request~at(k)
    if val \== .nil then rule~put(val, k)
  end
  if sourcePath \= "" then rule~put(sourcePath, "trace_request_source")
  val = request~at("request_id")
  if val \== .nil then rule~put(val, "request_id")
  else do
    val = request~at("id")
    existing = rule~at("request_id")
    if val \== .nil then do
      if existing == .nil then rule~put(val, "request_id")
    end
  end
decorateTraceRuleDone:
  signal off syntax
  return rule
::method applyTraceRequestRecord private
  use strict arg rec, defaultPrefix, sourcePath

  if rec == .nil then return 0
  signal on syntax name applyTraceRecordFailed
  enabledText = translate(self~traceRequestText(rec, "enabled", "true"))
  if enabledText = "0" | enabledText = "FALSE" | enabledText = "NO" | enabledText = "OFF" then return 0

  kind = self~traceRequestText(rec, "kind", "")
  if kind = "" then kind = self~traceRequestText(rec, "type", "method_trace")
  kind = translate(kind)

  classPattern = self~traceRequestText(rec, "class", "")
  if classPattern = "" then classPattern = self~traceRequestText(rec, "class_pattern", "*")
  methodPattern = self~traceRequestText(rec, "method", "")
  if methodPattern = "" then methodPattern = self~traceRequestText(rec, "method_pattern", "*")
  signalName = self~traceRequestText(rec, "signal", "")
  if signalName = "" then signalName = self~traceRequestText(rec, "signal_pattern", "*")
  procedurePattern = self~traceRequestText(rec, "procedure", "")
  if procedurePattern = "" then procedurePattern = self~traceRequestText(rec, "procedure_pattern", "*")
  stopClass = self~traceRequestText(rec, "stop_class", "*")
  if stopClass = "" then stopClass = self~traceRequestText(rec, "stop_class_pattern", "*")
  stopMethod = self~traceRequestText(rec, "stop_method", "*")
  if stopMethod = "" then stopMethod = self~traceRequestText(rec, "stop_method_pattern", "*")
  condVar = self~traceRequestOptionalText(rec, "condition_variable")
  if condVar == .nil then condVar = self~traceRequestOptionalText(rec, "variable")
  condEq = self~traceRequestOptionalText(rec, "condition_equals")
  if condEq == .nil then condEq = self~traceRequestOptionalText(rec, "equals")
  prefix = self~traceRequestText(rec, "report_prefix", "")
  if prefix = "" then prefix = self~traceRequestText(rec, "prefix", "")
  if prefix = "" then prefix = defaultPrefix || "-" || self~safeToken(self~sourceNameToken(sourcePath))

  select
    when kind = "TRACE_ON_METHOD" | kind = "METHOD_TRACE" | kind = "TRACE_METHOD" | kind = "METHOD" | kind = "TRACE" then do
      rule = self~collectTraceOnMethod(classPattern, methodPattern, condVar, condEq, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "TRACE_ON_SIGNAL" | kind = "SIGNAL_TRACE" | kind = "TRACE_SIGNAL" | kind = "SIGNAL" then do
      rule = self~collectTraceOnSignal(classPattern, methodPattern, signalName, condVar, condEq, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "SOURCE_TRAIL" | kind = "PARENT_SOURCE_TRAIL" | kind = "METHOD_SOURCE_TRAIL" then do
      rule = self~reportParentSourceTrailOnMethod(classPattern, methodPattern, stopClass, stopMethod, condVar, condEq, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "METHOD_REPORT" | kind = "INSPECTION_ON_METHOD" | kind = "REPORT_ON_METHOD" then do
      rule = self~createInspectionReportOnMethod(classPattern, methodPattern, condVar, condEq, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "SIGNAL_REPORT" | kind = "INSPECTION_ON_SIGNAL" | kind = "REPORT_ON_SIGNAL" then do
      rule = self~createInspectionReportOnSignal(classPattern, methodPattern, signalName, condVar, condEq, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "RETURN_PROXY" | kind = "RETURN_TRANSFORM_PROXY" | kind = "PROXY_RETURN_TRANSFORM" | kind = "PROXY_METHOD_RETURN" then do
      rule = self~createReturnTransformProxyOnMethod(classPattern, methodPattern, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "UPSTREAM_DISPATCH_TRACE" | kind = "CALL_SITE_TRACE" | kind = "DISPATCH_TRACE" then do
      rule = self~planUpstreamDispatchTraceForMethod(classPattern, methodPattern, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "UNKNOWN_METHOD_TRIPWIRE" | kind = "UNKNOWN_TRIPWIRE" | kind = "MISSING_METHOD_TRIPWIRE" | kind = "UNKNOWN_METHOD" then do
      action = self~traceRequestText(rec, "action", "report")
      rule = self~createUnknownMethodTripwire(classPattern, prefix, action)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    when kind = "PROCEDURE_SIGNAL" | kind = "PROCEDURE_SIGNAL_REPORT" then do
      rule = self~createInspectionReportOnProcedureSignal(procedurePattern, signalName, prefix)
      self~decorateTraceRuleFromRequest(rule, rec, sourcePath)
      return 1
    end
    otherwise do
      self~addWarning("Unknown trace request kind=" || kind || " source=" || sourcePath)
      return 0
    end
  end

applyTraceRecordFailed:
  self~addWarning("Trace request record failed source=" || sourcePath || " condition=" || condition("C"))
  return 0

::method traceRequestText private
  use arg rec, key, defaultValue
  if defaultValue == .nil then defaultValue = ""
  signal on syntax name traceTextFailed
  v = rec~at(key)
  if v == .nil then return defaultValue
  return "" || v
traceTextFailed:
  return defaultValue
::method traceRequestOptionalText private
  use arg rec, key
  signal on syntax name traceOptFailed
  v = rec~at(key)
  if v == .nil then return .nil
  if "" || v = "" then return .nil
  return "" || v
traceOptFailed:
  return .nil
::method safeToken private
  use arg value
  txt = translate("" || value)
  out = ""
  do i = 1 to txt~length
    ch = txt~substr(i, 1)
    isAlpha = .false
    if ch >= "A" then do
      if ch <= "Z" then isAlpha = .true
    end
    isDigit = .false
    if ch >= "0" then do
      if ch <= "9" then isDigit = .true
    end
    if isAlpha then out = out || ch
    else if isDigit then out = out || ch
    else out = out || "-"
  end
  do while pos("--", out) > 0
    out = changestr("--", out, "-")
  end
  if out = "" then out = "REQUEST"
  return out

::method sourceNameToken private
  use arg path
  if path == .nil | path = "" then return "request"
  s = "" || path
  do while s~pos("/") > 0
    s = s~substr(s~pos("/") + 1)
  end
  if translate(right(s, 5)) = ".JSON" then s = left(s, s~length - 5)
  if s = "" then s = "request"
  return s

::method isHiddenName private
  use strict arg name
  if name = "" then return .true
  if left(name, 1) = "." then return .true
  if right(translate(name), 4) = ".TMP" then return .true
  return .false

::method refreshObjectWalkForNewRules private
  expose roots objectQueue walkedObjects
  walkedObjects = .identityTable~new
  objectQueue = .queue~new
  do r over roots
    obj = r~at("object")
    name = r~at("name")
    objectQueue~append(self~makeObjectWork(obj, "root:" || name, .nil, name, 0))
  end
  return objectQueue~items

::method announce public
  expose announcementEmitted
  hostName = "ooRexx runtime"
  phaseName = "startup"
  reportPrefix = "inspector-clouseau"
  if arg() >= 1 then hostName = arg(1)
  if arg() >= 2 then phaseName = arg(2)
  if arg() >= 3 then reportPrefix = arg(3)
  if hostName == .nil then hostName = "ooRexx runtime"
  if phaseName == .nil then phaseName = "startup"
  if reportPrefix == .nil then reportPrefix = "inspector-clouseau"

  if announcementEmitted then return .false
  if \self~announcementAllowed then return .false

  announcementEmitted = .true
  say self~announcementLine(hostName, phaseName, reportPrefix)
  return .true

::method announcementLine public
  hostName = "ooRexx runtime"
  phaseName = "startup"
  reportPrefix = "inspector-clouseau"
  if arg() >= 1 then hostName = arg(1)
  if arg() >= 2 then phaseName = arg(2)
  if arg() >= 3 then reportPrefix = arg(3)
  return "[INSPECTOR CLOUSEAU] Bonjour. Inspector Clouseau is on the case. host=" || hostName || " phase=" || phaseName || " reports=" || reportPrefix

::method announcementAllowed public
  flag = translate(value("INSPECTOR_CLOUSEAU_QUIET",, "ENVIRONMENT"))
  if flag = "1" | flag = "TRUE" | flag = "YES" | flag = "ON" then return .false

  flag = translate(value("ALCHEMY_INSPECTOR_QUIET",, "ENVIRONMENT"))
  if flag = "1" | flag = "TRUE" | flag = "YES" | flag = "ON" then return .false

  flag = translate(value("INSPECTOR_CLOUSEAU_ANNOUNCE",, "ENVIRONMENT"))
  if flag = "0" | flag = "FALSE" | flag = "NO" | flag = "OFF" then return .false

  flag = translate(value("ALCHEMY_INSPECTOR_ANNOUNCE",, "ENVIRONMENT"))
  if flag = "0" | flag = "FALSE" | flag = "NO" | flag = "OFF" then return .false

  return .true

::method attach public
  expose automaticRootsSeeded
  rootName = "attached"
  rootObject = .nil
  if arg() = 1 then rootObject = arg(1)
  else do
    if arg() >= 1 then rootName = arg(1)
    if arg() >= 2 then rootObject = arg(2)
  end
  if rootName == .nil | rootName = "" then rootName = "attached"
  if rootObject == .nil then return self

  self~addRoot(rootName, rootObject)
  if \automaticRootsSeeded then do
    self~seedAutomaticRoots
    automaticRootsSeeded = .true
  end
  return self

::method enableProbes
  expose enableInjectedProbes
  use arg enabled

  if arg() = 0 then enabled = .true
  enableInjectedProbes = enabled
  return self

::method addRule
  expose rules
  use arg kind, pattern, value, options

  rec = .directory~new
  if arg() = 1 & self~safeClassName(kind)~translate~pos("DIRECTORY") > 0 then do
    do idx over self~safeIndexes(kind)
      rec~put(kind~at(idx), idx)
    end
    existing = rec~at("enabled")
    if existing == .nil then rec~put(.true, "enabled")
    existing = rec~at("kind")
    if existing == .nil then rec~put("custom", "kind")
  end
  else do
    rec~put(self~safeString(kind)~translate, "kind")
    if arg() >= 2 then rec~put(pattern, "pattern")
    else rec~put("*", "pattern")
    if arg() >= 3 then rec~put(value, "value")
    else rec~put(.true, "value")
    if arg() >= 4 then rec~put(options, "options")
    rec~put(.true, "enabled")
  end

  rules~append(rec)
  return rec
::method dontFollowPackage
  use strict arg pattern
  return self~addRule("DONT_FOLLOW_PACKAGE", pattern, .true)

::method reportQueueItems
  use arg enabled
  if arg() = 0 then enabled = .true
  return self~addRule("REPORT_QUEUE_ITEMS", "*", enabled)

::method reportCollectionSizes
  use arg enabled
  if arg() = 0 then enabled = .true
  return self~addRule("REPORT_COLLECTION_SIZES", "*", enabled)

::method reportCollectionItems
  use arg enabled
  if arg() = 0 then enabled = .true
  return self~addRule("REPORT_COLLECTION_ITEMS", "*", enabled)

::method reportVariable
  use arg pattern
  if arg() = 0 then pattern = "*"
  return self~addRule("REPORT_VARIABLE", pattern, .true)

::method reportVariables
  use arg pattern
  if arg() = 0 then pattern = "*"
  return self~reportVariable(pattern)

::method reportInheritanceMap
  use arg enabled
  if arg() = 0 then enabled = .true
  return self~addRule("REPORT_INHERITANCE_MAP", "*", enabled)

::method reportClassInheritanceMap
  forward message("REPORTINHERITANCEMAP")

::method mapInheritance
  forward message("REPORTINHERITANCEMAP")

::method createInspectionReportOnSignal
  use arg classPattern, methodPattern, signalName, conditionVariable, conditionEquals, reportPrefix

  if arg() < 1 then classPattern = "*"
  if arg() < 2 then methodPattern = "*"
  if arg() < 3 then signalName = "*"

  rec = .directory~new
  rec~put("TRIGGER_INSPECTION_ON_SIGNAL", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(signalName, "signal_pattern")
  rec~put(classPattern || "::" || methodPattern || "::" || signalName, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  rec~put(.true, "capture_source_trail")
  rec~put(12, "max_stack_frames")
  rec~put(4, "source_radius")

  if arg() >= 4 then do
    if conditionVariable \== .nil then rec~put(conditionVariable, "condition_variable")
  end
  if arg() >= 5 then do
    if conditionEquals \== .nil then do
      rec~put(conditionEquals, "condition_equals")
      rec~put(.true, "condition_has_equals")
    end
  end
  if arg() >= 6 then rec~put(reportPrefix, "report_prefix")
  if \rec~hasIndex("report_prefix") then rec~put("inspector-clouseau-signal", "report_prefix")

  return self~addRule(rec)

::method createInspectionReportWhenSignalFires
  forward message("CREATEINSPECTIONREPORTONSIGNAL")

::method reportWhenSignalFires
  forward message("CREATEINSPECTIONREPORTONSIGNAL")

::method createInspectionReportOnProcedureSignal
  use arg procedurePattern, signalName, reportPrefix

  if arg() < 1 then procedurePattern = "*"
  if arg() < 2 then signalName = "*"

  rec = .directory~new
  rec~put("TRIGGER_INSPECTION_ON_PROCEDURE_SIGNAL", "kind")
  rec~put(procedurePattern, "procedure_pattern")
  rec~put(signalName, "signal_pattern")
  rec~put(procedurePattern || "::" || signalName, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  if arg() >= 3 then rec~put(reportPrefix, "report_prefix")
  if \rec~hasIndex("report_prefix") then rec~put("inspector-clouseau-procedure-signal", "report_prefix")
  return self~addRule(rec)

::method reportWhenProcedureSignalFires
  forward message("CREATEINSPECTIONREPORTONPROCEDURESIGNAL")

::method createInspectionReportOnMethod
  use arg classPattern, methodPattern, conditionVariable, conditionEquals, reportPrefix

  if arg() < 1 then classPattern = "*"
  if arg() < 2 then methodPattern = "*"

  rec = .directory~new
  rec~put("TRIGGER_INSPECTION_ON_METHOD", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(classPattern || "::" || methodPattern, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put("before", "timing")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")

  if arg() >= 3 then do
    if conditionVariable \== .nil then do
      if self~safeClassName(conditionVariable)~translate~pos("DIRECTORY") > 0 then do
        val = conditionVariable~at("variable"); if val \== .nil then rec~put(val, "condition_variable")
        val = conditionVariable~at("equals")
        if val \== .nil then do
          rec~put(val, "condition_equals")
          rec~put(.true, "condition_has_equals")
        end
        val = conditionVariable~at("report_prefix"); if val \== .nil then rec~put(val, "report_prefix")
        val = conditionVariable~at("prefix"); if val \== .nil then rec~put(val, "report_prefix")
        val = conditionVariable~at("write_json"); if val \== .nil then rec~put(val, "write_json")
        val = conditionVariable~at("write_text"); if val \== .nil then rec~put(val, "write_text")
        val = conditionVariable~at("capture_source_trail"); if val \== .nil then rec~put(val, "capture_source_trail")
        val = conditionVariable~at("stop_class"); if val \== .nil then rec~put(val, "stop_class_pattern")
        val = conditionVariable~at("stop_method"); if val \== .nil then rec~put(val, "stop_method_pattern")
        val = conditionVariable~at("stop_class_pattern"); if val \== .nil then rec~put(val, "stop_class_pattern")
        val = conditionVariable~at("stop_method_pattern"); if val \== .nil then rec~put(val, "stop_method_pattern")
        val = conditionVariable~at("max_stack_frames"); if val \== .nil then rec~put(val, "max_stack_frames")
        val = conditionVariable~at("source_radius"); if val \== .nil then rec~put(val, "source_radius")
      end
      else rec~put(conditionVariable, "condition_variable")
    end
  end
  if arg() >= 4 then do
    if conditionEquals \== .nil then do
      rec~put(conditionEquals, "condition_equals")
      rec~put(.true, "condition_has_equals")
    end
  end
  if arg() >= 5 then do
    if reportPrefix \== .nil then rec~put(reportPrefix, "report_prefix")
  end

  self~addRule(rec)
  return rec
::method createInspectionReportWhenMethodRuns
  forward message("CREATEINSPECTIONREPORTONMETHOD")

::method reportWhenMethodRuns
  forward message("CREATEINSPECTIONREPORTONMETHOD")


::method collectTraceOnMethod
  use arg classPattern, methodPattern, conditionVariable, conditionEquals, reportPrefix
  if arg() < 1 then classPattern = "*"
  if arg() < 2 then methodPattern = "*"
  rec = .directory~new
  rec~put("TRACE_ON_METHOD", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(classPattern || "::" || methodPattern, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put(.true, "collect_trace")
  rec~put("R", "trace_setting")
  rec~put("S", "trace_object_option")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  if arg() >= 3 then do
    if conditionVariable \== .nil then rec~put(conditionVariable, "condition_variable")
  end
  if arg() >= 4 then do
    if conditionEquals \== .nil then do
      rec~put(conditionEquals, "condition_equals")
      rec~put(.true, "condition_has_equals")
    end
  end
  if arg() >= 5 then rec~put(reportPrefix, "report_prefix")
  if \rec~hasIndex("report_prefix") then rec~put("inspector-clouseau-trace", "report_prefix")
  return self~addRule(rec)

::method traceMethod
  forward message("COLLECTTRACEONMETHOD")

::method useMagnifyingGlassOnMethod
  forward message("COLLECTTRACEONMETHOD")

::method collectTraceOnSignal
  use arg classPattern, methodPattern, signalName, conditionVariable, conditionEquals, reportPrefix
  if arg() < 1 then classPattern = "*"
  if arg() < 2 then methodPattern = "*"
  if arg() < 3 then signalName = "*"
  rec = .directory~new
  rec~put("TRACE_ON_SIGNAL", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(signalName, "signal_pattern")
  rec~put(classPattern || "::" || methodPattern || "::" || signalName, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put(.true, "collect_trace")
  rec~put("R", "trace_setting")
  rec~put("S", "trace_object_option")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  rec~put(.true, "capture_source_trail")
  if arg() >= 4 then do
    if conditionVariable \== .nil then rec~put(conditionVariable, "condition_variable")
  end
  if arg() >= 5 then do
    if conditionEquals \== .nil then do
      rec~put(conditionEquals, "condition_equals")
      rec~put(.true, "condition_has_equals")
    end
  end
  if arg() >= 6 then rec~put(reportPrefix, "report_prefix")
  if \rec~hasIndex("report_prefix") then rec~put("inspector-clouseau-signal-trace", "report_prefix")
  return self~addRule(rec)

::method traceSignal
  forward message("COLLECTTRACEONSIGNAL")

::method useMagnifyingGlassOnSignal
  forward message("COLLECTTRACEONSIGNAL")

::method reportParentSourceTrailOnMethod
  use arg classPattern, methodPattern, stopClassPattern, stopMethodPattern, conditionVariable, conditionEquals, reportPrefix

  if arg() < 1 then classPattern = "*"
  if arg() < 2 then methodPattern = "*"
  if arg() < 3 then stopClassPattern = "*"
  if arg() < 4 then stopMethodPattern = "*"

  rec = .directory~new
  rec~put("TRIGGER_SOURCE_TRAIL_ON_METHOD", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(classPattern || "::" || methodPattern, "pattern")
  rec~put(.true, "value")
  rec~put(.true, "enabled")
  rec~put("before", "timing")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  rec~put(.true, "capture_source_trail")
  rec~put(stopClassPattern, "stop_class_pattern")
  rec~put(stopMethodPattern, "stop_method_pattern")
  rec~put(12, "max_stack_frames")
  rec~put(4, "source_radius")

  if arg() >= 5 then do
    if conditionVariable \== .nil then rec~put(conditionVariable, "condition_variable")
  end
  if arg() >= 6 then do
    if conditionEquals \== .nil then do
      rec~put(conditionEquals, "condition_equals")
      rec~put(.true, "condition_has_equals")
    end
  end
  if arg() >= 7 then rec~put(reportPrefix, "report_prefix")
  if \rec~hasIndex("report_prefix") then rec~put("inspector-clouseau-source-trail", "report_prefix")

  return self~addRule(rec)

::method createParentSourceInspectionReportOnMethod
  forward message("REPORTPARENTSOURCETRAILONMETHOD")

::method createMethodParentSourceInspectionReportOnMethod
  forward message("REPORTPARENTSOURCETRAILONMETHOD")

::method reportExecutionTreeOnMethod
  forward message("REPORTPARENTSOURCETRAILONMETHOD")

::method createReturnTransformProxyOnMethod public
  classPattern = "*"
  methodPattern = "*"
  reportPrefix = "inspector-clouseau-return-proxy"
  if arg() >= 1 then classPattern = arg(1)
  if arg() >= 2 then methodPattern = arg(2)
  if arg() >= 3 then reportPrefix = arg(3)
  rec = .directory~new
  rec~put(.true, "enabled")
  rec~put("RETURN_TRANSFORM_PROXY", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(reportPrefix, "report_prefix")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  rec~put(.true, "write_report")
  rec~put("source-required inline return transform proxy", "purpose")
  return self~addRule(rec)

::method proxyReturnTransformOnMethod public
  forward message("CREATERETURNTRANSFORMPROXYONMETHOD")

::method proxyReturnOnMethod public
  forward message("CREATERETURNTRANSFORMPROXYONMETHOD")

::method inspectReturnTransformOnMethod public
  forward message("CREATERETURNTRANSFORMPROXYONMETHOD")

::method planUpstreamDispatchTraceForMethod public
  classPattern = "*"
  methodPattern = "*"
  reportPrefix = "inspector-clouseau-upstream-dispatch"
  if arg() >= 1 then classPattern = arg(1)
  if arg() >= 2 then methodPattern = arg(2)
  if arg() >= 3 then reportPrefix = arg(3)
  rec = .directory~new
  rec~put(.true, "enabled")
  rec~put("UPSTREAM_DISPATCH_TRACE", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put(methodPattern, "method_pattern")
  rec~put(reportPrefix, "report_prefix")
  rec~put("planning-only fallback for source-unavailable/forward return proxy cases", "purpose")
  return self~addRule(rec)

::method createUnknownMethodTripwire public
  classPattern = "*"
  reportPrefix = "inspector-clouseau-unknown-method"
  action = "report"
  if arg() >= 1 then classPattern = arg(1)
  if arg() >= 2 then reportPrefix = arg(2)
  if arg() >= 3 then action = arg(3)
  if classPattern == .nil | classPattern = "" then classPattern = "*"
  if reportPrefix == .nil | reportPrefix = "" then reportPrefix = "inspector-clouseau-unknown-method"
  if action == .nil | action = "" then action = "report"
  rec = .directory~new
  rec~put(.true, "enabled")
  rec~put("UNKNOWN_METHOD_TRIPWIRE", "kind")
  rec~put(classPattern, "class_pattern")
  rec~put("UNKNOWN", "method_pattern")
  rec~put(reportPrefix, "report_prefix")
  rec~put(action, "unknown_action")
  rec~put(.true, "write_json")
  rec~put(.true, "write_text")
  rec~put(.true, "write_report")
  rec~put("records non-existent method dispatch via ooRexx UNKNOWN", "purpose")
  return self~addRule(rec)

::method reportUnknownMethodsForClass public
  forward message("CREATEUNKNOWNMETHODTRIPWIRE")

::method trapUnknownMethods public
  forward message("CREATEUNKNOWNMETHODTRIPWIRE")

::method suppressInternalClassMethods
  use arg enabled
  if arg() = 0 then enabled = .true
  return self~addRule("SUPPRESS_INTERNAL_CLASS_METHODS", "*", enabled)

::method suppressMethodOutputForClass
  use arg pattern, enabled
  if arg() = 0 then pattern = "*"
  if arg() < 2 then enabled = .true
  return self~addRule("SUPPRESS_METHOD_OUTPUT_FOR_CLASS", pattern, enabled)

::method suppressMethodOutput
  use arg pattern, enabled
  if arg() = 0 then pattern = "*"
  if arg() < 2 then enabled = .true
  return self~addRule("SUPPRESS_METHOD_OUTPUT", pattern, enabled)

::method suppressObjectOutputForPath
  use arg pattern, enabled
  if arg() = 0 then pattern = "*"
  if arg() < 2 then enabled = .true
  return self~addRule("SUPPRESS_OBJECT_OUTPUT_FOR_PATH", pattern, enabled)

::method dontFollowObjectPath
  use strict arg pattern
  return self~addRule("DONT_FOLLOW_OBJECT_PATH", pattern, .true)

::method dontFollowPath
  use strict arg pattern
  return self~dontFollowObjectPath(pattern)

::method ruleEnabled private
  expose rules
  use strict arg kind, candidate = "*"

  upperKind = self~safeString(kind)~translate
  result = .false
  do rule over rules
    enabled = rule~at("enabled")
    if enabled \== .true then iterate
    ruleKind = rule~at("kind")
    if ruleKind == .nil then iterate
    if self~safeString(ruleKind)~translate \= upperKind then iterate
    pattern = rule~at("pattern")
    if pattern == .nil then pattern = "*"
    if self~rulePatternMatches(pattern, candidate) then do
      val = rule~at("value")
      if val \== .nil then result = self~safeLogical(val)
      else result = .true
    end
  end
  return result
::method rulePatternMatches private
  use strict arg pattern, candidate

  p = self~safeString(pattern)~translate
  c = self~safeString(candidate)~translate
  if p = "" then return .false
  if p = "*" then return .true
  if p = c then return .true
  if p~left(1) = "*" & p~right(1) = "*" then do
    inner = p~substr(2, p~length - 2)
    if inner = "" then return .true
    return c~pos(inner) > 0
  end
  if p~left(1) = "*" then do
    suffix = p~substr(2)
    return c~right(suffix~length) = suffix
  end
  if p~right(1) = "*" then do
    prefix = p~left(p~length - 1)
    return c~left(prefix~length) = prefix
  end
  return c~pos(p) > 0

::method shouldSkipPackageByRule private
  use strict arg pkg

  ident = self~packageIdentity(pkg)
  if self~ruleEnabled("DONT_FOLLOW_PACKAGE", ident) then return .true
  name = self~safeString(self~safeSend0(pkg, "name", ""))
  if self~ruleEnabled("DONT_FOLLOW_PACKAGE", name) then return .true
  path = self~safeString(self~safeSend0(pkg, "path", ""))
  if self~ruleEnabled("DONT_FOLLOW_PACKAGE", path) then return .true
  return .false

::method addRoot
  expose roots objectQueue
  use strict arg name, obj

  rec = .directory~new
  rec~put(name, "name")
  rec~put(obj, "object")
  roots~append(rec)
  objectQueue~append(self~makeObjectWork(obj, "root:" || name, .nil, name, 0))
  return self

::method addPackage
  expose packageQueue
  use strict arg pkg

  if pkg == .nil then return self
  packageQueue~append(pkg)
  return self

::method seedAutomaticRoots
  self~addPackage(.context~package)
  self~addRoot(".environment", .environment)
  self~addRoot(".local", .local)
  self~addRoot(".context", .context)
  return self

::method snapshot
  expose packageQueue objectQueue inheritanceMaps

  self~loadConfiguredTraceRequests
  self~closePackageUniverse
  self~walkObjectUniverse
  self~detectIdentityFindings
  inheritanceMaps = self~buildInheritanceMaps
  return .InspectorSnapshot~new(self~asDirectory)

::method asDirectory
  expose roots packages objects edges queues classes methods findings warnings opaqueMethods classSlots rules variableReports triggerEvents callChainReports traceReports inheritanceMaps securityEvents traceRequestEvents traceRequestLoadReports traceRequestLastSummary scheduledSnapshotEvents returnProxyEvents unknownMethodEvents

  d = .directory~new
  d~put(self~SCHEMA, "schema")
  d~put(self~nowIso, "generated_at")
  d~put(self~rootsAsArray, "roots")
  d~put(packages, "packages")
  d~put(self~directoryValues(objects), "objects")
  d~put(edges, "edges")
  d~put(queues, "queues")
  d~put(self~directoryValues(classes), "classes")
  d~put(methods, "methods")
  d~put(opaqueMethods, "opaque_methods")
  d~put(classSlots, "class_slots")
  d~put(rules, "rules")
  d~put(variableReports, "variable_reports")
  d~put(triggerEvents, "trigger_events")
  d~put(callChainReports, "call_chain_reports")
  d~put(traceReports, "trace_reports")
  d~put(inheritanceMaps, "inheritance_maps")
  d~put(securityEvents, "security_events")
  d~put(traceRequestEvents, "trace_request_events")
  d~put(traceRequestLoadReports, "trace_request_load_reports")
  d~put(traceRequestLastSummary, "trace_request_last_summary")
  d~put(scheduledSnapshotEvents, "scheduled_snapshot_events")
  d~put(returnProxyEvents, "return_proxy_events")
  d~put(unknownMethodEvents, "unknown_method_events")
  d~put(findings, "findings")
  d~put(warnings, "warnings")
  return d


::method recordSecurityEvent public
  expose securityEvents triggerCounter
  event = .directory~new
  triggerCounter = triggerCounter + 1
  event~put(triggerCounter, "sequence")
  event~put(self~nowIso, "time")
  event~put("security_manager", "kind")
  if arg() >= 1 then event~put(arg(1), "manager")
  if arg() >= 2 then event~put(arg(2), "operation")
  if arg() >= 3 then event~put(arg(3), "action")
  if arg() >= 4 then event~put(arg(4), "reason")
  if arg() >= 5 then event~put(arg(5), "evidence")
  securityEvents~append(event)
  return event

::method writeSecurityReport public
  event = .nil
  prefix = "inspector-clouseau-security"
  if arg() >= 1 then event = arg(1)
  if arg() >= 2 then prefix = arg(2)
  if prefix == .nil | prefix = "" then prefix = "inspector-clouseau-security"
  signal on syntax name writeSecurityDone
  snap = .InspectorSnapshot~new(self~asDirectory)
  seq = "0"
  if event \== .nil then do
    val = event~at("sequence")
    if val \== .nil then seq = val
  end
  base = prefix || "-" || seq
  snap~writeJson(base || ".json")
  snap~writeText(base || ".txt")
  return base
writeSecurityDone:
  return ""
::method rootsAsArray private
  expose roots visitedObjects

  out = .array~new
  do r over roots
    obj = r~at("object")
    rec = .directory~new
    rec~put(r~at("name"), "name")
    rec~put(self~oidFor(obj), "oid")
    rec~put(self~safeClassName(obj), "class")
    out~append(rec)
  end
  return out

::method closePackageUniverse private
  expose packageQueue visitedPackages packages

  do while packageQueue~items > 0
    pkg = packageQueue~pull
    if pkg == .nil then iterate
    if self~isOwnPackage(pkg) then iterate
    if self~shouldSkipPackageByRule(pkg) then do
      self~addWarning("Package skipped by rule: " || self~packageIdentity(pkg))
      iterate
    end
    if visitedPackages~hasIndex(pkg) then iterate

    visitedPackages~put(.true, pkg)
    self~inspectPackage(pkg)
  end

::method inspectPackage private
  expose packages packageQueue
  use strict arg pkg

  rec = .directory~new
  rec~put(self~safeString(self~safeSend0(pkg, "name", "")), "name")
  rec~put(self~safeString(self~safeSend0(pkg, "path", "")), "path")
  rec~put(self~safeString(self~safeSend0(pkg, "sourceSize", 0)), "source_size")
  rec~put(self~packageIdentity(pkg), "package_identity")

  classesArray = .array~new
  pkgClasses = self~safeSend0(pkg, "classes", .nil)
  if pkgClasses \== .nil then do
    do cname over self~safeIndexes(pkgClasses)
      cls = self~safeAt(pkgClasses, cname, .nil)
      if cls \== .nil then do
        classesArray~append(self~safeString(cname))
        self~inspectClass(cls, pkg)
      end
    end
  end
  rec~put(classesArray, "classes")

  routinesArray = .array~new
  routines = self~safeSend0(pkg, "routines", .nil)
  if routines \== .nil then do
    do rname over self~safeIndexes(routines)
      routineObj = self~safeAt(routines, rname, .nil)
      routinesArray~append(self~safeString(rname))
      if routineObj \== .nil then self~inspectProcedure(rname, routineObj, pkg)
    end
  end
  rec~put(routinesArray, "routines")

  definedArray = .array~new
  defined = self~safeSend0(pkg, "definedMethods", .nil)
  if defined \== .nil then do
    do dname over self~safeIndexes(defined)
      dm = self~safeAt(defined, dname, .nil)
      definedArray~append(self~safeString(dname))
      self~inspectMethod(.nil, "<package-defined>", dname, dm, pkg)
    end
  end
  rec~put(definedArray, "defined_methods")

  reqArray = .array~new
  reqs = self~safeSend0(pkg, "requires", .nil)
  if reqs \== .nil then do
    do req over self~safeIterable(reqs)
      reqRec = .directory~new
      reqRec~put(self~safeString(self~safeSend0(req, "name", "")), "name")
      reqRec~put(self~safeString(self~safeSend0(req, "path", "")), "path")
      reqArray~append(reqRec)
      packageQueue~append(req)
    end
  end
  rec~put(reqArray, "requires")

  importsArray = .array~new
  imported = self~safeSend0(pkg, "importedPackages", .nil)
  if imported \== .nil then do
    do ipkg over self~safeIterable(imported)
      importsArray~append(self~packageIdentity(ipkg))
      packageQueue~append(ipkg)
    end
  end
  rec~put(importsArray, "imported_packages")

  rec~put(self~scanRequiresFromSource(pkg), "requires_from_source")
  packages~append(rec)

::method inspectProcedure private
  expose methods opaqueMethods
  use strict arg rname, routineObj, pkg

  rec = .directory~new
  rec~put("procedure", "record_kind")
  rec~put("<procedure>", "class")
  rec~put(self~safeString(rname), "method")
  rec~put(self~safeString(rname), "procedure")
  rec~put(self~packageIdentity(pkg), "package")
  rec~put(.false, "guarded")
  rec~put(.false, "private")
  rec~put(.false, "protected")

  origin = .directory~new
  origin~put("procedure_declared", "kind")
  origin~put("<procedure>", "from_class")
  origin~put("package_routine", "from_relation")
  origin~put(self~packageIdentity(pkg), "from_package")
  origin~put("package routines collection", "evidence")
  origin~put(.array~new, "inherited_by_subclasses")
  rec~put(origin, "origin")
  rec~put("procedure_declared", "origin_kind")
  rec~put("<procedure>", "origin_from_class")
  rec~put("package_routine", "origin_from_relation")
  rec~put(self~packageIdentity(pkg), "origin_from_package")

  sourceLines = self~sourceLinesForMethod(routineObj)
  if sourceLines == .nil then do
    rec~put(.false, "source_available")
    rec~put(.true, "terminal")
    rec~put("source_unavailable_unknown", "opaque_reason")
    rec~put(self~classifyByName(rname), "classification")
    rec~put(self~unknownSignalProfile, "signal_profile")
    opaqueMethods~append(rec)
  end
  else do
    rec~put(.true, "source_available")
    rec~put(.false, "terminal")
    rec~put(sourceLines~items, "source_line_count")
    signalProfile = self~scanSignals(sourceLines)
    rec~put(signalProfile, "signal_profile")
    rec~put(self~signalNamesFromProfile(signalProfile), "signal_names")
    rec~put(self~classifyMethodSource(rname, sourceLines, signalProfile), "classification")
    self~recordProcedureSignalRuleMatches(rec, signalProfile)
  end

  methods~append(rec)

::method inspectClass private
  expose visitedClasses classes methods packageQueue classSlots
  use strict arg cls, pkg

  if cls == .nil then return
  if self~isInspectorClass(cls) then return
  if visitedClasses~hasIndex(cls) then return
  visitedClasses~put(.true, cls)

  cname = self~safeClassId(cls)
  crec = .directory~new
  crec~put(cname, "name")
  crec~put(self~packageIdentity(pkg), "package")
  crec~put(self~safeString(self~safeSend0(cls, "id", cname)), "id")
  crec~put(self~safeString(self~safeSend0(self~safeSend0(cls, "superClass", .nil), "id", "")), "super_class")
  crec~put(self~namesFromClassCollection(self~safeSend0(cls, "superClasses", .nil)), "super_classes")
  crec~put(self~namesFromClassCollection(self~safeSend0(cls, "subclasses", .nil)), "subclasses")

  methodArray = .array~new
  methodMap = self~safeSend0(cls, "methods", .nil)
  if methodMap \== .nil then do
    do mname over self~safeIndexes(methodMap)
      if self~isProbeName(mname) then iterate
      m = self~safeAt(methodMap, mname, .nil)
      if m == .nil then m = self~safeMethodLookup(cls, mname)
      methodArray~append(self~safeString(mname))
      self~inspectMethod(cls, cname, mname, m, pkg)
    end
  end
  crec~put(methodArray, "methods")

  inferredSlots = self~inferClassSlots(cls, methodMap)
  crec~put(inferredSlots, "inferred_slots")
  classSlots~put(inferredSlots, cname)

  classes~put(crec, cname)

::method inspectMethod private
  expose methods opaqueMethods packageQueue
  use strict arg cls, cname, mname, methodObj, pkg

  methodPkg = self~safeSend0(methodObj, "package", .nil)
  if pkg == .nil then pkg = methodPkg
  if methodPkg \== .nil then packageQueue~append(methodPkg)

  rec = .directory~new
  rec~put(cname, "class")
  rec~put(self~safeString(mname), "method")
  rec~put(self~packageIdentity(pkg), "package")
  rec~put(self~safeLogical(self~safeSend0(methodObj, "isGuarded", .false)), "guarded")
  rec~put(self~safeLogical(self~safeSend0(methodObj, "isPrivate", .false)), "private")
  rec~put(self~safeLogical(self~safeSend0(methodObj, "isProtected", .false)), "protected")

  origin = self~methodOriginFor(cls, cname, mname, methodObj)
  rec~put(origin, "origin")
  if origin~hasIndex("kind") then rec~put(origin~at("kind"), "origin_kind")
  if origin~hasIndex("from_class") then rec~put(origin~at("from_class"), "origin_from_class")
  if origin~hasIndex("from_relation") then rec~put(origin~at("from_relation"), "origin_from_relation")
  if origin~hasIndex("from_package") then rec~put(origin~at("from_package"), "origin_from_package")

  sourceLines = self~sourceLinesForMethod(methodObj)
  if sourceLines == .nil then do
    rec~put(.false, "source_available")
    rec~put(.true, "terminal")
    rec~put("source_unavailable_unknown", "opaque_reason")
    rec~put(self~classifyByName(mname), "classification")
    rec~put(self~unknownSignalProfile, "signal_profile")
    opaqueMethods~append(rec)
  end
  else do
    rec~put(.true, "source_available")
    rec~put(.false, "terminal")
    rec~put(sourceLines~items, "source_line_count")
    signalProfile = self~scanSignals(sourceLines)
    rec~put(signalProfile, "signal_profile")
    rec~put(self~signalNamesFromProfile(signalProfile), "signal_names")
    rec~put(self~classifyMethodSource(mname, sourceLines, signalProfile), "classification")
    rt = self~returnTransformEvidence(sourceLines)
    rec~put(rt, "return_transform")
    if rt~hasIndex("matched") then do
      if rt~at("matched") == .true then rec~put(.true, "return_transform_candidate")
    end
  end

  methods~append(rec)

::method walkObjectUniverse private
  expose objectQueue

  do while objectQueue~items > 0
    work = objectQueue~pull
    if work == .nil then iterate
    self~walkObject(work)
  end

::method makeObjectWork private
  use strict arg obj, path, parentOid, edgeName, depth

  d = .directory~new
  d~put(obj, "object")
  d~put(path, "path")
  d~put(parentOid, "parent_oid")
  d~put(edgeName, "edge")
  d~put(depth, "depth")
  return d

::method walkObject private
  expose visitedObjects walkedObjects objects objectQueue edges packageQueue
  use strict arg work

  if work == .nil then return
  if self~safeClassName(work)~translate~pos("DIRECTORY") = 0 then do
    self~addWarning("Object walker skipped malformed work item of class " || self~safeClassName(work))
    return
  end

  obj = work~at("object")
  if obj == .nil then return

  path = work~at("path")
  if self~ruleEnabled("DONT_FOLLOW_OBJECT_PATH", path) then return
  parentOid = work~at("parent_oid")
  edgeName = work~at("edge")
  depth = work~at("depth")

  if self~shouldSkipObject(obj) then do
    self~addEdge(parentOid, "SKIPPED", edgeName, path, "skipped_self_or_examiner")
    return
  end

  oid = self~oidFor(obj)
  if parentOid \== .nil then self~addEdge(parentOid, oid, edgeName, path, "reference")

  if walkedObjects~hasIndex(obj) then return
  walkedObjects~put(.true, obj)

  node = .directory~new
  node~put(oid, "oid")
  node~put(path, "path")
  node~put(self~safeClassName(obj), "class")
  node~put(self~safeString(self~safeSend0(obj, "objectName", "")), "object_name")
  node~put(self~safeString(self~safeSend0(obj, "identityHash", "")), "identity_hash")
  node~put(self~objectKind(obj), "kind")
  node~put(depth, "depth")

  cls = self~safeSend0(obj, "class", .nil)
  if cls \== .nil then self~inspectClass(cls, .nil)

  if self~isCollectionLike(obj) then node~put(self~inspectCollection(obj, oid, path, depth), "collection")

  probe = self~installProbeForObject(obj, oid, path)
  if probe \== .nil then node~put(probe, "probe")

  triggerInstall = self~installMethodTriggersForObject(obj, oid, path)
  if triggerInstall~items > 0 then node~put(triggerInstall, "method_triggers")

  objects~put(node, oid)

  if depth >= self~MAX_DEPTH then do
    self~addWarning("Maximum object walk depth reached at " || path)
    return
  end

  if node~hasIndex("probe") then self~enqueueProbeChildren(node~at("probe"), oid, path, depth + 1)

  if self~isCollectionLike(obj) then self~enqueueCollectionChildren(obj, oid, path, depth + 1)
  else self~enqueueKnownInstanceRegistries(obj, oid, path, depth + 1)

::method enqueueKnownInstanceRegistries private
  expose objectQueue
  use strict arg obj, parentOid, path, depth

  cls = self~safeSend0(obj, "class", .nil)
  if cls == .nil then return

  reg = self~safeSend0(cls, "registry", .nil)
  if reg == .nil then reg = self~safeSend0(cls, "instances", .nil)
  if reg == .nil then return
  if \self~isCollectionLike(reg) then return

  objectQueue~append(self~makeObjectWork(reg, path || ".<class-registry>", parentOid, "class-registry", depth))

::method enqueueCollectionChildren private
  expose objectQueue
  use strict arg obj, parentOid, path, depth

  count = 0
  do idx over self~safeIndexes(obj)
    count = count + 1
    if count > self~MAX_COLLECTION_SAMPLE then leave
    child = self~safeAt(obj, idx, .nil)
    if child \== .nil then objectQueue~append(self~makeObjectWork(child, path || "[" || self~safeString(idx) || "]", parentOid, self~safeString(idx), depth))
  end

::method inspectCollection private
  expose queues
  use strict arg obj, oid, path, depth

  rec = .directory~new
  kind = self~objectKind(obj)
  itemCount = self~safeString(self~safeSend0(obj, "items", 0))

  if self~ruleEnabled("REPORT_COLLECTION_SIZES", path) then do
    rec~put(itemCount, "items")
    rec~put(self~safeLogical(self~safeSend0(obj, "isEmpty", .false)), "is_empty")
  end

  contents = .array~new
  reportContents = .false
  if kind = "queue" & self~ruleEnabled("REPORT_QUEUE_ITEMS", path) then reportContents = .true
  if self~ruleEnabled("REPORT_COLLECTION_ITEMS", path) then reportContents = .true

  if reportContents then do
    count = 0
    do idx over self~safeIndexes(obj)
      count = count + 1
      if count > self~MAX_COLLECTION_SAMPLE then leave
      child = self~safeAt(obj, idx, .nil)
      item = .directory~new
      item~put(self~safeString(idx), "index")
      if child == .nil then do
        item~put(.true, "nil")
      end
      else do
        item~put(self~oidFor(child), "oid")
        item~put(self~safeClassName(child), "class")
        item~put(self~objectKind(child), "kind")
        item~put(self~safeString(child), "value")
      end
      contents~append(item)
    end
    rec~put(contents, "contents")
  end

  if kind = "queue" then do
    qrec = .directory~new
    qrec~put(oid, "oid")
    qrec~put(path, "path")
    qrec~put(itemCount, "items")
    if reportContents then qrec~put(contents, "contents")
    queues~append(qrec)
  end

  return rec

::method detectIdentityFindings private
  expose objects findings

  byOid = self~directoryValues(objects)
  do node over byOid
    cls = node~at("class")~translate
    path = node~at("path")
    if cls~pos("POLLEVENT") > 0 then do
      if path~translate~pos("STORAGE") > 0 | path~translate~pos("REGISTRY") > 0 | path~translate~pos("INDEX") > 0 then do
        f = .directory~new
        f~put("suspicious_storage_of_event_object", "finding")
        f~put("high", "severity")
        f~put(node~at("oid"), "object_oid")
        f~put(node~at("class"), "object_class")
        f~put(path, "path")
        f~put("A poll event object appears on a storage, registry, or index path.", "reason")
        findings~append(f)
      end
    end
  end


::method buildInheritanceMaps private
  expose classes methods objects

  out = .directory~new
  out~put("alchemy.oorexx.inspector-clouseau.inheritance-map.v1", "schema")

  classReports = .array~new
  inheritanceEdges = .array~new
  hotspots = .array~new
  liveCounts = .directory~new
  liveSamples = .directory~new

  do obj over self~directoryValues(objects)
    if \obj~hasIndex("class") then iterate
    cname = self~safeString(obj~at("class"))
    if cname = "" then iterate
    if \liveCounts~hasIndex(cname) then do
      liveCounts~put(0, cname)
      liveSamples~put(.array~new, cname)
    end
    liveCounts~put(liveCounts~at(cname) + 1, cname)
    samples = liveSamples~at(cname)
    if samples~items < 8 then do
      s = .directory~new
      if obj~hasIndex("oid") then s~put(obj~at("oid"), "oid")
      if obj~hasIndex("path") then s~put(obj~at("path"), "path")
      if obj~hasIndex("kind") then s~put(obj~at("kind"), "kind")
      samples~append(s)
    end
  end

  do crec over self~directoryValues(classes)
    if \crec~hasIndex("name") then iterate
    cname = self~safeString(crec~at("name"))
    if cname = "" then iterate

    report = .directory~new
    report~put(cname, "class")
    if crec~hasIndex("id") then report~put(crec~at("id"), "id")
    if crec~hasIndex("package") then report~put(crec~at("package"), "package")

    directSuper = ""
    if crec~hasIndex("super_class") then directSuper = self~safeString(crec~at("super_class"))
    report~put(directSuper, "direct_superclass")

    supers = .array~new
    if crec~hasIndex("super_classes") then supers = crec~at("super_classes")
    report~put(supers, "super_classes")

    subs = .array~new
    if crec~hasIndex("subclasses") then subs = crec~at("subclasses")
    report~put(subs, "subclasses")

    report~put(self~classLineageForName(cname), "lineage")

    if liveCounts~hasIndex(cname) then do
      report~put(liveCounts~at(cname), "live_object_count")
      report~put(liveSamples~at(cname), "live_object_samples")
    end
    else do
      report~put(0, "live_object_count")
      report~put(.array~new, "live_object_samples")
    end

    buckets = .directory~new
    buckets~put(.array~new, "local_declared")
    buckets~put(.array~new, "local_override")
    buckets~put(.array~new, "inherited_superclass")
    buckets~put(.array~new, "inherited_mixin_or_secondary_superclass")
    buckets~put(.array~new, "injected_probe")
    buckets~put(.array~new, "unknown")
    buckets~put(.array~new, "signal_or_condition_methods")
    buckets~put(.array~new, "opaque_methods")

    do m over methods
      if \m~hasIndex("class") then iterate
      if self~safeString(m~at("class")) \= cname then iterate
      ms = self~methodResolutionSummary(m)
      ok = "unknown"
      if ms~hasIndex("origin_kind") then ok = self~safeString(ms~at("origin_kind"))
      if \buckets~hasIndex(ok) then ok = "unknown"
      buckets~at(ok)~append(ms)
      if ms~hasIndex("signal_names") then do
        if ms~at("signal_names")~items > 0 then buckets~at("signal_or_condition_methods")~append(ms)
      end
      if ms~hasIndex("source_available") then do
        if ms~at("source_available") \== .true then buckets~at("opaque_methods")~append(ms)
      end
    end

    counts = .directory~new
    do b over buckets~allIndexes
      counts~put(buckets~at(b)~items, b)
    end
    report~put(counts, "method_counts")
    report~put(buckets, "method_resolution")

    if directSuper \= "" then do
      e = .directory~new
      e~put(cname, "from")
      e~put(directSuper, "to")
      e~put("direct_superclass", "relation")
      inheritanceEdges~append(e)
    end

    do s over supers
      sname = self~safeString(s)
      if sname = "" then iterate
      if sname = directSuper then iterate
      e = .directory~new
      e~put(cname, "from")
      e~put(sname, "to")
      e~put("mixin_or_secondary_superclass", "relation")
      inheritanceEdges~append(e)
    end

    do sub over subs
      subName = self~safeString(sub)
      if subName = "" then iterate
      e = .directory~new
      e~put(cname, "from")
      e~put(subName, "to")
      e~put("subclass", "relation")
      inheritanceEdges~append(e)
    end

    if counts~at("local_override") > 0 then do
      h = .directory~new
      h~put("override_methods_present", "finding")
      h~put(cname, "class")
      h~put(counts~at("local_override"), "count")
      h~put("Class overrides one or more superclass/mixin method names.", "reason")
      hotspots~append(h)
    end
    if counts~at("signal_or_condition_methods") > 0 then do
      h = .directory~new
      h~put("signal_methods_present", "finding")
      h~put(cname, "class")
      h~put(counts~at("signal_or_condition_methods"), "count")
      h~put("Class has methods with SIGNAL/CALL ON/direct signal labels.", "reason")
      hotspots~append(h)
    end

    classReports~append(report)
  end

  out~put(classReports, "classes")
  out~put(inheritanceEdges, "edges")
  out~put(hotspots, "hotspots")
  return out

::method classLineageForName private
  expose classes
  use strict arg className

  out = .array~new
  seen = .directory~new
  current = self~safeString(className)
  do while current \= ""
    if seen~hasIndex(current) then leave
    seen~put(.true, current)
    out~append(current)
    if \classes~hasIndex(current) then leave
    crec = classes~at(current)
    if \crec~hasIndex("super_class") then leave
    next = self~safeString(crec~at("super_class"))
    if next = current then leave
    current = next
  end
  return out

::method methodResolutionSummary private
  use strict arg m

  s = .directory~new
  if m~hasIndex("class") then s~put(m~at("class"), "class")
  if m~hasIndex("method") then s~put(m~at("method"), "method")
  if m~hasIndex("package") then s~put(m~at("package"), "package")
  if m~hasIndex("source_available") then s~put(m~at("source_available"), "source_available")
  if m~hasIndex("terminal") then s~put(m~at("terminal"), "terminal")
  if m~hasIndex("opaque_reason") then s~put(m~at("opaque_reason"), "opaque_reason")
  if m~hasIndex("origin_kind") then s~put(m~at("origin_kind"), "origin_kind")
  if m~hasIndex("origin_from_class") then s~put(m~at("origin_from_class"), "from_class")
  if m~hasIndex("origin_from_relation") then s~put(m~at("origin_from_relation"), "from_relation")
  if m~hasIndex("origin_from_package") then s~put(m~at("origin_from_package"), "from_package")
  if m~hasIndex("signal_names") then s~put(m~at("signal_names"), "signal_names")
  else s~put(.array~new, "signal_names")
  if m~hasIndex("classification") then s~put(m~at("classification"), "classification")
  if m~hasIndex("origin") then do
    o = m~at("origin")
    if o~hasIndex("overrides_candidates") then s~put(o~at("overrides_candidates"), "overrides_candidates")
    if o~hasIndex("inherited_by_subclasses") then s~put(o~at("inherited_by_subclasses"), "inherited_by_subclasses")
    if o~hasIndex("evidence") then s~put(o~at("evidence"), "evidence")
  end
  return s


::method methodOriginFor private
  use strict arg cls, currentClassName, mname, methodObj

  origin = .directory~new
  origin~put(self~safeString(currentClassName), "current_class")
  origin~put(self~safeString(mname), "method")

  methodName = self~safeString(mname)
  if self~isProbeName(methodName) then do
    origin~put("injected_probe", "kind")
    origin~put(self~safeString(currentClassName), "from_class")
    origin~put("inspector_injected", "from_relation")
    origin~put("temporary_method", "evidence")
    origin~put(.array~new, "inherited_by_subclasses")
    return origin
  end

  if cls == .nil | methodObj == .nil | methodName = "" then do
    origin~put("unknown", "kind")
    origin~put("", "from_class")
    origin~put("unknown", "from_relation")
    origin~put("missing class, method object, or method name", "evidence")
    origin~put(.array~new, "inherited_by_subclasses")
    return origin
  end

  methodPkg = self~safeSend0(methodObj, "package", .nil)
  origin~put(self~packageIdentity(methodPkg), "method_package")

  directSuper = self~safeSend0(cls, "superClass", .nil)
  superDefinesSameName = .false
  overrideCandidates = .array~new

  if directSuper \== .nil then do
    directMethod = self~safeMethodLookup(directSuper, methodName)
    if directMethod \== .nil then do
      superDefinesSameName = .true
      if directMethod == methodObj then do
        origin~put("inherited_superclass", "kind")
        origin~put(self~safeClassId(directSuper), "from_class")
        origin~put("direct_superclass", "from_relation")
        origin~put(self~packageIdentity(self~safeSend0(directMethod, "package", .nil)), "from_package")
        origin~put("same method object returned by direct superclass", "evidence")
        origin~put(self~inheritedBySubclasses(cls, methodName, methodObj), "inherited_by_subclasses")
        return origin
      end
      else overrideCandidates~append(self~safeClassId(directSuper))
    end
  end

  supers = self~safeSend0(cls, "superClasses", .nil)
  do super over self~safeIterable(supers)
    if super == .nil then iterate
    if super == cls then iterate
    if directSuper \== .nil then do
      if super == directSuper then iterate
    end

    sm = self~safeMethodLookup(super, methodName)
    if sm == .nil then iterate
    superDefinesSameName = .true

    if sm == methodObj then do
      origin~put("inherited_mixin_or_secondary_superclass", "kind")
      origin~put(self~safeClassId(super), "from_class")
      origin~put("mixin_or_secondary_superclass", "from_relation")
      origin~put(self~packageIdentity(self~safeSend0(sm, "package", .nil)), "from_package")
      origin~put("same method object returned by non-primary superclass/mixin chain", "evidence")
      origin~put(self~inheritedBySubclasses(cls, methodName, methodObj), "inherited_by_subclasses")
      return origin
    end
    else overrideCandidates~append(self~safeClassId(super))
  end

  if superDefinesSameName then do
    origin~put("local_override", "kind")
    origin~put(self~safeString(currentClassName), "from_class")
    origin~put("current_class", "from_relation")
    origin~put(self~packageIdentity(methodPkg), "from_package")
    origin~put("superclass or mixin defines same method name but not the same method object", "evidence")
    origin~put(overrideCandidates, "overrides_candidates")
    origin~put(self~inheritedBySubclasses(cls, methodName, methodObj), "inherited_by_subclasses")
    return origin
  end

  origin~put("local_declared", "kind")
  origin~put(self~safeString(currentClassName), "from_class")
  origin~put("current_class", "from_relation")
  origin~put(self~packageIdentity(methodPkg), "from_package")
  origin~put("no superclass or mixin returned the same method name", "evidence")
  origin~put(self~inheritedBySubclasses(cls, methodName, methodObj), "inherited_by_subclasses")
  return origin

::method inheritedBySubclasses private
  use strict arg cls, methodName, methodObj

  out = .array~new
  if cls == .nil | methodObj == .nil then return out
  subs = self~safeSend0(cls, "subclasses", .nil)
  do sub over self~safeIterable(subs)
    if sub == .nil then iterate
    sm = self~safeMethodLookup(sub, methodName)
    if sm == .nil then iterate
    if sm == methodObj then out~append(self~safeClassId(sub))
  end
  return out

::method sourceLinesForMethod private
  use strict arg methodObj

  if methodObj == .nil then return .nil
  src = self~safeSend0(methodObj, "source", .nil)
  if src == .nil then return .nil
  return self~toLineArray(src)

::method toLineArray private
  use strict arg src

  out = .array~new

  signal on syntax name notIterable
  do line over src
    out~append(self~safeString(line))
  end
  signal off syntax
  if out~items > 0 then return out

notIterable:
  signal off syntax
  s = self~safeString(src)
  parse var s first ("0a"x) rest
  if rest = "" then do
    out~append(s)
    return out
  end

  out = .array~new
  text = s
  do while text \= ""
    parse var text one ("0a"x) text
    out~append(one)
  end
  return out

::method scanSignals private
  use strict arg lines

  p = .directory~new
  p~put(.false, "has_signal")
  p~put(.false, "direct_signal")
  p~put(.false, "signal_value")
  p~put(.array~new, "signal_on")
  p~put(.array~new, "signal_off")
  p~put(.array~new, "call_on")
  p~put(.array~new, "call_off")
  p~put(.array~new, "labels")
  p~put(.array~new, "direct_signal_targets")
  p~put(.array~new, "signal_named_handlers")
  p~put(.array~new, "call_named_handlers")

  blockState = .array~new
  blockState~append(.false)
  do line over lines
    cleaned = self~cleanRexxLine(line, blockState)
    upper = cleaned~translate~strip
    if upper = "" then iterate

    parse value upper with first second third .
    if first = "SIGNAL" then do
      p~put(.true, "has_signal")
      if second = "ON" then do
        cond = third
        p~at("signal_on")~append(cond)
        handler = self~conditionHandlerLabel(upper)
        if handler \= "" then do
          h = .directory~new
          h~put(cond, "condition")
          h~put(handler, "label")
          h~put("SIGNAL ON", "kind")
          p~at("signal_named_handlers")~append(h)
        end
      end
      else if second = "OFF" then p~at("signal_off")~append(third)
      else if second = "VALUE" then p~put(.true, "signal_value")
      else do
        p~put(.true, "direct_signal")
        target = second
        if target \= "" then p~at("direct_signal_targets")~append(target)
      end
    end

    if first = "CALL" then do
      if second = "ON" then do
        cond = third
        p~at("call_on")~append(cond)
        handler = self~conditionHandlerLabel(upper)
        if handler \= "" then do
          h = .directory~new
          h~put(cond, "condition")
          h~put(handler, "label")
          h~put("CALL ON", "kind")
          p~at("call_named_handlers")~append(h)
        end
      end
      if second = "OFF" then p~at("call_off")~append(third)
    end

    if upper~right(1) = ":" then do
      label = upper~left(upper~length - 1)~strip
      if label \= "" then p~at("labels")~append(label)
    end
  end

  return p

::method conditionHandlerLabel private
  use strict arg upperLine

  rest = upperLine
  do while rest \= ""
    parse var rest token rest
    if token = "NAME" then do
      parse var rest label .
      if label \= "" then return self~normalizeSignalLabel(label)
    end
  end
  return ""

::method normalizeSignalLabel private
  use strict arg label

  l = self~safeString(label)~translate~strip
  if l = "" then return ""
  if l~right(1) = ":" then l = l~left(l~length - 1)
  if l~right(1) = "," then l = l~left(l~length - 1)
  if l~right(1) = ";" then l = l~left(l~length - 1)
  return l

::method signalNamesFromProfile private
  use strict arg profile

  out = .array~new
  seen = .directory~new
  self~appendSignalNames(out, seen, self~safeSend1(profile, "at", "labels", .array~new))
  self~appendSignalNames(out, seen, self~safeSend1(profile, "at", "signal_on", .array~new))
  self~appendSignalNames(out, seen, self~safeSend1(profile, "at", "call_on", .array~new))
  self~appendSignalNames(out, seen, self~safeSend1(profile, "at", "direct_signal_targets", .array~new))
  do h over self~safeIterable(self~safeSend1(profile, "at", "signal_named_handlers", .array~new))
    if h~hasIndex("label") then self~appendSignalName(out, seen, h~at("label"))
    if h~hasIndex("condition") then self~appendSignalName(out, seen, h~at("condition"))
  end
  do h over self~safeIterable(self~safeSend1(profile, "at", "call_named_handlers", .array~new))
    if h~hasIndex("label") then self~appendSignalName(out, seen, h~at("label"))
    if h~hasIndex("condition") then self~appendSignalName(out, seen, h~at("condition"))
  end
  return out

::method appendSignalNames private
  use strict arg out, seen, arr

  do item over self~safeIterable(arr)
    self~appendSignalName(out, seen, item)
  end

::method appendSignalName private
  use strict arg out, seen, name

  n = self~normalizeSignalLabel(name)
  if n = "" then return
  if seen~hasIndex(n) then return
  seen~put(.true, n)
  out~append(n)

::method recordProcedureSignalRuleMatches private
  expose rules warnings
  use strict arg procedureRec, signalProfile

  pname = ""
  if procedureRec~hasIndex("procedure") then pname = procedureRec~at("procedure")
  names = self~signalNamesFromProfile(signalProfile)
  do rule over rules
    if \rule~hasIndex("enabled") then iterate
    if rule~at("enabled") \== .true then iterate
    if \rule~hasIndex("kind") then iterate
    if self~safeString(rule~at("kind"))~translate \= "TRIGGER_INSPECTION_ON_PROCEDURE_SIGNAL" then iterate
    pp = "*"
    sp = "*"
    if rule~hasIndex("procedure_pattern") then pp = rule~at("procedure_pattern")
    if rule~hasIndex("signal_pattern") then sp = rule~at("signal_pattern")
    if \self~rulePatternMatches(pp, pname) then iterate
    do sig over names
      if self~rulePatternMatches(sp, sig) then do
        matches = .array~new
        if procedureRec~hasIndex("procedure_signal_rule_matches") then matches = procedureRec~at("procedure_signal_rule_matches")
        m = .directory~new
        m~put(pname, "procedure")
        m~put(sig, "signal")
        m~put("procedure signal trigger is reported from source; runtime routine replacement is not installed by v1.2.6", "status")
        matches~append(m)
        procedureRec~put(matches, "procedure_signal_rule_matches")
      end
    end
  end

::method classifyMethodSource private
  use strict arg mname, lines, signalProfile

  upperName = self~safeString(mname)~translate
  all = ""
  do line over lines
    all = all || " " || line~translate
  end

  c = self~classifyByName(upperName)
  behaviour = c~at("behaviour")
  risk = c~at("risk")
  control = c~at("control_flow")

  if all~pos("~QUEUE") > 0 | all~pos("~PUSH") > 0 | all~pos("~PULL") > 0 | all~pos("~APPEND") > 0 then risk~append("queue_mutating")
  if all~pos("~PUT") > 0 | all~pos("WRITE") > 0 | all~pos("STORE") > 0 | all~pos("INDEX") > 0 then risk~append("state_or_storage_mutating")
  if all~pos("JAVA") > 0 | all~pos("BSF") > 0 | all~pos("BRIDGE") > 0 then risk~append("bridge_or_java")
  if all~pos("DO WHILE") > 0 | all~pos("DO FOREVER") > 0 then control~append("loop")
  if signalProfile~at("has_signal") then control~append("signal_or_condition_boundary")

  return c

::method classifyByName private
  use strict arg mname

  upper = self~safeString(mname)~translate
  c = .directory~new
  behaviour = .array~new
  risk = .array~new
  control = .array~new

  if upper = "INIT" then behaviour~append("constructor")
  if upper = "UNINIT" then behaviour~append("destructor")
  if upper~pos("POLL") > 0 then behaviour~append("agent_poll")
  if upper~pos("DISPATCH") > 0 then behaviour~append("dispatch")
  if upper~pos("EVENT") > 0 | upper~pos("ACTIONPERFORMED") > 0 then behaviour~append("event_handler")
  if upper~pos("STORE") > 0 | upper~pos("WRITE") > 0 | upper~pos("INDEX") > 0 then behaviour~append("storage_operation")
  if upper~pos("QUEUE") > 0 | upper~pos("PULL") > 0 | upper~pos("PUSH") > 0 then behaviour~append("queue_operation")
  if upper~pos("BRIDGE") > 0 | upper~pos("JAVA") > 0 | upper~pos("INVOKE") > 0 then behaviour~append("bridge_call")

  if behaviour~items = 0 then behaviour~append("unknown")
  if risk~items = 0 then risk~append("unknown")
  if control~items = 0 then control~append("unknown")

  c~put(behaviour, "behaviour")
  c~put(risk, "risk")
  c~put(control, "control_flow")
  return c

::method unknownSignalProfile private
  p = .directory~new
  p~put("unknown_no_source", "status")
  p~put(.false, "has_signal")
  return p

::method scanRequiresFromSource private
  use strict arg pkg

  out = .array~new
  size = self~safeSend0(pkg, "sourceSize", 0)
  if size~datatype("W") \= 1 then return out

  do i = 1 to size
    line = self~safeString(self~safeSend1(pkg, "sourceLine", i, ""))
    upper = line~translate~strip
    parse value upper with first .
    if first = "::REQUIRES" then out~append(line~strip)
  end
  return out

::method cleanRexxLine private
  /* Strip line comments and slash-star block comments from a REXX source line.
     blockState is a one-item Array used as a mutable boolean reference. */
  use strict arg line, blockState

  s = self~safeString(line)
  inBlock = .false
  isArray = self~safeClassName(blockState)~translate~pos("ARRAY") > 0
  if isArray then do
    if blockState~items >= 1 then inBlock = self~safeLogical(blockState~at(1))
  end
  else inBlock = self~safeLogical(blockState)

  out = ""
  i = 1
  slen = s~length
  do while i <= slen
    if inBlock then do
      if i <= slen - 1 & s~substr(i, 2) = "*/" then do
        inBlock = .false
        i = i + 2
      end
      else i = i + 1
      iterate
    end

    if i <= slen - 1 then do
      two = s~substr(i, 2)
      if two = "/*" then do
        inBlock = .true
        i = i + 2
        iterate
      end
      if two = "--" then leave
    end

    out = out || s~substr(i, 1)
    i = i + 1
  end

  if isArray then do
    if blockState~items >= 1 then blockState~put(inBlock, 1)
    else blockState~append(inBlock)
  end
  return out

::method isCollectionLike private
  use strict arg obj

  if obj == .nil then return .false
  cname = self~safeClassName(obj)~translate
  if cname~pos("QUEUE") > 0 then return .true
  if cname~pos("ARRAY") > 0 then return .true
  if cname~pos("DIRECTORY") > 0 then return .true
  if cname~pos("TABLE") > 0 then return .true
  if cname~pos("LIST") > 0 then return .true
  if cname~pos("BAG") > 0 then return .true
  if cname~pos("SET") > 0 then return .true
  if cname~pos("RELATION") > 0 then return .true
  if cname~pos("STEM") > 0 then return .true

  items = self~safeSend0(obj, "items", .nil)
  indexes = self~safeSend0(obj, "allIndexes", .nil)
  if items \== .nil & indexes \== .nil then return .true
  return .false

::method objectKind private
  use strict arg obj

  cname = self~safeClassName(obj)~translate
  if cname~pos("QUEUE") > 0 then return "queue"
  if cname~pos("DIRECTORY") > 0 then return "directory"
  if cname~pos("ARRAY") > 0 then return "array"
  if cname~pos("TABLE") > 0 then return "table"
  if cname~pos("LIST") > 0 then return "list"
  if cname~pos("BAG") > 0 then return "bag"
  if cname~pos("SET") > 0 then return "set"
  if cname~pos("RELATION") > 0 then return "relation"
  if cname~pos("PACKAGE") > 0 then return "package"
  if cname~pos("CLASS") > 0 then return "class"
  if cname~pos("METHOD") > 0 then return "method"
  return "object"

::method namesFromClassCollection private
  use strict arg coll

  out = .array~new
  if coll == .nil then return out
  do item over self~safeIterable(coll)
    out~append(self~safeClassId(item))
  end
  return out

::method safeIndexes private
  use strict arg coll

  out = .array~new
  if coll == .nil then return out

  signal on syntax name noIndexes
  indexes = coll~allIndexes
  do idx over indexes
    out~append(idx)
  end
  signal off syntax
  return out

noIndexes:
  signal off syntax
  /* Claude performance rule: do not fall back to Supplier iteration here.
     Inspector callers that need indexes should use allIndexes-capable maps;
     safeIterable handles value iteration through do-over separately. */
  return out

::method safeIterable private
  use strict arg coll

  out = .array~new
  if coll == .nil then return out

  signal on syntax name notIterable
  do item over coll
    out~append(item)
  end
  signal off syntax
  return out

notIterable:
  signal off syntax
  do idx over self~safeIndexes(coll)
    item = self~safeAt(coll, idx, .nil)
    if item \== .nil then out~append(item)
  end
  return out


::method safeSendArgs private
  use strict arg target, messageName, args, defaultValue

  if target == .nil then return defaultValue
  if args == .nil then args = .array~new
  signal on syntax name failed
  v = target~sendWith(messageName, args)
  signal off syntax
  return v
failed:
  signal off syntax
  return defaultValue

::method hasPublicInstallHook private
  use strict arg obj

  return self~safeLogical(self~safeSend1(obj, "hasMethod", "__INSPECTOR_CLOUSEAU_INSTALL", .false))

::method hasPublicUninstallHook private
  use strict arg obj

  return self~safeLogical(self~safeSend1(obj, "hasMethod", "__INSPECTOR_CLOUSEAU_UNINSTALL", .false))

::method conditionSummary private
  c = ""
  d = .nil
  a = .nil
  rcText = ""
  siglText = ""
  co = .nil

  if arg() >= 1 then c = arg(1)
  else c = condition("C")
  if arg() >= 2 then d = arg(2)
  else d = condition("D")
  if arg() >= 3 then a = arg(3)
  else a = condition("A")
  if arg() >= 4 then rcText = arg(4)
  if arg() >= 5 then siglText = arg(5)
  if arg() >= 6 then co = arg(6)

  out = self~safeString(c)
  if d \== .nil then do
    if self~safeClassName(d)~translate~pos("DIRECTORY") > 0 then do
      detail = ""
      do idx over self~safeIndexes(d)
        if detail \= "" then detail = detail || ";"
        detail = detail || self~safeString(idx) || "=" || self~safeString(self~safeAt(d, idx, ""))
      end
      if detail \= "" then out = out || ":" || detail
    end
    else do
      dText = self~safeString(d)
      if dText \= "" then out = out || ":" || dText
    end
  end
  if a \== .nil then do
    aText = self~safeString(a)
    if aText \= "" then out = out || ":additional=" || aText
  end
  if rcText \= "" then out = out || " rc=" || self~safeString(rcText)
  if siglText \= "" then out = out || " sigl=" || self~safeString(siglText)

  if co \== .nil then do
    signal on syntax name coDone
    if co~hasMethod("CONDITION") then out = out || " co_condition=" || self~safeString(co~condition)
    if co~hasMethod("DESCRIPTION") then out = out || " co_description=" || self~safeString(co~description)
    if co~hasMethod("ERRORTEXT") then out = out || " errortext=" || self~safeString(co~errortext)
    if co~hasMethod("INSTRUCTION") then out = out || " instruction=" || self~safeString(co~instruction)
    if co~hasMethod("PROGRAM") then out = out || " program=" || self~safeString(co~program)
    if co~hasMethod("CODE") then out = out || " code=" || self~safeString(co~code)
coDone:
    signal off syntax
  end

  return out

::method safeAt private
  use strict arg coll, idx, defaultValue

  signal on syntax name failed
  v = coll~at(idx)
  signal off syntax
  return v
failed:
  signal off syntax
  return defaultValue

::method safeSend0 private
  use strict arg target, messageName, defaultValue

  if target == .nil then return defaultValue
  signal on syntax name failed
  v = target~send(messageName)
  signal off syntax
  return v
failed:
  signal off syntax
  return defaultValue

::method safeSend1 private
  use strict arg target, messageName, a1, defaultValue

  if target == .nil then return defaultValue
  signal on syntax name failed
  args = .array~new
  args~append(a1)
  v = target~send(messageName, args)
  signal off syntax
  return v
failed:
  signal off syntax
  return defaultValue

::method safeMethodLookup private
  use strict arg cls, name

  signal on syntax name failed
  m = cls~method(name)
  signal off syntax
  return m
failed:
  signal off syntax
  return .nil

::method safeClassName private
  use strict arg obj

  if obj == .nil then return "nil"
  cls = self~safeSend0(obj, "class", .nil)
  return self~safeClassId(cls)

::method safeClassId private
  use strict arg cls

  if cls == .nil then return "unknown"
  id = self~safeSend0(cls, "id", .nil)
  if id == .nil then id = self~safeSend0(cls, "objectName", "unknown")
  return self~safeString(id)

::method packageIdentity private
  use strict arg pkg

  if pkg == .nil then return ""
  name = self~safeString(self~safeSend0(pkg, "name", ""))
  path = self~safeString(self~safeSend0(pkg, "path", ""))
  if path \= "" then return path
  return name

::method safeString private
  use strict arg v

  if v == .nil then return ""
  signal on syntax name failed
  s = v~string
  signal off syntax
  return s
failed:
  signal off syntax
  return "<string-unavailable>"

::method safeLogical private
  use strict arg v

  if v == .true then return .true
  if v == .false then return .false
  s = self~safeString(v)~translate
  if s = "1" | s = "TRUE" then return .true
  return .false

::method oidFor private
  expose visitedObjects oidCounter
  use strict arg obj

  if obj == .nil then return "nil"
  existing = visitedObjects~at(obj)
  if existing \== .nil then return existing
  oidCounter = oidCounter + 1
  oid = "O" || oidCounter~right(6, "0")
  visitedObjects~put(oid, obj)
  return oid
::method shouldSkipObject private
  use strict arg obj

  if obj == self then return .true
  if self~safeClassName(obj)~translate~pos("INSPECTORCLOUSEAU") > 0 then return .true
  if self~safeClassName(obj)~translate~pos("INSPECTORSNAPSHOT") > 0 then return .true
  return .false

::method isInspectorClass private
  use strict arg cls

  cname = self~safeClassId(cls)~translate
  if cname~pos("INSPECTORCLOUSEAU") > 0 then return .true
  if cname~pos("INSPECTORSNAPSHOT") > 0 then return .true
  return .false

::method isOwnPackage private
  use strict arg pkg

  ident = self~packageIdentity(pkg)~translate
  if ident~pos("INSPECTORCLOUSEAU") > 0 then return .true
  if ident~pos("INSPECTOR_CLOUSEAU") > 0 then return .true
  return .false

::method isProbeName private
  use strict arg name

  return self~safeString(name)~translate~pos(self~PROBE_PREFIX) = 1

::method classSafeName private
  use strict arg name

  s = self~safeString(name)~translate
  out = ""
  do i = 1 to s~length
    ch = s~substr(i, 1)
    if ch~datatype("M") | ch~datatype("W") then out = out || ch
    else out = out || "_"
  end
  if out = "" then out = "UNKNOWN"
  return out

::method addEdge private
  expose edges
  use strict arg fromOid, toOid, edgeName, path, kind

  e = .directory~new
  e~put(fromOid, "from")
  e~put(toOid, "to")
  e~put(edgeName, "edge")
  e~put(path, "path")
  e~put(kind, "edge_kind")
  edges~append(e)

::method addWarning private
  expose warnings
  use strict arg message

  w = .directory~new
  w~put(message, "message")
  warnings~append(w)

::method directoryValues private
  use strict arg d

  out = .array~new
  if d == .nil then return out
  do idx over self~safeIndexes(d)
    out~append(d~at(idx))
  end
  return out

::method nowIso private
  return date("S") || "T" || time("L")

::method timestampToken private
  t = time("L")
  t = changestr(":", t, "")
  t = changestr(".", t, "")
  return date("S") || "T" || t

::method inferClassSlots private
  use strict arg cls, methodMap

  slots = .array~new
  seen = .directory~new
  if methodMap == .nil then return slots

  do mname over self~safeIndexes(methodMap)
    upperName = self~safeString(mname)~translate
    if self~isProbeName(upperName) then iterate

    /* ::ATTRIBUTE creates a getter and setter.  The setter method name is a
       useful source-independent slot hint. */
    if upperName~right(1) = "=" then do
      slot = upperName~left(upperName~length - 1)
      self~appendSlotName(slots, seen, slot)
    end

    m = self~safeAt(methodMap, mname, .nil)
    if m == .nil then m = self~safeMethodLookup(cls, mname)
    lines = self~sourceLinesForMethod(m)
    if lines == .nil then iterate

    do line over lines
      cleaned = self~cleanRexxLine(line, .false)~strip
      upper = cleaned~translate
      parse var upper first rest
      if first = "EXPOSE" then do while rest \= ""
        parse var rest token rest
        token = self~normalizeSlotToken(token)
        self~appendSlotName(slots, seen, token)
      end
    end
  end

  return slots

::method appendSlotName private
  use strict arg slots, seen, token

  token = self~normalizeSlotToken(token)
  if token = "" then return
  if seen~hasIndex(token) then return
  seen~put(.true, token)
  slots~append(token)

::method normalizeSlotToken private
  use strict arg token

  t = self~safeString(token)~translate~strip
  if t = "" then return ""
  if t~right(1) = "," then t = t~left(t~length - 1)
  if t~right(1) = ";" then t = t~left(t~length - 1)
  if t~right(1) = "." then t = t~left(t~length - 1)
  if t~pos("(") > 0 then return ""
  if t~pos("~") > 0 then return ""
  if t~pos("'") > 0 | t~pos('"') > 0 then return ""
  if t = "SELF" then return ""
  if t = "SIGL" then return ""
  if t = "OBJECTNAME" then return ""
  if t = "DEFAULTNAME" then return ""
  if t~left(1)~datatype("W") then return ""

  do i = 1 to t~length
    ch = t~substr(i, 1)
    if ch~datatype("M") | ch~datatype("W") | ch = "_" | ch = "!" | ch = "?" then nop
    else return ""
  end
  return t

::method shouldProbeObject private
  expose enableInjectedProbes
  use strict arg obj, path

  if enableInjectedProbes \== .true then return .false
  if obj == .nil then return .false
  if self~shouldSkipObject(obj) then return .false
  upperPath = self~safeString(path)~translate
  if upperPath~left(18) = "ROOT:.ENVIRONMENT" then return .false
  if upperPath~left(11) = "ROOT:.LOCAL" then return .false
  if upperPath~left(13) = "ROOT:.CONTEXT" then return .false
  if self~isCollectionLike(obj) then return .false

  kind = self~objectKind(obj)
  if kind \= "object" then return .false

  cname = self~safeClassName(obj)~translate
  if cname = "STRING" | cname = "STREAM" | cname = "MONITOR" then return .false
  if cname = "REXXINFO" | cname = "REXXCONTEXT" then return .false
  if cname = "CLASS" | cname = "METHOD" | cname = "PACKAGE" then return .false

  slots = self~slotsForObject(obj)
  if slots~items = 0 then return .false
  return .true

::method slotsForObject private
  expose classSlots
  use strict arg obj

  cname = self~safeClassName(obj)
  slots = classSlots~at(cname)
  if slots \== .nil then return slots
  slots = classSlots~at(cname~translate)
  if slots \== .nil then return slots
  return .array~new
::method installProbeForObject private
  expose probeCounter
  use strict arg obj, oid, path

  if \self~shouldProbeObject(obj, path) then return .nil

  slots = self~slotsForObject(obj)
  cname = self~classSafeName(self~safeClassName(obj))
  probeCounter = probeCounter + 1
  probeName = self~PROBE_PREFIX || cname || "_" || oid || "_" || probeCounter

  if self~safeLogical(self~safeSend1(obj, "hasMethod", probeName, .false)) then do
    self~addWarning("Probe name collision skipped for " || path || " method=" || probeName)
    return .nil
  end

  source = self~buildProbeSource(probeName, slots)
  probeMethod = self~runtimeMethodFromSource(probeName, source)

  installed = .false
  installMode = ""
  directFailure = ""

  signal on syntax name directInstallFailed
  obj~setMethod(probeName, probeMethod)
  installed = .true
  installMode = "direct-setMethod-method-object"
  signal off syntax
  signal installedOk

directInstallFailed:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  directFailure = self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O"))
  if self~hasPublicInstallHook(obj) then do
    args = .array~new
    args~append(probeName)
    args~append(probeMethod)
    args~append("OBJECT")
    hookResult = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    if self~safeLogical(hookResult) then do
      installed = .true
      installMode = "cooperative-hook"
    end
  end

installedOk:
  if installed \== .true then do
    self~addWarning("Probe injection failed at " || path || " method=" || probeName || " direct=" || directFailure || " hook=unavailable-or-failed")
    return .nil
  end

  result = .nil
  signal on syntax name invokeFailed
  result = obj~send(probeName)
  signal off syntax

  self~enqueueProbeResultChildren(result, oid, path)
  self~removeProbeMethod(obj, probeName, installMode)
  return self~summarizeProbeResult(result, probeName, slots, oid, path)

invokeFailed:
  signal off syntax
  self~removeProbeMethod(obj, probeName, installMode)
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  self~addWarning("Probe invocation failed at " || path || " method=" || probeName || " mode=" || installMode || " condition=" || self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O")))
  return .nil

::method installMethodTriggersForObject private
  expose rules triggerInstalled triggerActive
  use strict arg obj, oid, path

  installed = .array~new
  if triggerActive == .true then return installed
  if obj == .nil then return installed
  if self~shouldSkipObject(obj) then return installed

  cname = self~safeClassName(obj)
  ckey = cname~translate

  objectInstalled = .directory~new
  if triggerInstalled~hasIndex(obj) then objectInstalled = triggerInstalled~at(obj)

  do rule over rules
    if \rule~hasIndex("enabled") then iterate
    if rule~at("enabled") \== .true then iterate
    if \rule~hasIndex("kind") then iterate
    if \self~isInstallableTriggerRule(rule) then iterate

    classPattern = "*"
    methodPattern = "*"
    if rule~hasIndex("class_pattern") then classPattern = rule~at("class_pattern")
    if rule~hasIndex("method_pattern") then methodPattern = rule~at("method_pattern")
    if \self~rulePatternMatches(classPattern, cname) then iterate

    methodsToTry = .array~new
    if methodPattern = "*" then do
      cls = self~safeSend0(obj, "class", .nil)
      methodMap = self~safeSend0(cls, "methods", .nil)
      do mn over self~safeIndexes(methodMap)
        methodsToTry~append(self~safeString(mn))
      end
    end
    else methodsToTry~append(self~safeString(methodPattern))

    do methodName over methodsToTry
      if self~isProbeName(methodName) then iterate
      if \self~rulePatternMatches(methodPattern, methodName) then iterate
      installKey = ckey || "::" || methodName~translate
      if self~isSignalTriggerRule(rule) then do
        sigp = "*"
        if rule~hasIndex("signal_pattern") then sigp = rule~at("signal_pattern")
        installKey = installKey || "::SIGNAL::" || self~safeString(sigp)~translate
      end
      else if self~isUnknownMethodTripwireRule(rule) then installKey = installKey || "::UNKNOWN_TRIPWIRE"
      else if self~isReturnTransformProxyRule(rule) then installKey = installKey || "::RETURN_PROXY"
      else if self~isUpstreamDispatchTraceRule(rule) then installKey = installKey || "::UPSTREAM_DISPATCH_TRACE"
      if objectInstalled~hasIndex(installKey) then iterate

      if self~isUnknownMethodTripwireRule(rule) then do
        rec = self~installOneUnknownMethodTripwire(obj, oid, path, cname, rule)
      end
      else if self~isReturnTransformProxyRule(rule) then do
        rec = self~installOneReturnTransformProxy(obj, oid, path, cname, methodName, rule)
      end
      else if self~isUpstreamDispatchTraceRule(rule) then do
        rec = self~recordUpstreamDispatchTraceFallback(obj, oid, path, cname, methodName, rule)
      end
      else if self~isSignalTriggerRule(rule) then do
        rec = self~installOneSignalTrigger(obj, oid, path, cname, methodName, rule)
      end
      else do
        rec = self~installOneMethodTrigger(obj, oid, path, cname, methodName, rule)
      end
      if rec \== .nil then do
        installed~append(rec)
        objectInstalled~put(.true, installKey)
      end
    end
  end

  if objectInstalled~items > 0 then triggerInstalled~put(objectInstalled, obj)
  return installed

::method isSignalTriggerRule private
  use strict arg rule

  if rule == .nil then return .false
  k = rule~at("kind")
  if k == .nil then return .false
  k = self~safeString(k)~translate
  if k = "TRIGGER_INSPECTION_ON_SIGNAL" then return .true
  if k = "TRACE_ON_SIGNAL" then return .true
  return .false
::method isReturnTransformProxyRule private
  use strict arg rule
  if rule == .nil then return .false
  k = rule~at("kind")
  if k == .nil then return .false
  return self~safeString(k)~translate = "RETURN_TRANSFORM_PROXY"
::method isUpstreamDispatchTraceRule private
  use strict arg rule
  if rule == .nil then return .false
  k = rule~at("kind")
  if k == .nil then return .false
  return self~safeString(k)~translate = "UPSTREAM_DISPATCH_TRACE"
::method isUnknownMethodTripwireRule private
  use strict arg rule
  if rule == .nil then return .false
  k = rule~at("kind")
  if k == .nil then return .false
  return self~safeString(k)~translate = "UNKNOWN_METHOD_TRIPWIRE"
::method isInstallableTriggerRule private
  use strict arg rule

  if self~isMethodTriggerRule(rule) then return .true
  if self~isSignalTriggerRule(rule) then return .true
  if self~isUnknownMethodTripwireRule(rule) then return .true
  return .false

::method installOneUnknownMethodTripwire private
  use strict arg obj, oid, path, cname, rule

  if self~safeLogical(self~safeSend1(obj, "hasMethod", "UNKNOWN", .false)) then do
    rec = .directory~new
    rec~put("unknown_method_existing", "trigger_kind")
    rec~put(cname, "class")
    rec~put(path, "path")
    rec~put(oid, "object_oid")
    rec~put("existing_unknown_method_present", "status")
    return rec
  end

  safeClass = self~classSafeName(cname)
  hiddenName = self~PROBE_PREFIX || "UNKNOWN_TRIPWIRE_" || safeClass || "_" || oid
  triggerKey = hiddenName || "_UNKNOWN"
  wrapperSource = self~buildUnknownMethodTripwireSource(triggerKey, rule)
  wrapperMethod = self~runtimeMethodFromSource("UNKNOWN", wrapperSource)

  installed = .false
  installMode = ""
  failure = ""
  signal on syntax name unknownDirectFailed
  obj~setMethod("UNKNOWN", wrapperMethod)
  installed = .true
  installMode = "direct-setMethod-unknown-tripwire"
  signal off syntax
  signal unknownInstalledOk

unknownDirectFailed:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  failure = self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O"))
  if self~hasPublicInstallHook(obj) then do
    args = .array~new
    args~append("UNKNOWN")
    args~append(wrapperMethod)
    args~append("OBJECT")
    hook1 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    if self~safeLogical(hook1) then do
      installed = .true
      installMode = "cooperative-hook-unknown-tripwire"
    end
  end

unknownInstalledOk:
  if installed \== .true then do
    self~addWarning("UNKNOWN tripwire install failed at " || path || " class=" || cname || " direct=" || failure)
    return .nil
  end

  meta = .directory~new
  meta~put(self, "inspector")
  meta~put(rule, "rule")
  meta~put("unknown_method", "trigger_kind")
  meta~put(cname, "class")
  meta~put(path, "path")
  meta~put(oid, "object_oid")
  meta~put(installMode, "install_mode")
  if rule~hasIndex("unknown_action") then meta~put(rule~at("unknown_action"), "unknown_action")

  reg = self~triggerRegistry
  reg~put(meta, triggerKey)

  rec = .directory~new
  rec~put(triggerKey, "trigger_key")
  rec~put("unknown_method", "trigger_kind")
  rec~put(cname, "class")
  rec~put(path, "path")
  rec~put(oid, "object_oid")
  rec~put(installMode, "install_mode")
  if rule~hasIndex("unknown_action") then rec~put(rule~at("unknown_action"), "unknown_action")
  return rec

::method buildUnknownMethodTripwireSource private
  use strict arg triggerKey, rule

  action = "report"
  if rule~hasIndex("unknown_action") then action = self~safeString(rule~at("unknown_action"))~translate
  src = .array~new
  src~append("__icUnknownName = ''")
  src~append("if arg() >= 1 then __icUnknownName = arg(1)")
  src~append("__icUnknownArgs = .array~new")
  src~append("if arg() >= 2 then do")
  src~append("  __icSuppliedArgs = arg(2)")
  src~append("  signal on syntax name __icUnknownArgsFallback")
  src~append("  if __icSuppliedArgs \== .nil then do")
  src~append("    do __icA = 1 to __icSuppliedArgs~items")
  src~append("      __icUnknownArgs~append(__icSuppliedArgs~at(__icA))")
  src~append("    end")
  src~append("  end")
  src~append("  signal off syntax")
  src~append("  signal __icUnknownArgsReady")
  src~append("end")
  src~append("__icUnknownArgsFallback:")
  src~append("signal off syntax")
  src~append("do __icA = 2 to arg()")
  src~append("  __icUnknownArgs~append(arg(__icA))")
  src~append("end")
  src~append("__icUnknownArgsReady:")
  src~append("signal on syntax name __icUnknownRecordFailed")
  src~append("__icReg = .local~at('INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY')")
  src~append("__icMeta = __icReg~at(" || self~sourceLiteral(triggerKey) || ")")
  src~append("__icInspector = __icMeta~at('inspector')")
  src~append("__icInspector~recordUnknownMethod(" || self~sourceLiteral(triggerKey) || ", self, __icUnknownName, __icUnknownArgs)")
  src~append("signal off syntax")
  if action = "RAISE" | action = "REPORT_RAISE" | action = "PROHIBIT" then do
    src~append("raise syntax 97.1 array ('Inspector Clouseau trapped UNKNOWN message ' || __icUnknownName)")
  end
  src~append("return .nil")
  src~append("__icUnknownRecordFailed:")
  src~append("signal off syntax")
  if action = "RAISE" | action = "REPORT_RAISE" | action = "PROHIBIT" then do
    src~append("raise syntax 97.1 array ('Inspector Clouseau trapped UNKNOWN message ' || __icUnknownName)")
  end
  src~append("return .nil")
  return src

::method recordUnknownMethod public
  expose unknownMethodEvents triggerCounter
  use strict arg triggerKey, targetObject, unknownName, unknownArgs

  triggerCounter = triggerCounter + 1
  meta = self~safeAt(self~triggerRegistry, triggerKey, .nil)
  ev = .directory~new
  ev~put("alchemy.oorexx.inspector-clouseau.unknown-method-event.v1", "schema")
  ev~put(triggerCounter, "sequence")
  ev~put(self~nowIso, "generated_at")
  ev~put(triggerKey, "trigger_key")
  ev~put(self~safeString(unknownName), "unknown_message")
  ev~put(self~safeClassName(targetObject), "target_class")
  ev~put(self~returnProxyArgsSummary(unknownArgs), "args")
  if meta \== .nil then do
    if meta~hasIndex("class") then ev~put(meta~at("class"), "class")
    if meta~hasIndex("path") then ev~put(meta~at("path"), "path")
    if meta~hasIndex("object_oid") then ev~put(meta~at("object_oid"), "object_oid")
    if meta~hasIndex("install_mode") then ev~put(meta~at("install_mode"), "install_mode")
    if meta~hasIndex("unknown_action") then ev~put(meta~at("unknown_action"), "unknown_action")
    if meta~hasIndex("rule") then self~copyTraceGroupMetadata(ev, meta~at("rule"), meta)
  end
  unknownMethodEvents~append(ev)

  rule = .nil
  if meta \== .nil then do
    if meta~hasIndex("rule") then rule = meta~at("rule")
  end
  writeReport = .true
  if rule \== .nil then do
    if rule~hasIndex("write_report") then writeReport = self~safeLogical(rule~at("write_report"))
  end
  if writeReport then self~triggerInspection(triggerKey, targetObject, ev)
  return ev

::method installOneReturnTransformProxy private
  use strict arg obj, oid, path, cname, methodName, rule

  cls = self~safeSend0(obj, "class", .nil)
  original = self~safeSend1(obj, "instanceMethod", methodName, .nil)
  if original == .nil then original = self~safeMethodLookup(cls, methodName)
  if original == .nil then return .nil

  originalLines = self~sourceLinesForMethod(original)
  safeClass = self~classSafeName(cname)
  safeMethod = self~classSafeName(methodName)
  hiddenName = self~PROBE_PREFIX || "PROXIED_" || safeClass || "_" || safeMethod || "_" || oid
  triggerKey = hiddenName || "_RETURN_PROXY"

  if originalLines == .nil then do
    self~recordReturnProxySkipped(triggerKey, cname, methodName, path, oid, "source_unavailable", rule)
    return .nil
  end
  if self~methodContainsForward(originalLines) then do
    self~recordReturnProxySkipped(triggerKey, cname, methodName, path, oid, "forward_present", rule)
    return .nil
  end

  evidence = self~returnTransformEvidence(originalLines)
  if \evidence~hasIndex("matched") | evidence~at("matched") \== .true then do
    self~recordReturnProxySkipped(triggerKey, cname, methodName, path, oid, "no_inline_return_transform", rule)
    return .nil
  end

  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then return .nil

  wrapperSource = self~buildReturnProxyWrapperSource(triggerKey, hiddenName, rule)
  wrapperMethod = self~runtimeMethodFromSource(methodName, wrapperSource)

  installed = .false
  installMode = ""
  failure = ""
  signal on syntax name returnProxyDirectFailed
  obj~setMethod(hiddenName, original)
  obj~setMethod(methodName, wrapperMethod)
  installed = .true
  installMode = "direct-setMethod-return-proxy"
  signal off syntax
  signal returnProxyInstalledOk

returnProxyDirectFailed:
  signal off syntax
  signal on syntax name __icRtpRollbackDone
  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then
    obj~setMethod(hiddenName, .Method~new(hiddenName, "return .nil"))
__icRtpRollbackDone:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  failure = self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O"))
  if self~hasPublicInstallHook(obj) then do
    args = .array~new
    args~append(hiddenName)
    args~append(original)
    args~append("OBJECT")
    hook1 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    args = .array~new
    args~append(methodName)
    args~append(wrapperMethod)
    args~append("OBJECT")
    hook2 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    if self~safeLogical(hook1) & self~safeLogical(hook2) then do
      installed = .true
      installMode = "cooperative-hook-return-proxy"
    end
  end

returnProxyInstalledOk:
  if installed \== .true then do
    self~addWarning("Return-transform proxy install failed at " || path || " class=" || cname || " method=" || methodName || " direct=" || failure)
    self~recordReturnProxySkipped(triggerKey, cname, methodName, path, oid, "install_failed", rule)
    return .nil
  end

  meta = .directory~new
  meta~put(self, "inspector")
  meta~put(rule, "rule")
  meta~put("return_transform_proxy", "trigger_kind")
  meta~put(cname, "class")
  meta~put(methodName, "method")
  meta~put(path, "path")
  meta~put(oid, "object_oid")
  meta~put(hiddenName, "hidden_method")
  meta~put(original, "original_method_object")
  meta~put(installMode, "install_mode")
  meta~put(evidence, "return_transform")
  reg = self~triggerRegistry
  reg~put(meta, triggerKey)

  rec = .directory~new
  rec~put(triggerKey, "trigger_key")
  rec~put("return_transform_proxy", "trigger_kind")
  rec~put(cname, "class")
  rec~put(methodName, "method")
  rec~put(hiddenName, "hidden_method")
  rec~put(installMode, "install_mode")
  rec~put(path, "path")
  rec~put(evidence, "return_transform")
  return rec

::method buildReturnProxyWrapperSource private
  use strict arg triggerKey, hiddenName, rule

  src = .array~new
  src~append("__icArgs = .array~new")
  src~append("do __icI = 1 to arg()")
  src~append("  if arg(__icI, 'E') then __icArgs~append(arg(__icI))")
  src~append("  else __icArgs~append(.nil)  /* omitted optional arg: preserve position */")
  src~append("end")
  src~append("__icResult = self~sendWith(" || self~sourceLiteral(hiddenName) || ", __icArgs)")
  src~append("signal on syntax name __icProxyRecordFailed")
  src~append("__icEvidence = .directory~new")
  src~append("__icEvidence~put('ok', 'status')")
  src~append("__icReg = .local~at('INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY')")
  src~append("__icMeta = __icReg~at(" || self~sourceLiteral(triggerKey) || ")")
  src~append("__icInspector = __icMeta~at('inspector')")
  src~append("__icInspector~recordReturnProxy(" || self~sourceLiteral(triggerKey) || ", self, __icArgs, __icResult, __icEvidence)")
  src~append("signal off syntax")
  src~append("return __icResult")
  src~append("__icProxyRecordFailed:")
  src~append("signal off syntax")
  src~append("return __icResult")
  return src

::method recordReturnProxy public
  expose returnProxyEvents triggerCounter
  use strict arg triggerKey, targetObject, args, result, evidence = .nil

  triggerCounter = triggerCounter + 1
  meta = self~safeAt(self~triggerRegistry, triggerKey, .nil)
  ev = .directory~new
  ev~put("alchemy.oorexx.inspector-clouseau.return-proxy-event.v1", "schema")
  ev~put(triggerCounter, "sequence")
  ev~put(self~nowIso, "generated_at")
  ev~put(triggerKey, "trigger_key")
  if meta \== .nil then do
    if meta~hasIndex("class") then ev~put(meta~at("class"), "class")
    if meta~hasIndex("method") then ev~put(meta~at("method"), "method")
    if meta~hasIndex("path") then ev~put(meta~at("path"), "path")
    if meta~hasIndex("object_oid") then ev~put(meta~at("object_oid"), "object_oid")
    if meta~hasIndex("install_mode") then ev~put(meta~at("install_mode"), "install_mode")
    if meta~hasIndex("return_transform") then ev~put(meta~at("return_transform"), "return_transform")
    if meta~hasIndex("rule") then self~copyTraceGroupMetadata(ev, meta~at("rule"), meta)
  end
  ev~put(self~safeClassName(targetObject), "target_class")
  ev~put(self~returnProxyArgsSummary(args), "args")
  ev~put(self~safeClassName(result), "result_class")
  ev~put(self~safeString(result), "result_string")
  if evidence \== .nil then ev~put(evidence, "evidence")
  returnProxyEvents~append(ev)

  rule = .nil
  if meta \== .nil then do
    if meta~hasIndex("rule") then rule = meta~at("rule")
  end
  writeReport = .true
  if rule \== .nil then do
    if rule~hasIndex("write_report") then writeReport = self~safeLogical(rule~at("write_report"))
  end
  if writeReport then self~triggerInspection(triggerKey, targetObject, ev)
  return ev

::method recordReturnProxySkipped private
  expose returnProxyEvents triggerCounter
  use strict arg triggerKey, cname, methodName, path, oid, reason, rule

  triggerCounter = triggerCounter + 1
  ev = .directory~new
  ev~put("alchemy.oorexx.inspector-clouseau.return-proxy-skip.v1", "schema")
  ev~put(triggerCounter, "sequence")
  ev~put(self~nowIso, "generated_at")
  ev~put(triggerKey, "trigger_key")
  ev~put(cname, "class")
  ev~put(methodName, "method")
  ev~put(path, "path")
  ev~put(oid, "object_oid")
  ev~put(reason, "status")
  if rule \== .nil then self~copyTraceGroupMetadata(ev, rule, .nil)
  if reason = "source_unavailable" | reason = "forward_present" then ev~put(self~upstreamCallSitePlan(methodName), "upstream_dispatch_candidates")
  returnProxyEvents~append(ev)
  return ev

::method recordUpstreamDispatchTraceFallback private
  use strict arg obj, oid, path, cname, methodName, rule

  rec = .directory~new
  rec~put("upstream_dispatch_trace_plan", "trigger_kind")
  rec~put(cname, "class")
  rec~put(methodName, "method")
  rec~put(path, "path")
  rec~put(oid, "object_oid")
  rec~put(self~upstreamCallSitePlan(methodName), "upstream_dispatch_candidates")
  return rec

::method upstreamCallSitePlan private
  expose methods
  use strict arg methodName

  out = .array~new
  do m over methods
    if out~items >= 50 then leave
    if m == .nil then iterate
    cname = ""
    mname = ""
    if m~hasIndex("class") then cname = m~at("class")
    if m~hasIndex("method") then mname = m~at("method")
    if cname = "" | mname = "" then iterate
    if mname~translate = self~safeString(methodName)~translate then iterate
    rec = .directory~new
    rec~put(cname, "class")
    rec~put(mname, "method")
    rec~put("candidate_from_loaded_method_index", "status")
    out~append(rec)
  end
  return out

::method returnProxyArgsSummary private
  use strict arg args
  out = .array~new
  if args == .nil then return out
  signal on syntax name argsDone
  do i = 1 to args~items
    rec = .directory~new
    v = args~at(i)
    rec~put(i, "index")
    rec~put(self~safeClassName(v), "class")
    rec~put(self~safeString(v), "string")
    out~append(rec)
  end
argsDone:
  signal off syntax
  return out

::method returnTransformEvidence private
  use strict arg lines

  ev = .directory~new
  ev~put(.false, "matched")
  ev~put("", "reason")
  if lines == .nil then do
    ev~put("source_unavailable", "reason")
    return ev
  end
  if self~methodContainsForward(lines) then do
    ev~put("forward_present", "reason")
    return ev
  end
  blockState = .array~new
  blockState~append(.false)
  lineNo = 0
  chars = "+-*/(~|"
  do line over lines
    lineNo = lineNo + 1
    cleaned = self~cleanRexxLine(line, blockState)~strip
    if cleaned = "" then iterate
    upper = cleaned~translate~strip
    parse value upper with first .
    if first \= "RETURN" then iterate
    expr = cleaned~substr(7)~strip
    if expr = "" then iterate
    do ci = 1 to chars~length
      ch = chars~substr(ci, 1)
      if expr~pos(ch) > 0 then do
        ev~put(.true, "matched")
        ev~put(lineNo, "line")
        ev~put(cleaned, "return_line")
        ev~put(expr, "return_expression")
        ev~put(ch, "matched_token")
        ev~put("inline_return_transform", "reason")
        return ev
      end
    end
  end
  ev~put("no_inline_return_transform", "reason")
  return ev

::method methodContainsForward private
  use strict arg lines
  if lines == .nil then return .false
  blockState = .array~new
  blockState~append(.false)
  do line over lines
    cleaned = self~cleanRexxLine(line, blockState)~translate~strip
    if cleaned = "" then iterate
    parse value cleaned with first .
    if first = "FORWARD" then return .true
    if cleaned~pos(" FORWARD ") > 0 then return .true
  end
  return .false

::method installOneSignalTrigger private
  use strict arg obj, oid, path, cname, methodName, rule

  cls = self~safeSend0(obj, "class", .nil)
  original = self~safeSend1(obj, "instanceMethod", methodName, .nil)
  if original == .nil then original = self~safeMethodLookup(cls, methodName)
  if original == .nil then return .nil

  originalLines = self~sourceLinesForMethod(original)
  if originalLines == .nil then return .nil

  profile = self~scanSignals(originalLines)
  targetLabels = self~signalHookLabelsForRule(profile, rule)
  if targetLabels~items = 0 then return .nil

  safeClass = self~classSafeName(cname)
  safeMethod = self~classSafeName(methodName)
  signalPattern = "*"
  if rule~hasIndex("signal_pattern") then signalPattern = rule~at("signal_pattern")
  safeSignal = self~classSafeName(signalPattern)
  hiddenName = self~PROBE_PREFIX || "ORIGINAL_SIGNAL_" || safeClass || "_" || safeMethod || "_" || safeSignal || "_" || oid
  wrapperName = methodName

  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then return .nil

  triggerKey = hiddenName || "_TRIGGER"
  wrapperSource = self~buildSignalTriggerMethodSource(triggerKey, originalLines, targetLabels, rule)
  wrapperMethod = self~runtimeMethodFromSource(wrapperName, wrapperSource)

  installed = .false
  installMode = ""
  failure = ""

  signal on syntax name directFailed
  obj~setMethod(hiddenName, original)
  obj~setMethod(wrapperName, wrapperMethod)
  installed = .true
  installMode = "direct-setMethod-method-object"
  signal off syntax
  signal installedOk

directFailed:
  signal off syntax
  /* Rollback: if the hidden stash was installed before the wrapper failed,
     replace it with a no-op so the object is not left in a half-wired state. */
  signal on syntax name __icRollbackDone
  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then
    obj~setMethod(hiddenName, .Method~new(hiddenName, "return .nil"))
__icRollbackDone:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  failure = self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O"))
  if self~hasPublicInstallHook(obj) then do
    args = .array~new
    args~append(hiddenName)
    args~append(original)
    args~append("OBJECT")
    hook1 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    args = .array~new
    args~append(wrapperName)
    args~append(wrapperMethod)
    args~append("OBJECT")
    hook2 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    if self~safeLogical(hook1) & self~safeLogical(hook2) then do
      installed = .true
      installMode = "cooperative-hook"
    end
  end

installedOk:
  if installed \== .true then do
    self~addWarning("Signal trigger install failed at " || path || " class=" || cname || " method=" || methodName || " signal=" || signalPattern || " direct=" || failure)
    return .nil
  end

  meta = .directory~new
  meta~put(self, "inspector")
  meta~put(rule, "rule")
  if self~safeString(rule~at("kind"))~translate = "TRACE_ON_SIGNAL" then meta~put("signal_trace", "trigger_kind")
  else meta~put("signal", "trigger_kind")
  meta~put(cname, "class")
  meta~put(methodName, "method")
  meta~put(signalPattern, "signal_pattern")
  meta~put(targetLabels, "signal_labels")
  meta~put(path, "path")
  meta~put(oid, "object_oid")
  meta~put(hiddenName, "hidden_method")
  meta~put(original, "original_method_object")
  meta~put(wrapperName, "wrapper_method")
  meta~put(installMode, "install_mode")

  reg = self~triggerRegistry
  reg~put(meta, triggerKey)

  rec = .directory~new
  rec~put(triggerKey, "trigger_key")
  if self~safeString(rule~at("kind"))~translate = "TRACE_ON_SIGNAL" then rec~put("signal_trace", "trigger_kind")
  else rec~put("signal", "trigger_kind")
  rec~put(cname, "class")
  rec~put(methodName, "method")
  rec~put(signalPattern, "signal_pattern")
  rec~put(targetLabels, "signal_labels")
  rec~put(hiddenName, "hidden_method")
  rec~put(installMode, "install_mode")
  rec~put(path, "path")
  if rule~hasIndex("condition_variable") then rec~put(rule~at("condition_variable"), "condition_variable")
  if rule~hasIndex("condition_equals") then rec~put(rule~at("condition_equals"), "condition_equals")
  return rec

::method signalHookLabelsForRule private
  use strict arg profile, rule

  out = .array~new
  seen = .directory~new
  pattern = "*"
  if rule~hasIndex("signal_pattern") then pattern = rule~at("signal_pattern")

  labels = self~safeSend1(profile, "at", "labels", .array~new)
  directTargets = self~safeSend1(profile, "at", "direct_signal_targets", .array~new)
  do sigLabel over self~safeIterable(labels)
    l = self~normalizeSignalLabel(sigLabel)
    if l = "" then iterate
    if pattern = "*" then do
      self~appendSignalName(out, seen, l)
      iterate
    end
    if self~rulePatternMatches(pattern, l) then do
      self~appendSignalName(out, seen, l)
      iterate
    end
    do target over self~safeIterable(directTargets)
      if self~normalizeSignalLabel(target) = l then do
        if self~rulePatternMatches(pattern, target) then self~appendSignalName(out, seen, l)
      end
    end
    do h over self~safeIterable(self~safeSend1(profile, "at", "signal_named_handlers", .array~new))
      if \h~hasIndex("label") then iterate
      if self~normalizeSignalLabel(h~at("label")) \= l then iterate
      if h~hasIndex("condition") then do
        if self~rulePatternMatches(pattern, h~at("condition")) | self~rulePatternMatches(pattern, h~at("label")) then self~appendSignalName(out, seen, l)
      end
    end
    do h over self~safeIterable(self~safeSend1(profile, "at", "call_named_handlers", .array~new))
      if \h~hasIndex("label") then iterate
      if self~normalizeSignalLabel(h~at("label")) \= l then iterate
      if h~hasIndex("condition") then do
        if self~rulePatternMatches(pattern, h~at("condition")) | self~rulePatternMatches(pattern, h~at("label")) then self~appendSignalName(out, seen, l)
      end
    end
  end
  return out

::method buildSignalTriggerMethodSource private
  use strict arg triggerKey, originalLines, targetLabels, rule

  conditionVariable = ""
  conditionEquals = ""
  hasEquals = .false
  if rule~hasIndex("condition_variable") then conditionVariable = self~normalizeSlotToken(rule~at("condition_variable"))
  if rule~hasIndex("condition_has_equals") then do
    hasEquals = self~safeLogical(rule~at("condition_has_equals"))
    if rule~hasIndex("condition_equals") then conditionEquals = self~safeString(rule~at("condition_equals"))
  end

  labelSet = .directory~new
  do sigLabel over targetLabels
    labelSet~put(.true, self~normalizeSignalLabel(sigLabel))
  end

  /* Block comment state must be tracked across lines so that label-like text
     inside slash-star block comments does not trigger spurious hook injection.
     Use the same mutable-array pattern as returnTransformEvidence. */
  blockState = .array~new
  blockState~append(.false)

  src = .array~new
  do line over originalLines
    src~append(line)
    cleaned = self~cleanRexxLine(line, blockState)~translate~strip
    if cleaned~right(1) = ":" then do
      label = self~normalizeSignalLabel(cleaned~left(cleaned~length - 1))
      if labelSet~hasIndex(label) then do
        self~appendSignalTriggerBlock(src, triggerKey, label, conditionVariable, conditionEquals, hasEquals, rule)
      end
    end
  end
  return src

::method appendSignalTriggerBlock private
  use strict arg src, triggerKey, label, conditionVariable, conditionEquals, hasEquals, rule

  safeLabel = self~classSafeName(label)
  failLabel = "__icSignalTriggerFailed_" || safeLabel
  afterLabel = "__icAfterSignalTrigger_" || safeLabel
  condFailLabel = "__icConditionObjectFailed_" || safeLabel
  condAfterLabel = "__icAfterConditionObject_" || safeLabel
  src~append("/* Inspector Clouseau signal hook: " || label || " */")
  src~append("__icSignalEvidence = .directory~new")
  src~append("__icSignalEvidence~put('alchemy.oorexx.inspector-clouseau.signal-evidence.v1', 'schema')")
  src~append("__icSignalEvidence~put(" || self~sourceLiteral(label) || ", 'label')")
  src~append("if symbol('RC') = 'VAR' then __icSignalEvidence~put(rc, 'rc')")
  src~append("if symbol('SIGL') = 'VAR' then __icSignalEvidence~put(sigl, 'sigl')")
  src~append("signal on syntax name " || condFailLabel)
  src~append("__icConditionObject = condition('O')")
  src~append("if __icConditionObject \== .nil then do")
  src~append("  __icSignalEvidence~put(__icConditionObject~condition, 'condition')")
  src~append("  __icSignalEvidence~put(__icConditionObject~description, 'description')")
  src~append("  __icSignalEvidence~put(__icConditionObject~instruction, 'instruction')")
  src~append("  __icSignalEvidence~put(__icConditionObject~program, 'program')")
  src~append("  __icSignalEvidence~put(__icConditionObject~errortext, 'error_text')")
  src~append("  __icSignalEvidence~put(__icConditionObject~code, 'code')")
  src~append("end")
  src~append("signal off syntax")
  src~append("signal " || condAfterLabel)
  src~append(condFailLabel || ":")
  src~append("signal off syntax")
  src~append("__icSignalEvidence~put('condition-object-read-failed', 'condition_object_status')")
  src~append(condAfterLabel || ":")
  src~append("__icSignalShould = .true")
  if conditionVariable \= "" then do
    src~append("if symbol('" || conditionVariable || "') \= 'VAR' then __icSignalShould = .false")
    if hasEquals then do
      src~append("else do")
      src~append("  __icSignalValueString = " || conditionVariable || "~string")
      src~append("  if __icSignalValueString \= " || self~sourceLiteral(conditionEquals) || " then __icSignalShould = .false")
      src~append("end")
    end
  end
  src~append("if __icSignalShould then do")
  if rule~hasIndex("collect_trace") then do
    if self~safeLogical(rule~at("collect_trace")) then do
      src~append("  __icTraceCollection = .array~new")
      src~append("  signal on syntax name " || failLabel)
      src~append("  .TraceObject~collector = __icTraceCollection")
      src~append("  .TraceObject~option = 'S'")
      src~append("  trace R")
      src~append("  trace Off")
      src~append("  signal off syntax")
    end
  end
  src~append("  signal on syntax name " || failLabel)
  src~append("  __icReg = .local~at('INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY')")
  src~append("  __icMeta = __icReg~at(" || self~sourceLiteral(triggerKey) || ")")
  src~append("  __icMeta~put(" || self~sourceLiteral(label) || ", 'fired_signal')")
  src~append("  __icInspector = __icMeta~at('inspector')")
  if rule~hasIndex("collect_trace") then do
    if self~safeLogical(rule~at("collect_trace")) then src~append("  __icInspector~recordTraceCollection(" || self~sourceLiteral(triggerKey) || ", self, __icTraceCollection, 'signal')")
  end
  src~append("  __icInspector~triggerInspection(" || self~sourceLiteral(triggerKey) || ", self, __icSignalEvidence)")
  src~append("  signal off syntax")
  src~append("end")
  src~append("signal " || afterLabel)
  src~append(failLabel || ":")
  src~append("signal off syntax")
  src~append(afterLabel || ":")

::method installOneMethodTrigger private
  use strict arg obj, oid, path, cname, methodName, rule

  cls = self~safeSend0(obj, "class", .nil)
  original = self~safeSend1(obj, "instanceMethod", methodName, .nil)
  if original == .nil then original = self~safeMethodLookup(cls, methodName)
  if original == .nil then return .nil

  safeClass = self~classSafeName(cname)
  safeMethod = self~classSafeName(methodName)
  hiddenName = self~PROBE_PREFIX || "ORIGINAL_" || safeClass || "_" || safeMethod || "_" || oid
  wrapperName = methodName

  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then return .nil

  triggerKey = hiddenName || "_TRIGGER"
  wrapperSource = self~buildMethodTriggerWrapperSource(triggerKey, hiddenName, rule)
  wrapperMethod = self~runtimeMethodFromSource(wrapperName, wrapperSource)

  installed = .false
  installMode = ""
  failure = ""

  signal on syntax name directFailed
  obj~setMethod(hiddenName, original)
  obj~setMethod(wrapperName, wrapperMethod)
  installed = .true
  installMode = "direct-setMethod-method-object"
  signal off syntax
  signal installedOk

directFailed:
  signal off syntax
  signal on syntax name __icMtRollbackDone
  if self~safeLogical(self~safeSend1(obj, "hasMethod", hiddenName, .false)) then
    obj~setMethod(hiddenName, .Method~new(hiddenName, "return .nil"))
__icMtRollbackDone:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  failure = self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O"))
  if self~hasPublicInstallHook(obj) then do
    args = .array~new
    args~append(hiddenName)
    args~append(original)
    args~append("OBJECT")
    hook1 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    args = .array~new
    args~append(wrapperName)
    args~append(wrapperMethod)
    args~append("OBJECT")
    hook2 = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_INSTALL", args, .false)
    if self~safeLogical(hook1) & self~safeLogical(hook2) then do
      installed = .true
      installMode = "cooperative-hook"
    end
  end

installedOk:
  if installed \== .true then do
    self~addWarning("Method trigger install failed at " || path || " class=" || cname || " method=" || methodName || " direct=" || failure)
    return .nil
  end

  meta = .directory~new
  meta~put(self, "inspector")
  meta~put(rule, "rule")
  if self~safeString(rule~at("kind"))~translate = "TRACE_ON_METHOD" then meta~put("method_trace", "trigger_kind")
  else meta~put("method", "trigger_kind")
  meta~put(cname, "class")
  meta~put(methodName, "method")
  meta~put(path, "path")
  meta~put(oid, "object_oid")
  meta~put(hiddenName, "hidden_method")
  meta~put(original, "original_method_object")
  meta~put(wrapperName, "wrapper_method")
  meta~put(installMode, "install_mode")

  reg = self~triggerRegistry
  reg~put(meta, triggerKey)

  rec = .directory~new
  rec~put(triggerKey, "trigger_key")
  if self~safeString(rule~at("kind"))~translate = "TRACE_ON_METHOD" then rec~put("method_trace", "trigger_kind")
  else rec~put("method", "trigger_kind")
  rec~put(cname, "class")
  rec~put(methodName, "method")
  rec~put(hiddenName, "hidden_method")
  rec~put(installMode, "install_mode")
  rec~put(path, "path")
  if rule~hasIndex("condition_variable") then rec~put(rule~at("condition_variable"), "condition_variable")
  if rule~hasIndex("condition_equals") then rec~put(rule~at("condition_equals"), "condition_equals")
  return rec

::method triggerRegistry private
  signal on syntax name makeRegistry
  reg = .local~at("INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY")
  signal off syntax
  if reg \== .nil then return reg

makeRegistry:
  signal off syntax
  reg = .directory~new
  .local~put(reg, "INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY")
  return reg

::method buildMethodTriggerWrapperSource private
  use strict arg triggerKey, hiddenName, rule

  conditionVariable = ""
  conditionEquals = ""
  hasEquals = .false
  collectTrace = .false
  if rule~hasIndex("condition_variable") then conditionVariable = self~normalizeSlotToken(rule~at("condition_variable"))
  if rule~hasIndex("condition_has_equals") then do
    hasEquals = self~safeLogical(rule~at("condition_has_equals"))
    if rule~hasIndex("condition_equals") then conditionEquals = self~safeString(rule~at("condition_equals"))
  end
  if rule~hasIndex("collect_trace") then collectTrace = self~safeLogical(rule~at("collect_trace"))

  src = .array~new
  if conditionVariable \= "" then src~append("expose " || conditionVariable)
  /* Collect args for trace path only.  Non-trace uses bare FORWARD which
     preserves the original argument list including omitted optional args.
     Using arg(__icI) without the 'E' existence check raises SYNTAX rc=88
     on omitted optional arguments and breaks the caller. */
  if collectTrace then do
    src~append("__icArgs = .array~new")
    src~append("do __icI = 1 to arg()")
    src~append("  if arg(__icI, 'E') then __icArgs~append(arg(__icI))")
    src~append("  else __icArgs~append(.nil)  /* omitted optional arg: preserve position */")
    src~append("end")
  end
  src~append("__icShould = .true")
  if conditionVariable \= "" then do
    src~append("if symbol('" || conditionVariable || "') \= 'VAR' then __icShould = .false")
    if hasEquals then do
      src~append("else do")
      src~append("  __icValueString = " || conditionVariable || "~string")
      src~append("  if __icValueString \= " || self~sourceLiteral(conditionEquals) || " then __icShould = .false")
      src~append("end")
    end
  end

  if collectTrace then do
    src~append("__icTraceCollection = .array~new")
    src~append("__icTraceEnabled = .false")
    src~append("if __icShould then do")
    src~append("  signal on syntax name __icTraceSetupFailed")
    src~append("  .TraceObject~collector = __icTraceCollection")
    src~append("  .TraceObject~option = 'S'")
    src~append("  __icTraceEnabled = .true")
    src~append("  signal off syntax")
    src~append("end")
    src~append("signal __icAfterTraceSetup")
    src~append("__icTraceSetupFailed:")
    src~append("signal off syntax")
    src~append("__icTraceEnabled = .false")
    src~append("__icAfterTraceSetup:")
    src~append("if __icTraceEnabled then trace R")
    src~append("__icResult = self~sendWith(" || self~sourceLiteral(hiddenName) || ", __icArgs)")
    src~append("if __icTraceEnabled then trace Off")
    src~append("if __icShould then do")
    src~append("  signal on syntax name __icTriggerFailed")
    src~append("  __icReg = .local~at('INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY')")
    src~append("  __icMeta = __icReg~at(" || self~sourceLiteral(triggerKey) || ")")
    src~append("  __icInspector = __icMeta~at('inspector')")
    src~append("  if __icTraceEnabled then __icInspector~recordTraceCollection(" || self~sourceLiteral(triggerKey) || ", self, __icTraceCollection, 'method')")
    src~append("  __icInspector~triggerInspection(" || self~sourceLiteral(triggerKey) || ", self)")
    src~append("  signal off syntax")
    src~append("end")
    src~append("signal __icAfterTrigger")
    src~append("__icTriggerFailed:")
    src~append("signal off syntax")
    src~append("__icAfterTrigger:")
    src~append("return __icResult")
    return src
  end

  src~append("if __icShould then do")
  src~append("  signal on syntax name __icTriggerFailed")
  src~append("  __icReg = .local~at('INSPECTOR_CLOUSEAU_TRIGGER_REGISTRY')")
  src~append("  __icMeta = __icReg~at(" || self~sourceLiteral(triggerKey) || ")")
  src~append("  __icInspector = __icMeta~at('inspector')")
  src~append("  __icInspector~triggerInspection(" || self~sourceLiteral(triggerKey) || ", self)")
  src~append("  signal off syntax")
  src~append("end")
  src~append("signal __icAfterTrigger")
  src~append("__icTriggerFailed:")
  src~append("signal off syntax")
  src~append("__icAfterTrigger:")
  /* FORWARD without ARGUMENTS preserves the original argument list verbatim,
     including omitted optional args.  Never pass __icArgs here. */
  src~append("forward to (self) message (" || self~sourceLiteral(hiddenName) || ")")
  return src


::method copyTraceGroupMetadata private
  use arg target, rule, meta
  if target == .nil then return target
  signal on syntax name copyTraceGroupDone
  keys = .array~of("trace_group", "bundle_id", "trace_goal", "trace_step", "trace_role", "path_from", "path_to", "planner", "planner_reason", "route_class", "route_object_path", "request_id", "trace_request_source")
  if rule \== .nil then do
    do k over keys
      if rule~hasIndex(k) then target~put(rule~at(k), k)
    end
  end
  if meta \== .nil then do
    if meta~hasIndex("trigger_kind") then target~put(meta~at("trigger_kind"), "trigger_kind")
    if meta~hasIndex("class") then target~put(meta~at("class"), "class")
    if meta~hasIndex("method") then target~put(meta~at("method"), "method")
    if meta~hasIndex("path") then target~put(meta~at("path"), "path")
  end
copyTraceGroupDone:
  signal off syntax
  return target

::method recordTraceCollection
  expose traceReports
  use arg triggerKey, triggeringObject, traceCollection, traceContext

  if arg() < 4 then traceContext = "method"
  rec = .directory~new
  rec~put("alchemy.oorexx.inspector-clouseau.trace-collection.v1", "schema")
  rec~put(triggerKey, "trigger_key")
  rec~put(traceContext, "context")
  rec~put(self~nowIso, "generated_at")
  meta = self~safeAt(self~triggerRegistry, triggerKey, .nil)
  rule = .nil
  if meta \== .nil then rule = meta~at("rule")
  self~copyTraceGroupMetadata(rec, rule, meta)
  if triggeringObject \== .nil then do
    rec~put(self~safeClassName(triggeringObject), "trigger_object_class")
    rec~put(self~oidFor(triggeringObject), "trigger_object_oid")
  end

  events = .array~new
  count = 0
  if traceCollection \== .nil then do
    count = self~safeSend0(traceCollection, "items", 0)
    n = 0
    do traceEvt over self~safeIterable(traceCollection)
      n = n + 1
      if n > 500 then leave
      events~append(self~traceEventAsDirectory(traceEvt, n))
    end
    if count > 500 then rec~put(count - 500, "truncated_events")
  end
  rec~put(count, "items")
  rec~put(events, "events")
  traceReports~append(rec)
  return rec
::method traceEventAsDirectory private
  use arg traceEvt, seq

  d = .directory~new
  d~put(seq, "sequence")
  d~put(self~safeClassName(traceEvt), "class")
  d~put(self~safeString(traceEvt), "string")
  d~put(self~safeSend0(traceEvt, "line", ""), "line")
  d~put(self~safeSend0(traceEvt, "thread", ""), "thread")
  d~put(self~safeSend0(traceEvt, "program", ""), "program")
  d~put(self~safeSend0(traceEvt, "instruction", ""), "instruction")
  d~put(self~safeSend0(traceEvt, "package", ""), "package")
  d~put(self~safeSend0(traceEvt, "method", ""), "method")
  d~put(self~safeSend0(traceEvt, "routine", ""), "routine")
  return d

::method triggerInspection
  expose triggerActive triggerCounter triggerEvents callChainReports
  use strict arg triggerKey, triggeringObject = .nil, triggerEvidence = .nil

  if triggerActive == .true then return .false
  triggerActive = .true
  signal on syntax name triggerFailed
  triggerCounter = triggerCounter + 1

  meta = self~safeAt(self~triggerRegistry, triggerKey, .nil)
  event = .directory~new
  event~put(triggerKey, "trigger_key")
  event~put(triggerCounter, "sequence")
  event~put(self~nowIso, "generated_at")
  rule = .nil
  if meta \== .nil then do
    if meta~hasIndex("rule") then rule = meta~at("rule")
    if meta~hasIndex("class") then event~put(meta~at("class"), "class")
    if meta~hasIndex("method") then event~put(meta~at("method"), "method")
    if meta~hasIndex("trigger_kind") then event~put(meta~at("trigger_kind"), "trigger_kind")
    if meta~hasIndex("signal_pattern") then event~put(meta~at("signal_pattern"), "signal_pattern")
    if meta~hasIndex("fired_signal") then event~put(meta~at("fired_signal"), "fired_signal")
    if meta~hasIndex("path") then event~put(meta~at("path"), "path")
    if meta~hasIndex("object_oid") then event~put(meta~at("object_oid"), "object_oid")
  end
  if rule \== .nil then self~copyTraceGroupMetadata(event, rule, meta)
  if triggerEvidence \== .nil then do

    event~put(triggerEvidence, "trigger_evidence")
    if self~safeClassName(triggerEvidence)~translate~pos("DIRECTORY") > 0 then do
      if triggerEvidence~hasIndex("rc") then event~put(triggerEvidence~at("rc"), "rc")
      if triggerEvidence~hasIndex("sigl") then event~put(triggerEvidence~at("sigl"), "sigl")
      if triggerEvidence~hasIndex("condition") then event~put(triggerEvidence~at("condition"), "condition")
      if triggerEvidence~hasIndex("description") then event~put(triggerEvidence~at("description"), "description")
      if triggerEvidence~hasIndex("error_text") then event~put(triggerEvidence~at("error_text"), "error_text")
      if triggerEvidence~hasIndex("code") then event~put(triggerEvidence~at("code"), "code")
      if triggerEvidence~hasIndex("instruction") then event~put(triggerEvidence~at("instruction"), "instruction")
      if triggerEvidence~hasIndex("program") then event~put(triggerEvidence~at("program"), "program")
    end
  end
  if triggeringObject \== .nil then do
    event~put(self~safeClassName(triggeringObject), "trigger_object_class")
    event~put(self~oidFor(triggeringObject), "trigger_object_oid")
  end
  triggerEvents~append(event)

  prefix = "inspector-clouseau-trigger"
  writeJson = .true
  writeText = .true
  if rule \== .nil then do
    if rule~hasIndex("report_prefix") then prefix = self~safeString(rule~at("report_prefix"))
    if rule~hasIndex("write_json") then writeJson = self~safeLogical(rule~at("write_json"))
    if rule~hasIndex("write_text") then writeText = self~safeLogical(rule~at("write_text"))
  end

  sourceTrail = self~captureMethodParentSourceTrail(triggerKey, triggeringObject, meta, rule, event)
  if sourceTrail \== .nil then callChainReports~append(sourceTrail)

  self~refreshLiveObjectGraphForTrigger(triggeringObject, event)
  snap = .InspectorSnapshot~new(self~asDirectory)
  base = self~safeFileStem(prefix || "-" || triggerCounter)
  if writeJson then snap~writeJson(base || ".json")
  if writeText then snap~writeText(base || ".txt")

  signal off syntax
  triggerActive = .false
  return .true

triggerFailed:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  self~addWarning("Method trigger report failed for key=" || triggerKey || " condition=" || self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O")))
  triggerActive = .false
  return .false

::method isMethodTriggerRule private
  use strict arg rule

  if rule == .nil then return .false
  if \rule~hasIndex("kind") then return .false
  k = self~safeString(rule~at("kind"))~translate
  if k = "TRIGGER_INSPECTION_ON_METHOD" then return .true
  if k = "TRIGGER_SOURCE_TRAIL_ON_METHOD" then return .true
  if k = "TRACE_ON_METHOD" then return .true
  if k = "RETURN_TRANSFORM_PROXY" then return .true
  if k = "UPSTREAM_DISPATCH_TRACE" then return .true
  return .false

::method captureMethodParentSourceTrail private
  use strict arg triggerKey, triggeringObject, meta, rule, event

  if rule == .nil then return .nil
  capture = .false
  if rule~hasIndex("capture_source_trail") then capture = self~safeLogical(rule~at("capture_source_trail"))
  if self~safeString(rule~at("kind"))~translate = "TRIGGER_SOURCE_TRAIL_ON_METHOD" then capture = .true
  if capture \== .true then return .nil

  report = .directory~new
  report~put("alchemy.oorexx.inspector-clouseau.method-parent-source-trail.v1", "schema")
  report~put(triggerKey, "trigger_key")
  if event \== .nil then do
    if event~hasIndex("sequence") then report~put(event~at("sequence"), "sequence")
    if event~hasIndex("generated_at") then report~put(event~at("generated_at"), "generated_at")
  end

  target = .directory~new
  if meta \== .nil then do
    if meta~hasIndex("class") then target~put(meta~at("class"), "class")
    if meta~hasIndex("method") then target~put(meta~at("method"), "method")
    if meta~hasIndex("path") then target~put(meta~at("path"), "path")
    if meta~hasIndex("object_oid") then target~put(meta~at("object_oid"), "object_oid")
    if meta~hasIndex("original_method_object") then do
      tm = meta~at("original_method_object")
      target~put(self~methodSourceRecord(tm, 0, rule), "source")
    end
  end
  if triggeringObject \== .nil then do
    target~put(self~safeClassName(triggeringObject), "live_object_class")
    target~put(self~oidFor(triggeringObject), "live_object_oid")
  end
  report~put(target, "target")

  stop = .directory~new
  stopClass = "*"
  stopMethod = "*"
  if rule~hasIndex("stop_class_pattern") then stopClass = rule~at("stop_class_pattern")
  if rule~hasIndex("stop_method_pattern") then stopMethod = rule~at("stop_method_pattern")
  stop~put(stopClass, "class_pattern")
  stop~put(stopMethod, "method_pattern")
  report~put(stop, "stop")

  frames = .array~new
  rawFrames = self~safeSend0(.context, "stackFrames", .nil)
  maxFrames = self~ruleInteger(rule, "max_stack_frames", 12)
  count = 0
  stopped = .false
  if rawFrames \== .nil then do
    do frame over self~safeIterable(rawFrames)
      count = count + 1
      if count > maxFrames then leave
      frec = self~stackFrameSourceRecord(frame, count, rule)
      frames~append(frec)
      if self~frameMatchesStop(frec, stopClass, stopMethod) then do
        stopped = .true
        leave
      end
    end
  end
  report~put(frames, "frames")
  report~put(stopped, "stopped_at_parent")
  if rawFrames == .nil then report~put("stackFrames unavailable from .context", "note")
  return report

::method stackFrameSourceRecord private
  use strict arg frame, depth, rule

  rec = .directory~new
  rec~put(depth, "depth")
  rec~put(self~safeClassName(frame), "frame_class")

  name = self~firstNonEmptySend0(frame, "name methodName method routine executableName")
  rec~put(name, "name")

  line = self~firstNonNilSend0(frame, "line lineNumber sourceLine")
  if line \== .nil then rec~put(self~safeString(line), "line")

  executable = self~firstNonNilSend0(frame, "executable method routine")
  if executable \== .nil then do
    rec~put(self~safeClassName(executable), "executable_class")
    pkg = self~safeSend0(executable, "package", .nil)
    rec~put(self~packageIdentity(pkg), "package")
    rec~put(self~methodSourceRecord(executable, line, rule), "source")
  end
  else do
    rec~put(.false, "source_available")
    rec~put("source_unavailable_no_executable_on_stack_frame", "opaque_reason")
  end

  return rec

::method methodSourceRecord private
  use strict arg methodObj, lineHint = 0, rule = .nil

  rec = .directory~new
  if methodObj == .nil then do
    rec~put(.false, "source_available")
    rec~put("nil_method_object", "opaque_reason")
    return rec
  end

  rec~put(self~safeClassName(methodObj), "method_object_class")
  pkg = self~safeSend0(methodObj, "package", .nil)
  rec~put(self~packageIdentity(pkg), "package")
  lines = self~sourceLinesForMethod(methodObj)
  if lines == .nil then do
    rec~put(.false, "source_available")
    rec~put("source_unavailable", "opaque_reason")
    return rec
  end

  rec~put(.true, "source_available")
  rec~put(lines~items, "source_line_count")
  rec~put(self~sourceExcerpt(lines, lineHint, self~ruleInteger(rule, "source_radius", 4)), "excerpt")
  return rec

::method sourceExcerpt private
  use strict arg lines, lineHint = 0, radius = 4

  out = .array~new
  total = lines~items
  focus = 1
  lineText = self~safeString(lineHint)
  if lineText~datatype("W") then focus = lineText + 0
  if focus < 1 | focus > total then focus = 1

  start = focus - radius
  if start < 1 then start = 1
  finish = focus + radius
  if finish > total then finish = total
  if total > 0 & lineText = "" then do
    finish = total
    if finish > (radius * 2 + 1) then finish = radius * 2 + 1
  end

  do i = start to finish
    lineRec = .directory~new
    lineRec~put(i, "line")
    lineRec~put(self~safeString(lines~at(i)), "text")
    if i = focus then lineRec~put(.true, "focus")
    out~append(lineRec)
  end
  return out

::method frameMatchesStop private
  use strict arg frameRec, classPattern, methodPattern

  cname = ""
  mname = ""
  if frameRec~hasIndex("class") then cname = frameRec~at("class")
  if frameRec~hasIndex("frame_class") then cname = frameRec~at("frame_class")
  if frameRec~hasIndex("method") then mname = frameRec~at("method")
  if frameRec~hasIndex("name") then mname = frameRec~at("name")

  if \self~rulePatternMatches(classPattern, cname) then return .false
  if \self~rulePatternMatches(methodPattern, mname) then return .false
  return .true

::method ruleInteger private
  use strict arg rule, key, defaultValue

  if rule == .nil then return defaultValue
  v = rule~at(key)
  if v == .nil then return defaultValue
  s = self~safeString(v)
  if s~datatype("W") then return s + 0
  return defaultValue
::method firstNonEmptySend0 private
  use strict arg obj, names

  rest = names
  do while rest \= ""
    parse var rest n rest
    if n = "" then iterate
    v = self~safeSend0(obj, n, "")
    sv = self~safeString(v)
    if sv \= "" then return sv
  end
  return ""

::method firstNonNilSend0 private
  use strict arg obj, names

  rest = names
  do while rest \= ""
    parse var rest n rest
    if n = "" then iterate
    v = self~safeSend0(obj, n, .nil)
    if v \== .nil then return v
  end
  return .nil

::method refreshLiveObjectGraphForTrigger private
  expose roots objects objectQueue edges queues findings variableReports walkedObjects visitedObjects oidCounter
  use strict arg triggeringObject, event

  objects = .directory~new
  objectQueue = .queue~new
  edges = .array~new
  queues = .array~new
  findings = .array~new
  variableReports = .array~new
  walkedObjects = .identityTable~new
  visitedObjects = .identityTable~new
  oidCounter = 0

  do r over roots
    objectQueue~append(self~makeObjectWork(r~at("object"), "root:" || r~at("name"), .nil, r~at("name"), 0))
  end
  if triggeringObject \== .nil then objectQueue~append(self~makeObjectWork(triggeringObject, "trigger:" || event~at("trigger_key"), .nil, "trigger", 0))

  self~walkObjectUniverse
  self~detectIdentityFindings

::method sourceLiteral private
  use strict arg value

  s = self~safeString(value)
  out = "'"
  do i = 1 to s~length
    ch = s~substr(i, 1)
    if ch = "'" then out = out || "''"
    else out = out || ch
  end
  out = out || "'"
  return out

::method safeFileStem private
  use strict arg value

  s = self~safeString(value)
  out = ""
  do i = 1 to s~length
    ch = s~substr(i, 1)
    if ch~datatype("M") | ch~datatype("W") | ch = "-" | ch = "_" | ch = "." then out = out || ch
    else out = out || "_"
  end
  if out = "" then out = "inspector-clouseau-trigger"
  return out

::method runtimeMethodFromSource private
  /* ooRexx object~setMethod() in the BSF4ooRexx/Alchemy runtime wants a
     Method object.  Passing an Array of source lines triggers rc=98 with
     additional=an Array on many live application objects. */
  use strict arg methodName, source

  if source == .nil then return .nil
  cname = self~safeClassName(source)~translate
  if cname~pos("METHOD") > 0 then return source

  sourceText = self~sourceTextForRuntimeMethod(source)
  signal on syntax name methodBuildFailed
  m = .Method~new(self~safeString(methodName), sourceText)
  signal off syntax
  return m

methodBuildFailed:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  self~addWarning("Runtime method build failed name=" || self~safeString(methodName) || " source_class=" || self~safeClassName(source) || " condition=" || self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O")))
  return sourceText

::method sourceTextForRuntimeMethod private
  use strict arg source

  if source == .nil then return ""
  cname = self~safeClassName(source)~translate
  if cname~pos("ARRAY") > 0 then do
    out = ""
    do line over source
      if out = "" then out = self~safeString(line)
      else out = out || '0a'x || self~safeString(line)
    end
    return out
  end
  return self~safeString(source)

::method buildProbeSource private
  use strict arg probeName, slots

  src = .array~new
  if slots~items > 0 then do
    exposeLine = "expose"
    do slot over slots
      exposeLine = exposeLine || " " || slot
    end
    src~append(exposeLine)
  end
  src~append("use strict arg")
  src~append("__ic = .directory~new")
  src~append("__icSlots = .directory~new")
  src~append("__icMissing = .array~new")
  src~append("__ic~put('alchemy.oorexx.inspector-clouseau.probe.v1', 'schema')")
  src~append("__ic~put('" || probeName || "', 'probe_name')")
  do slot over slots
    src~append("if symbol('" || slot || "') = 'VAR' then do")
    src~append("  __icSlots~put(" || slot || ", '" || slot || "')")
    src~append("end")
    src~append("else do")
    src~append("  __icMissing~append('" || slot || "')")
    src~append("end")
  end
  src~append("__ic~put(__icSlots, 'slots')")
  src~append("__ic~put(__icMissing, 'missing')")
  src~append("return __ic")
  return src

::method removeProbeMethod private
  use strict arg obj, probeName, installMode = ""

  if installMode = "cooperative-hook" then do
    if self~hasPublicUninstallHook(obj) then do
      args = .array~new
      args~append(probeName)
      hookResult = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_UNINSTALL", args, .false)
      if self~safeLogical(hookResult) then return .true
    end
  end

  signal on syntax name unsetFailed
  obj~unsetMethod(probeName)
  signal off syntax
  return .true

unsetFailed:
  signal off syntax
  if self~hasPublicUninstallHook(obj) then do
    args = .array~new
    args~append(probeName)
    hookResult = self~safeSendArgs(obj, "__INSPECTOR_CLOUSEAU_UNINSTALL", args, .false)
    if self~safeLogical(hookResult) then return .true
  end

  signal on syntax name setNilFailed
  obj~setMethod(probeName)
  signal off syntax
  return .true

setNilFailed:
  signal off syntax
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  self~addWarning("Unable to remove probe method " || probeName || " from object " || self~safeClassName(obj) || " condition=" || self~conditionSummary(condition("C"), condition("D"), condition("A"), __icRC, __icSIGL, condition("O")))
  return .false

::method summarizeProbeResult private
  expose variableReports
  use strict arg result, probeName, requestedSlots, ownerOid = "", ownerPath = ""

  if result == .nil then return .nil

  rec = .directory~new
  rec~put(probeName, "probe_name")
  rec~put(.true, "injected")
  rec~put(requestedSlots, "requested_slots")

  slotSummary = .array~new
  slots = self~safeSend1(result, "at", "slots", .nil)
  if slots \== .nil then do
    do slotName over self~safeIndexes(slots)
      value = self~safeAt(slots, slotName, .nil)
      srec = .directory~new
      srec~put(self~safeString(slotName), "name")
      assignment = ownerPath || "." || self~safeString(slotName)
      srec~put(assignment, "assignment")
      if value == .nil then srec~put(.true, "nil")
      else do
        valueOid = self~oidFor(value)
        valueClass = self~safeClassName(value)
        valueKind = self~objectKind(value)
        valueString = self~safeString(value)
        srec~put(valueOid, "oid")
        srec~put(valueClass, "class")
        srec~put(valueKind, "kind")
        srec~put(valueString, "value")
        if self~isCollectionLike(value) then srec~put(self~safeString(self~safeSend0(value, "items", 0)), "items")

        if self~ruleEnabled("REPORT_VARIABLE", slotName) | self~ruleEnabled("REPORT_VARIABLE", assignment) then do
          vrec = .directory~new
          vrec~put(self~safeString(slotName), "variable")
          vrec~put(assignment, "assignment")
          vrec~put(ownerOid, "owner_oid")
          vrec~put(valueOid, "value_oid")
          vrec~put(valueClass, "class")
          vrec~put(valueKind, "kind")
          vrec~put(valueString, "value")
          if self~isCollectionLike(value) then vrec~put(self~safeString(self~safeSend0(value, "items", 0)), "items")
          variableReports~append(vrec)
        end
      end
      slotSummary~append(srec)
    end
  end
  rec~put(slotSummary, "slots")

  missing = self~safeSend1(result, "at", "missing", .array~new)
  rec~put(missing, "missing")
  return rec

::method enqueueProbeResultChildren private
  expose objectQueue
  use strict arg result, parentOid, path

  if result == .nil then return
  slots = self~safeSend1(result, "at", "slots", .nil)
  if slots == .nil then return
  do slotName over self~safeIndexes(slots)
    value = self~safeAt(slots, slotName, .nil)
    if value == .nil then iterate
    if self~shouldSkipObject(value) then iterate
    objectQueue~append(self~makeObjectWork(value, path || "." || self~safeString(slotName), parentOid, self~safeString(slotName), 0))
  end

::method enqueueProbeChildren private
  expose objectQueue
  use strict arg probe, parentOid, path, depth

  slots = self~safeSend1(probe, "at", "slots", .nil)
  if slots == .nil then return
  do slotRec over slots
    if slotRec~hasIndex("oid") then do
      /* The summary does not keep the raw object.  Re-open through the raw
         probe result is intentionally avoided, so this method is used only
         by future versions that keep a transient raw probe map. */
      nop
    end
  end


::class InspectorSnapshot public

::attribute data private

::method init
  expose data
  use strict arg data

::method asDirectory
  expose data
  return data

::method asText
  expose data

  lines = .array~new
  lines~append("Inspector Clouseau snapshot")
  lines~append("schema: " || data~at("schema"))
  lines~append("generated_at: " || data~at("generated_at"))
  lines~append("")

  if data~hasIndex("rules") then do
    lines~append("Rules: " || data~at("rules")~items)
    do rule over data~at("rules")
      kind = ""
      pattern = "*"
      value = ""
      if rule~hasIndex("kind") then kind = rule~at("kind")
      if rule~hasIndex("pattern") then pattern = rule~at("pattern")
      if rule~hasIndex("value") then value = rule~at("value")
      lines~append("  " || kind || " pattern=" || pattern || " value=" || value)
    end
    lines~append("")
  end

  shownObjects = 0
  suppressedObjects = 0
  objectLines = .array~new
  do obj over data~at("objects")
    if self~suppressObjectFromText(obj) then do
      suppressedObjects = suppressedObjects + 1
      iterate
    end
    line = "  " || obj~at("oid") || " " || obj~at("path") || " :: " || obj~at("class") || " kind=" || obj~at("kind")
    if obj~hasIndex("collection") then do
      coll = obj~at("collection")
      if coll~hasIndex("items") then line = line || " items=" || coll~at("items")
    end
    if obj~hasIndex("probe") then do
      probe = obj~at("probe")
      if probe~hasIndex("slots") then line = line || " probe_slots=" || probe~at("slots")~items
    end
    objectLines~append(line)
    shownObjects = shownObjects + 1
  end
  lines~append("Objects: " || data~at("objects")~items || " shown=" || shownObjects || " suppressed=" || suppressedObjects)
  do ol over objectLines
    lines~append(ol)
  end

  if data~hasIndex("inheritance_maps") then do
    if self~ruleEnabled("REPORT_INHERITANCE_MAP", "*") then do
      imap = data~at("inheritance_maps")
      shownClasses = 0
      suppressedClasses = 0
      classLines = .array~new
      if imap~hasIndex("classes") then do
        do cr over imap~at("classes")
          cname = ""
          pkg = ""
          if cr~hasIndex("class") then cname = cr~at("class")
          if cr~hasIndex("package") then pkg = cr~at("package")
          if self~ruleEnabled("SUPPRESS_INTERNAL_CLASS_METHODS", cname) then do
            if self~isInternalClassName(cname, pkg) then do
              suppressedClasses = suppressedClasses + 1
              iterate
            end
          end
          line = "  " || cname
          if cr~hasIndex("live_object_count") then line = line || " live=" || cr~at("live_object_count")
          if cr~hasIndex("lineage") then line = line || " lineage=" || self~joinArray(cr~at("lineage"), " -> ")
          classLines~append(line)
          if cr~hasIndex("method_counts") then do
            counts = cr~at("method_counts")
            countLine = "    method-resolution:"
            if counts~hasIndex("local_declared") then countLine = countLine || " local=" || counts~at("local_declared")
            if counts~hasIndex("local_override") then countLine = countLine || " overrides=" || counts~at("local_override")
            if counts~hasIndex("inherited_superclass") then countLine = countLine || " inherited-super=" || counts~at("inherited_superclass")
            if counts~hasIndex("inherited_mixin_or_secondary_superclass") then countLine = countLine || " inherited-mixin=" || counts~at("inherited_mixin_or_secondary_superclass")
            if counts~hasIndex("signal_or_condition_methods") then countLine = countLine || " signals=" || counts~at("signal_or_condition_methods")
            if counts~hasIndex("opaque_methods") then countLine = countLine || " opaque=" || counts~at("opaque_methods")
            classLines~append(countLine)
          end
          if cr~hasIndex("method_resolution") then do
            mr = cr~at("method_resolution")
            if mr~hasIndex("local_override") then do
              if mr~at("local_override")~items > 0 then classLines~append("    overrides: " || self~methodNamesSummary(mr~at("local_override"), 8))
            end
            if mr~hasIndex("signal_or_condition_methods") then do
              if mr~at("signal_or_condition_methods")~items > 0 then classLines~append("    signal methods: " || self~methodNamesSummary(mr~at("signal_or_condition_methods"), 8))
            end
          end
          shownClasses = shownClasses + 1
        end
      end
      lines~append("")
      edgeCount = 0
      hotspotCount = 0
      if imap~hasIndex("edges") then edgeCount = imap~at("edges")~items
      if imap~hasIndex("hotspots") then hotspotCount = imap~at("hotspots")~items
      lines~append("Inheritance map: shown=" || shownClasses || " suppressed=" || suppressedClasses || " edges=" || edgeCount || " hotspots=" || hotspotCount)
      do cl over classLines
        lines~append(cl)
      end
    end
  end

  lines~append("")
  lines~append("Collections:")
  collCount = 0
  do obj over data~at("objects")
    if \obj~hasIndex("collection") then iterate
    coll = obj~at("collection")
    if \coll~hasIndex("items") then iterate
    collCount = collCount + 1
    lines~append("  " || obj~at("oid") || " " || obj~at("path") || " class=" || obj~at("class") || " items=" || coll~at("items"))
  end
  if collCount = 0 then lines~append("  <none reported>")

  lines~append("")
  lines~append("Queues: " || data~at("queues")~items)
  do q over data~at("queues")
    lines~append("  " || q~at("oid") || " " || q~at("path") || " items=" || q~at("items"))
    if q~hasIndex("contents") then do
      do item over q~at("contents")
        itemLine = "    [" || item~at("index") || "]"
        if item~hasIndex("oid") then itemLine = itemLine || " " || item~at("oid") || " :: " || item~at("class") || " kind=" || item~at("kind")
        if item~hasIndex("value") then itemLine = itemLine || " value=" || item~at("value")
        if item~hasIndex("nil") then itemLine = itemLine || " nil"
        lines~append(itemLine)
      end
    end
  end



  if data~hasIndex("trace_request_events") then do
    lines~append("")
    lines~append("Trace request files: " || data~at("trace_request_events")~items)
    do tre over data~at("trace_request_events")
      trLine = "  "
      if tre~hasIndex("status") then trLine = trLine || tre~at("status")
      if tre~hasIndex("rules_loaded") then trLine = trLine || " rules=" || tre~at("rules_loaded")
      if tre~hasIndex("path") then trLine = trLine || " path=" || tre~at("path")
      if tre~hasIndex("condition") then trLine = trLine || " condition=" || tre~at("condition")
      lines~append(trLine)
    end
  end

  if data~hasIndex("trace_request_load_reports") then do
    lines~append("")
    lines~append("Trace request load reports: " || data~at("trace_request_load_reports")~items)
    do lrep over data~at("trace_request_load_reports")
      lrLine = "  "
      if lrep~hasIndex("status") then lrLine = lrLine || lrep~at("status")
      if lrep~hasIndex("rules_loaded") then lrLine = lrLine || " rules=" || lrep~at("rules_loaded")
      if lrep~hasIndex("directory") then lrLine = lrLine || " dir=" || lrep~at("directory")
      if lrep~hasIndex("json_path") then lrLine = lrLine || " json=" || lrep~at("json_path")
      if lrep~hasIndex("condition") then lrLine = lrLine || " condition=" || lrep~at("condition")
      lines~append(lrLine)
    end
  end

  if data~hasIndex("security_events") then do
    lines~append("")
    lines~append("Security manager events: " || data~at("security_events")~items)
    do sev over data~at("security_events")
      seLine = "  #"
      if sev~hasIndex("sequence") then seLine = seLine || sev~at("sequence")
      if sev~hasIndex("manager") then seLine = seLine || " manager=" || sev~at("manager")
      if sev~hasIndex("operation") then seLine = seLine || " operation=" || sev~at("operation")
      if sev~hasIndex("action") then seLine = seLine || " action=" || sev~at("action")
      lines~append(seLine)
      if sev~hasIndex("reason") then lines~append("    reason=" || sev~at("reason"))
      if sev~hasIndex("evidence") then lines~append("    evidence=" || self~safeString(sev~at("evidence")))
    end
  end

  if data~hasIndex("return_proxy_events") then do
    lines~append("")
    lines~append("Return proxy events: " || data~at("return_proxy_events")~items)
    do rpe over data~at("return_proxy_events")
      rpLine = "  #"
      if rpe~hasIndex("sequence") then rpLine = rpLine || rpe~at("sequence")
      if rpe~hasIndex("class") then rpLine = rpLine || " class=" || rpe~at("class")
      if rpe~hasIndex("method") then rpLine = rpLine || " method=" || rpe~at("method")
      if rpe~hasIndex("status") then rpLine = rpLine || " status=" || rpe~at("status")
      if rpe~hasIndex("result_class") then rpLine = rpLine || " result_class=" || rpe~at("result_class")
      lines~append(rpLine)
      if rpe~hasIndex("result_string") then lines~append("    result=" || rpe~at("result_string"))
      if rpe~hasIndex("return_transform") then do
        rt = rpe~at("return_transform")
        if rt~hasIndex("return_line") then lines~append("    return_line=" || rt~at("return_line"))
      end
    end
  end

  if data~hasIndex("unknown_method_events") then do
    lines~append("")
    lines~append("UNKNOWN method events: " || data~at("unknown_method_events")~items)
    do ume over data~at("unknown_method_events")
      umLine = "  #"
      if ume~hasIndex("sequence") then umLine = umLine || ume~at("sequence")
      if ume~hasIndex("class") then umLine = umLine || " class=" || ume~at("class")
      if ume~hasIndex("unknown_message") then umLine = umLine || " message=" || ume~at("unknown_message")
      if ume~hasIndex("target_class") then umLine = umLine || " target=" || ume~at("target_class")
      if ume~hasIndex("unknown_action") then umLine = umLine || " action=" || ume~at("unknown_action")
      lines~append(umLine)
      if ume~hasIndex("path") then lines~append("    path=" || ume~at("path"))
      if ume~hasIndex("args") then lines~append("    args=" || ume~at("args")~items)
    end
  end

  if data~hasIndex("trigger_events") then do
    lines~append("")
    lines~append("Trigger events: " || data~at("trigger_events")~items)
    do ev over data~at("trigger_events")
      evLine = "  #" || ev~at("sequence") || " key=" || ev~at("trigger_key")
      if ev~hasIndex("class") then evLine = evLine || " class=" || ev~at("class")
      if ev~hasIndex("method") then evLine = evLine || " method=" || ev~at("method")
      if ev~hasIndex("trigger_kind") then evLine = evLine || " kind=" || ev~at("trigger_kind")
      if ev~hasIndex("signal_pattern") then evLine = evLine || " signal_pattern=" || ev~at("signal_pattern")
      if ev~hasIndex("fired_signal") then evLine = evLine || " fired_signal=" || ev~at("fired_signal")
      if ev~hasIndex("condition") then evLine = evLine || " condition=" || ev~at("condition")
      if ev~hasIndex("rc") then evLine = evLine || " rc=" || ev~at("rc")
      if ev~hasIndex("sigl") then evLine = evLine || " sigl=" || ev~at("sigl")
      if ev~hasIndex("code") then evLine = evLine || " code=" || ev~at("code")
      if ev~hasIndex("trigger_object_oid") then evLine = evLine || " oid=" || ev~at("trigger_object_oid")
      lines~append(evLine)
      if ev~hasIndex("description") then lines~append("    description=" || ev~at("description"))
      if ev~hasIndex("error_text") then lines~append("    error_text=" || ev~at("error_text"))
      if ev~hasIndex("instruction") then lines~append("    instruction=" || ev~at("instruction"))
      if ev~hasIndex("program") then lines~append("    program=" || ev~at("program"))
    end
  end

  if data~hasIndex("trace_reports") then do
    lines~append("")
    lines~append("Trace reports: " || data~at("trace_reports")~items)
    do tr over data~at("trace_reports")
      trLine = "  trigger="
      if tr~hasIndex("trigger_key") then trLine = trLine || tr~at("trigger_key")
      if tr~hasIndex("context") then trLine = trLine || " context=" || tr~at("context")
      if tr~hasIndex("items") then trLine = trLine || " events=" || tr~at("items")
      if tr~hasIndex("truncated_events") then trLine = trLine || " truncated=" || tr~at("truncated_events")
      lines~append(trLine)
      if tr~hasIndex("events") then do
        __icTraceShown = 0
        do tev over tr~at("events")
          __icTraceShown = __icTraceShown + 1
          if __icTraceShown > 10 then leave
          evLine = "    #" || tev~at("sequence")
          if tev~hasIndex("line") then evLine = evLine || " line=" || self~safeString(tev~at("line"))
          if tev~hasIndex("thread") then evLine = evLine || " thread=" || self~safeString(tev~at("thread"))
          if tev~hasIndex("instruction") then evLine = evLine || " instruction=" || self~safeString(tev~at("instruction"))
          lines~append(evLine)
        end
      end
    end
  end

  if data~hasIndex("call_chain_reports") then do
    lines~append("")
    lines~append("Method parent/source trails: " || data~at("call_chain_reports")~items)
    do cr over data~at("call_chain_reports")
      header = "  trigger="
      if cr~hasIndex("trigger_key") then header = header || cr~at("trigger_key")
      if cr~hasIndex("sequence") then header = header || " sequence=" || cr~at("sequence")
      lines~append(header)
      if cr~hasIndex("target") then do
        t = cr~at("target")
        tline = "    target"
        if t~hasIndex("class") then tline = tline || " class=" || t~at("class")
        if t~hasIndex("method") then tline = tline || " method=" || t~at("method")
        if t~hasIndex("path") then tline = tline || " path=" || t~at("path")
        lines~append(tline)
        if t~hasIndex("source") then self~appendSourceSummaryLines(lines, "      ", t~at("source"))
      end
      if cr~hasIndex("frames") then do
        do fr over cr~at("frames")
          fline = "    frame " || fr~at("depth")
          if fr~hasIndex("name") then fline = fline || " name=" || fr~at("name")
          if fr~hasIndex("line") then fline = fline || " line=" || fr~at("line")
          if fr~hasIndex("package") then fline = fline || " package=" || fr~at("package")
          lines~append(fline)
          if fr~hasIndex("source") then self~appendSourceSummaryLines(lines, "      ", fr~at("source"))
        end
      end
    end
  end

  if data~hasIndex("variable_reports") then do
    lines~append("")
    lines~append("Variables: " || data~at("variable_reports")~items)
    do v over data~at("variable_reports")
      line = "  " || v~at("assignment") || " variable=" || v~at("variable") || " oid=" || v~at("value_oid") || " class=" || v~at("class") || " kind=" || v~at("kind")
      if v~hasIndex("items") then line = line || " items=" || v~at("items")
      if v~hasIndex("value") then line = line || " value=" || v~at("value")
      lines~append(line)
    end
  end

  shown = 0
  suppressed = 0
  methodLines = .array~new
  do m over data~at("methods")
    if self~suppressMethodFromText(m) then do
      suppressed = suppressed + 1
      iterate
    end
    src = "source=no"
    if m~at("source_available") == .true then src = "source=yes"
    originText = ""
    if m~hasIndex("origin_kind") then do
      originText = " origin=" || m~at("origin_kind")
      if m~hasIndex("origin_from_class") then do
        if m~at("origin_from_class") \= "" then originText = originText || " from=" || m~at("origin_from_class")
      end
      if m~hasIndex("origin_from_relation") then do
        if m~at("origin_from_relation") \= "" then originText = originText || " via=" || m~at("origin_from_relation")
      end
      if m~hasIndex("origin") then do
        o = m~at("origin")
        if o~hasIndex("inherited_by_subclasses") then do
          ib = o~at("inherited_by_subclasses")
          if ib~items > 0 then originText = originText || " inherited_by=" || ib~items
        end
      end
    end
    signalText = ""
    if m~hasIndex("signal_names") then do
      sn = m~at("signal_names")
      if sn~items > 0 then do
        signalText = " signals="
        firstSig = .true
        do sig over sn
          if firstSig == .true then firstSig = .false
          else signalText = signalText || ","
          signalText = signalText || sig
        end
      end
    end
    methodLines~append("  " || m~at("class") || "::" || m~at("method") || " " || src || originText || signalText)
    if m~hasIndex("procedure_signal_rule_matches") then do
      do pmatch over m~at("procedure_signal_rule_matches")
        methodLines~append("    procedure-signal-rule signal=" || pmatch~at("signal") || " status=" || pmatch~at("status"))
      end
    end
    shown = shown + 1
  end

  originCounts = .directory~new
  do m over data~at("methods")
    ok = "unknown"
    if m~hasIndex("origin_kind") then ok = m~at("origin_kind")
    if originCounts~hasIndex(ok) then originCounts~put(originCounts~at(ok) + 1, ok)
    else originCounts~put(1, ok)
  end

  lines~append("")
  lines~append("Methods: " || data~at("methods")~items || " shown=" || shown || " suppressed=" || suppressed)
  if originCounts~items > 0 then do
    originLine = "  origins:"
    do ok over originCounts~allIndexes
      originLine = originLine || " " || ok || "=" || originCounts~at(ok)
    end
    lines~append(originLine)
  end
  do ml over methodLines
    lines~append(ml)
  end

  if data~hasIndex("warnings") then do
    lines~append("")
    lines~append("Warnings: " || data~at("warnings")~items)
    do w over data~at("warnings")
      if self~safeClassName(w)~translate~pos("DIRECTORY") > 0 then do
        if w~hasIndex("message") then lines~append("  " || w~at("message"))
        else lines~append("  " || self~safeString(w))
      end
      else lines~append("  " || self~safeString(w))
    end
  end

  text = ""
  do l over lines
    text = text || l || "0a"x
  end
  return text


::method joinArray private
  use strict arg arr, sep = ","

  text = ""
  first = .true
  do item over arr
    if first == .true then first = .false
    else text = text || sep
    text = text || self~safeString(item)
  end
  return text

::method methodNamesSummary private
  use strict arg arr, maxItems = 8

  text = ""
  count = 0
  do m over arr
    count = count + 1
    if count > maxItems then leave
    if text \= "" then text = text || ","
    if m~hasIndex("method") then text = text || m~at("method")
    else text = text || self~safeString(m)
    if m~hasIndex("from_class") then do
      if m~at("from_class") \= "" then text = text || "<-" || m~at("from_class")
    end
  end
  if arr~items > maxItems then text = text || ",..."
  if text = "" then text = "<none>"
  return text


::method appendSourceSummaryLines private
  use strict arg lines, prefix, sourceRec

  if sourceRec == .nil then return
  if \sourceRec~hasIndex("source_available") then return
  if sourceRec~at("source_available") \== .true then do
    reason = "source unavailable"
    if sourceRec~hasIndex("opaque_reason") then reason = sourceRec~at("opaque_reason")
    lines~append(prefix || reason)
    return
  end
  if sourceRec~hasIndex("package") then lines~append(prefix || "source package=" || sourceRec~at("package"))
  if sourceRec~hasIndex("excerpt") then do
    do ln over sourceRec~at("excerpt")
      marker = " "
      if ln~hasIndex("focus") then marker = ">"
      lines~append(prefix || marker || self~safeString(ln~at("line")) || ": " || self~safeString(ln~at("text")))
    end
  end

::method suppressObjectFromText private
  use strict arg obj

  path = obj~at("path"); if path == .nil then path = ""
  cname = obj~at("class"); if cname == .nil then cname = ""
  kind = obj~at("kind"); if kind == .nil then kind = ""

  if self~ruleEnabled("SUPPRESS_OBJECT_OUTPUT_FOR_PATH", path) then return .true
  if self~ruleEnabled("SUPPRESS_OBJECT_OUTPUT_FOR_CLASS", cname) then return .true
  if self~ruleEnabled("SUPPRESS_OBJECT_OUTPUT_FOR_KIND", kind) then return .true
  return .false
::method suppressMethodFromText private
  expose data
  use strict arg m

  cname = m~at("class"); if cname == .nil then cname = ""
  pkg = m~at("package"); if pkg == .nil then pkg = ""
  mname = m~at("method"); if mname == .nil then mname = ""

  if self~isProbeName(mname) then return .true
  if self~ruleEnabled("SUPPRESS_METHOD_OUTPUT", mname) then return .true
  if self~ruleEnabled("SUPPRESS_METHOD_OUTPUT_FOR_CLASS", cname) then return .true
  if self~ruleEnabled("SUPPRESS_METHOD_OUTPUT_FOR_CLASS", pkg) then return .true

  if self~ruleEnabled("SUPPRESS_INTERNAL_CLASS_METHODS", cname) then do
    if self~isInternalClassName(cname, pkg) then return .true
  end

  return .false
::method isInternalClassName private
  use strict arg cname, pkg = ""

  c = self~safeString(cname)~translate
  p = self~safeString(pkg)~translate
  if p = "REXX" then return .true
  if p = "" then do
    select
      when c = "OBJECT" then return .true
      when c = "CLASS" then return .true
      when c = "METHOD" then return .true
      when c = "PACKAGE" then return .true
      when c = "ROUTINE" then return .true
      when c = "STRING" then return .true
      when c = "ARRAY" then return .true
      when c = "DIRECTORY" then return .true
      when c = "QUEUE" then return .true
      when c = "REXXQUEUE" then return .true
      when c = "REXXCONTEXT" then return .true
      when c = "REXXINFO" then return .true
      when c = "STREAM" then return .true
      when c = "MONITOR" then return .true
      when c = "TABLE" then return .true
      when c = "LIST" then return .true
      when c = "BAG" then return .true
      when c = "SET" then return .true
      when c = "RELATION" then return .true
      when c = "STEM" then return .true
      otherwise nop
    end
  end
  return .false

::method ruleEnabled private
  expose data
  use strict arg kind, candidate = "*"

  rules = data~at("rules")
  if rules == .nil then return .false
  upperKind = self~safeString(kind)~translate
  result = .false
  do rule over rules
    enabled = rule~at("enabled")
    if enabled \== .true then iterate
    ruleKind = rule~at("kind")
    if ruleKind == .nil then iterate
    if self~safeString(ruleKind)~translate \= upperKind then iterate
    pattern = rule~at("pattern")
    if pattern == .nil then pattern = "*"
    if self~rulePatternMatches(pattern, candidate) then do
      val = rule~at("value")
      if val \== .nil then result = self~safeLogical(val)
      else result = .true
    end
  end
  return result
::method rulePatternMatches private
  use strict arg pattern, candidate

  p = self~safeString(pattern)~translate
  c = self~safeString(candidate)~translate
  if p = "" then return .false
  if p = "*" then return .true
  if p = c then return .true
  if p~left(1) = "*" & p~right(1) = "*" then do
    inner = p~substr(2, p~length - 2)
    if inner = "" then return .true
    return c~pos(inner) > 0
  end
  if p~left(1) = "*" then do
    suffix = p~substr(2)
    return c~right(suffix~length) = suffix
  end
  if p~right(1) = "*" then do
    prefix = p~left(p~length - 1)
    return c~left(prefix~length) = prefix
  end
  return c~pos(p) > 0

::method safeString private
  use strict arg v

  if v == .nil then return ""
  signal on syntax name failed
  s = v~string
  signal off syntax
  return s
failed:
  signal off syntax
  return "<string-unavailable>"

::method safeLogical private
  use strict arg v

  if v == .true then return .true
  if v == .false then return .false
  s = self~safeString(v)~translate
  if s = "1" | s = "TRUE" then return .true
  return .false


::method isProbeName private
  use strict arg name

  n = self~safeString(name)~translate
  if n~left(20) = "__INSPECTOR_CLOUSEAU" then return .true
  return .false

::method safeClassName private
  use strict arg obj

  if obj == .nil then return "NIL"
  signal on syntax name failed
  c = obj~class
  if c == .nil then return "<class-unavailable>"
  signal on syntax name failed2
  id = c~id
  signal off syntax
  signal off syntax
  return self~safeString(id)
failed2:
  signal off syntax
  signal off syntax
  return self~safeString(c)
failed:
  signal off syntax
  return "<class-unavailable>"

::method writeText
  use strict arg path

  signal on syntax name writeTextFailed
  signal on notready name writeTextFailed
  s = .stream~new(path)
  s~open("write replace")
  s~charout(self~asText)
  s~close
  signal off syntax
  signal off notready
  return path

writeTextFailed:
  signal off syntax
  signal off notready
  return .false

::method writeJson
  expose data
  use strict arg path

  writer = .InspectorJsonWriter~new
  jsonText = writer~encode(data)
  signal on syntax name writeJsonFailed
  signal on notready name writeJsonFailed
  s = .stream~new(path)
  s~open("write replace")
  s~charout(jsonText)
  s~close
  signal off syntax
  signal off notready
  return path

writeJsonFailed:
  signal off syntax
  signal off notready
  return .false

::class InspectorJsonWriter public

::method encode
  use strict arg data

  signal on syntax name encodeFailed
  return .json~toJson(data)

encodeFailed:
  signal off syntax
  /* Some json.cls versions expose the encoder under a different message. */
  signal on syntax name encodeFailedAgain
  j = .json~new
  return j~toJson(data)

encodeFailedAgain:
  signal off syntax
  raise syntax 93.900 array("json.cls writer does not expose toJson(data) in this environment")


::class InspectorTraceRequestAlarmTarget public inherit AlarmNotification

::method init public
  expose inspector
  use arg inspector

::method triggered public unguarded
  expose inspector
  use arg alarm
  if inspector \== .nil then inspector~traceRequestAlarmFired
  return .true

::class InspectorSnapshotAlarmTarget public inherit AlarmNotification

::method init public
  expose inspector
  use arg inspector

::method triggered public unguarded
  expose inspector
  use arg alarm
  if inspector \== .nil then inspector~snapshotAlarmFired
  return .true

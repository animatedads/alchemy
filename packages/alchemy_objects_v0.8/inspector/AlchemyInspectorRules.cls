/* AlchemyInspectorRules.cls -- tidy Alchemy integration for Inspector Clouseau, rebased for iter87.
   iter92: preserves staged install logging, traps NOTREADY, and captures
   condition evidence inline at handler labels before helper calls.

   This file is deliberately small.  InspectorClouseau.cls owns the machinery;
   this class owns the Alchemy-specific root set, rule policy, and report names.

   Enable with:
     ALCHEMY_INSPECTOR=1 rexx alchemy.rex text

   Optional:
     ALCHEMY_INSPECTOR_PROBES=1          allow in-scope object-variable probes
     ALCHEMY_INSPECTOR_TRACE_SIGNALS=1   collect TraceObject evidence on signal hooks
     ALCHEMY_INSPECTOR_METHOD_TRACE=1    collect TraceObject evidence on selected hot methods
     ALCHEMY_INSPECTOR_TRACE_REQUEST_DIR=dir load dropped JSON trace requests; default DATA_DIR/inspector-trace-requests
     ALCHEMY_INSPECTOR_TRACE_REQUEST_ALARM_SECONDS=5 rescan trace-request dir by ooRexx Alarm; 0 disables
     ALCHEMY_INSPECTOR_SNAPSHOT_ALARM_SECONDS=1800 write timestamped snapshots on an ooRexx Alarm; 0 disables
     ALCHEMY_INSPECTOR_STARTUP_SNAPSHOT=0 skip startup snapshot/write
     ALCHEMY_INSPECTOR_PREFIX=prefix     report prefix; default DATA_DIR/alchemy-inspector
     ALCHEMY_INSPECTOR_SECURITY_POLICY=file.json  handcuff policy file
     ALCHEMY_INSPECTOR_QUIET=1        silence Inspector startup announcement
     ALCHEMY_INSPECTOR_INSTALL_LOG=file  early install evidence log; default DATA_DIR/alchemy-inspector-install.log
*/

::class AlchemyInspectorRules public

::method install class public
  phase = "core"
  roots = .nil
  logger = .nil
  dataDir = "."
  stage = "entry"
  if arg() >= 1 then phase = arg(1)
  if arg() >= 2 then roots = arg(2)
  if arg() >= 3 then logger = arg(3)
  if arg() >= 4 then dataDir = arg(4)

  if \self~enabled then return .nil
  self~writeDiagnostic(dataDir, "install begin phase=" || phase || " roots=" || self~rootCount(roots))
  signal on syntax name installFailed

  stage = "create-inspector"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  inspector = .InspectorClouseau~new
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  stage = "announce"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  inspector~announce("Alchemy", phase, self~prefix(dataDir))
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  stage = "configure-rules"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  self~configure(inspector, phase, logger, dataDir)
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  stage = "attach-roots"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  self~attachRoots(inspector, roots)
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  stage = "attach-handcuffs"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  self~attachSecurityManagers(inspector, roots, dataDir, logger)
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  stage = "startup-snapshot"
  self~writeDiagnostic(dataDir, "install stage begin " || stage)
  self~writeSnapshot(inspector, phase, logger, dataDir)
  self~writeDiagnostic(dataDir, "install stage ok " || stage)

  self~writeDiagnostic(dataDir, "install ok phase=" || phase || " roots=" || self~rootCount(roots))
  self~logInfo(logger, "installed Inspector Clouseau phase=" || phase || " roots=" || self~rootCount(roots))
  return inspector

installFailed:
  __icC = condition("C")
  __icD = condition("D")
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  diag = self~formatCapturedCondition("Inspector Clouseau install failed", stage, __icC, __icD, __icRC, __icSIGL, condition("O"))
  self~writeDiagnostic(dataDir, diag)
  self~logFail(logger, diag)
  return .nil

::method attach class public
  phase = "attach"
  inspector = .nil
  roots = .nil
  logger = .nil
  dataDir = "."
  stage = "attach-entry"
  if arg() >= 1 then phase = arg(1)
  if arg() >= 2 then inspector = arg(2)
  if arg() >= 3 then roots = arg(3)
  if arg() >= 4 then logger = arg(4)
  if arg() >= 5 then dataDir = arg(5)

  if inspector == .nil then return .false
  if \self~enabled then return .false
  self~writeDiagnostic(dataDir, "attach begin phase=" || phase || " roots=" || self~rootCount(roots))
  signal on syntax name attachFailed

  stage = "attach-roots"
  self~writeDiagnostic(dataDir, "attach stage begin " || stage)
  self~attachRoots(inspector, roots)
  self~writeDiagnostic(dataDir, "attach stage ok " || stage)

  stage = "attach-snapshot"
  self~writeDiagnostic(dataDir, "attach stage begin " || stage)
  self~writeSnapshot(inspector, phase, logger, dataDir)
  self~writeDiagnostic(dataDir, "attach stage ok " || stage)

  self~writeDiagnostic(dataDir, "attach ok phase=" || phase || " roots=" || self~rootCount(roots))
  self~logInfo(logger, "attached Inspector Clouseau phase=" || phase || " roots=" || self~rootCount(roots))
  return .true

attachFailed:
  __icC = condition("C")
  __icD = condition("D")
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  diag = self~formatCapturedCondition("Inspector Clouseau attach failed phase=" || phase, stage, __icC, __icD, __icRC, __icSIGL, condition("O"))
  self~writeDiagnostic(dataDir, diag)
  self~logFail(logger, diag)
  return .false

::method enabled class public
  flag = translate(value("ALCHEMY_INSPECTOR",, "ENVIRONMENT"))
  if flag = "" then return .false
  if flag = "1" then return .true
  if flag = "TRUE" then return .true
  if flag = "YES" then return .true
  if flag = "ON" then return .true
  if flag = "INSPECT" then return .true
  return .false

::method envEnabled class private
  use strict arg name, defaultValue = .false
  flag = translate(value(name,, "ENVIRONMENT"))
  if flag = "" then return defaultValue
  if flag = "0" then return .false
  if flag = "FALSE" then return .false
  if flag = "NO" then return .false
  if flag = "OFF" then return .false
  return .true

::method configure class private
  use strict arg inspector, phase, logger, dataDir

  traceDir = self~traceRequestDir(dataDir)
  inspector~setTraceRequestDirectory(traceDir, self~prefix(dataDir) || "-trace-request")

  /* Evidence first, noise later. */
  inspector~reportQueueItems(.true)
  inspector~reportCollectionSizes(.true)
  inspector~reportCollectionItems(.true)
  inspector~reportInheritanceMap(.true)
  inspector~reportVariable("*QUEUE*")
  inspector~reportVariable("*AGENT*")
  inspector~reportVariable("*BRIDGE*")
  inspector~reportVariable("*OID*")
  inspector~reportVariable("*TIMER*")
  inspector~reportVariable("*LOGGER*")
  inspector~reportVariable("*SECURITY*")
  inspector~reportVariable("*CODELET*")

  /* Keep the human report readable while preserving JSON evidence. */
  inspector~dontFollowPackage("REXX")
  inspector~suppressInternalClassMethods(.true)
  inspector~suppressMethodOutput("__INSPECTOR_CLOUSEAU*")
  inspector~suppressMethodOutputForClass("STRING")
  inspector~suppressMethodOutputForClass("ARRAY")
  inspector~suppressMethodOutputForClass("QUEUE")
  inspector~suppressMethodOutputForClass("DIRECTORY")
  inspector~suppressObjectOutputForPath("root:.environment*")
  inspector~suppressObjectOutputForPath("root:.local[ENVIRONMENT]*")

  /* In-scope private-slot probes are useful but intentionally opt-in. */
  if self~envEnabled("ALCHEMY_INSPECTOR_PROBES", .false) then inspector~enableProbes(.true)

  /* Every source-visible named signal/condition handler becomes a report point.
     This is the important Alchemy insertion: when a trap fires, Clouseau captures
     RC, SIGL, CONDITION('O'), source trail, object graph, queues, and inheritance. */
  if self~envEnabled("ALCHEMY_INSPECTOR_TRACE_SIGNALS", .false) then
    inspector~collectTraceOnSignal("*", "*", "*", .nil, .nil, self~prefix(dataDir) || "-signal-trace")
  else
    inspector~createInspectionReportOnSignal("*", "*", "*", .nil, .nil, self~prefix(dataDir) || "-signal")

  /* Procedure/routine signals are scanned and reported.  Runtime routine
     replacement remains conservative in InspectorClouseau itself. */
  inspector~createInspectionReportOnProcedureSignal("*", "*", self~prefix(dataDir) || "-procedure-signal")

  /* Bug-hunting source trails on the points where Alchemy changes state or crosses
     process/provider/UI boundaries.  These are intentionally selective so normal
     chat traffic is not drowned in report files. */
  inspector~reportParentSourceTrailOnMethod("ALCHEMYAPPLICATION", "SENDMESSAGE", "*", "*", .nil, .nil, self~prefix(dataDir) || "-send-message")
  inspector~reportParentSourceTrailOnMethod("ALCHEMYAPPLICATION", "POLLALL", "*", "*", .nil, .nil, self~prefix(dataDir) || "-poll-all")
  inspector~reportParentSourceTrailOnMethod("ALCHEMYAPPLICATION", "POLLAGENT", "*", "*", .nil, .nil, self~prefix(dataDir) || "-poll-agent")
  inspector~reportParentSourceTrailOnMethod("AGENTREGISTRY", "ENQUEUE*", "*", "*", .nil, .nil, self~prefix(dataDir) || "-agent-enqueue")
  inspector~reportParentSourceTrailOnMethod("ALCHEMYAGENT", "RUNONE", "*", "*", .nil, .nil, self~prefix(dataDir) || "-agent-run-one")
  inspector~reportParentSourceTrailOnMethod("PLUGINCOMMANDROUTER", "HANDLELINE", "*", "*", .nil, .nil, self~prefix(dataDir) || "-plugin-command")
  inspector~reportParentSourceTrailOnMethod("MESSAGEBUS", "DISPATCH*", "*", "*", .nil, .nil, self~prefix(dataDir) || "-messagebus-dispatch")
  inspector~reportParentSourceTrailOnMethod("UIMIDDLEWAREDISPATCHER", "DISPATCH*", "*", "*", .nil, .nil, self~prefix(dataDir) || "-middleware-dispatch")

  if self~envEnabled("ALCHEMY_INSPECTOR_METHOD_TRACE", .false) then do
    inspector~collectTraceOnMethod("BRIDGEFACTORY", "MAKE", .nil, .nil, self~prefix(dataDir) || "-bridgefactory-make-trace")
    inspector~collectTraceOnMethod("HTTPJSONBRIDGE", "POSTJSON", .nil, .nil, self~prefix(dataDir) || "-http-postjson-trace")
    inspector~collectTraceOnMethod("OBJECTSTORE", "APPEND", .nil, .nil, self~prefix(dataDir) || "-objectstore-append-trace")
    inspector~collectTraceOnMethod("LIBRARIANREGISTRY", "QUEUEINDEX", .nil, .nil, self~prefix(dataDir) || "-librarian-queueindex-trace")
  end

  dropped = inspector~loadTraceRequestsFromDirectory(traceDir, self~prefix(dataDir) || "-trace-request", .true)
  self~logInfo(logger, "initial Inspector trace request load dir=" || traceDir || " rules=" || dropped)

  alarmSeconds = self~traceRequestAlarmSeconds
  if alarmSeconds > 0 then do
    inspector~startTraceRequestAlarm(alarmSeconds)
    self~logInfo(logger, "started Inspector trace request alarm dir=" || traceDir || " seconds=" || alarmSeconds)
  end

  snapshotSeconds = self~snapshotAlarmSeconds
  if snapshotSeconds > 0 then do
    inspector~startSnapshotAlarm(snapshotSeconds, phase, self~prefix(dataDir))
    self~logInfo(logger, "started Inspector scheduled snapshot alarm phase=" || phase || " seconds=" || snapshotSeconds)
  end

  return inspector

::method attachRoots class private
  inspector = .nil
  roots = .nil
  if arg() >= 1 then inspector = arg(1)
  if arg() >= 2 then roots = arg(2)

  if inspector == .nil then return 0
  if roots == .nil then return 0
  count = 0
  signal on syntax name attachDone
  keys = roots~allIndexes
  do i = 1 to keys~items
    key = keys~at(i)
    value = roots~at(key)
    if value == .nil then iterate
    ok = self~attachOneRoot(inspector, "alchemy:" || key, value)
    if ok then count = count + 1
  end
attachDone:
  return count

::method attachOneRoot class private
  inspector = .nil
  rootName = "attached"
  rootObject = .nil
  if arg() >= 1 then inspector = arg(1)
  if arg() >= 2 then rootName = arg(2)
  if arg() >= 3 then rootObject = arg(3)
  if inspector == .nil | rootObject == .nil then return .false
  signal on syntax name attachFailed
  inspector~attach(rootName, rootObject)
  return .true
attachFailed:
  return .false

::method attachSecurityManagers class private
  use strict arg inspector, roots, dataDir, logger

  if roots == .nil then return 0
  if inspector == .nil then return 0
  policyFile = value("ALCHEMY_INSPECTOR_SECURITY_POLICY",, "ENVIRONMENT")
  prefix = self~prefix(dataDir) || "-handcuffs"
  count = 0
  signal on syntax name securityAttachDone
  do key over roots~allIndexes
    obj = roots~at(key)
    if obj == .nil then iterate
    if translate("" || key) = "CODELETS" then do
      obj~attachInspector(inspector, policyFile, prefix)
      count = count + 1
      policyLabel = policyFile
      if policyLabel = "" then policyLabel = "default"
      self~logInfo(logger, "attached Inspector handcuffs to codelet manager policy=" || policyLabel)
    end
  end
securityAttachDone:
  return count

::method writeSnapshot class private
  use strict arg inspector, phase, logger, dataDir

  if \self~envEnabled("ALCHEMY_INSPECTOR_STARTUP_SNAPSHOT", .true) then return .false
  signal on syntax name writeFailed
  signal on notready name writeFailed

  dropped = inspector~checkTraceRequestsNow
  if dropped > 0 then self~logInfo(logger, "loaded Inspector trace requests before snapshot rules=" || dropped)
  snap = inspector~snapshot
  phaseToken = self~safeToken(phase)
  timestampedBase = self~prefix(dataDir) || "-" || phaseToken || "-" || self~timestampToken
  latestBase = self~prefix(dataDir) || "-" || phaseToken
  jsonPath = snap~writeJson(timestampedBase || ".json")
  textPath = snap~writeText(timestampedBase || ".txt")
  latestJsonPath = snap~writeJson(latestBase || ".json")
  latestTextPath = snap~writeText(latestBase || ".txt")
  signal off syntax
  signal off notready
  if jsonPath == .false | textPath == .false then do
    self~logFail(logger, "Inspector Clouseau timestamped snapshot write returned false phase=" || phase || " base=" || timestampedBase)
    return .false
  end
  if latestJsonPath == .false | latestTextPath == .false then do
    self~logFail(logger, "Inspector Clouseau latest snapshot alias write returned false phase=" || phase || " base=" || latestBase)
  end
  self~logInfo(logger, "wrote Inspector Clouseau snapshot " || timestampedBase || ".json/.txt latest=" || latestBase || ".json/.txt")
  return .true

writeFailed:
  __icC = condition("C")
  __icD = condition("D")
  __icRC = ""
  __icSIGL = ""
  if symbol("RC") = "VAR" then __icRC = "" || rc
  if symbol("SIGL") = "VAR" then __icSIGL = "" || sigl
  __icDiag = self~formatCapturedCondition("Inspector Clouseau snapshot failed phase=" || phase, "write-snapshot", __icC, __icD, __icRC, __icSIGL, condition("O"))
  signal off syntax
  signal off notready
  self~logFail(logger, __icDiag)
  return .false

::method traceRequestAlarmSeconds class private
  p = value("ALCHEMY_INSPECTOR_TRACE_REQUEST_ALARM_SECONDS",, "ENVIRONMENT")
  if p = "" then p = value("ALCHEMY_INSPECTOR_TRACE_REQUEST_INTERVAL",, "ENVIRONMENT")
  if p = "" then p = "5"
  if \datatype(p, "W") then return 5
  n = p + 0
  if n < 0 then n = 0
  return n

::method snapshotAlarmSeconds class private
  p = value("ALCHEMY_INSPECTOR_SNAPSHOT_ALARM_SECONDS",, "ENVIRONMENT")
  if p = "" then p = value("ALCHEMY_INSPECTOR_SNAPSHOT_INTERVAL",, "ENVIRONMENT")
  if p = "" then return 0
  if \datatype(p, "W") then return 0
  n = p + 0
  if n < 0 then n = 0
  return n

::method timestampToken class private
  t = time("L")
  t = changestr(":", t, "")
  t = changestr(".", t, "")
  return date("S") || "T" || t

::method traceRequestDir class private
  use strict arg dataDir
  p = value("ALCHEMY_INSPECTOR_TRACE_REQUEST_DIR",, "ENVIRONMENT")
  if p \= "" then return p
  if dataDir = "" then dataDir = "."
  return dataDir || "/inspector-trace-requests"

::method prefix class private
  use strict arg dataDir
  p = value("ALCHEMY_INSPECTOR_PREFIX",, "ENVIRONMENT")
  if p \= "" then return p
  if dataDir = "" then dataDir = "."
  return dataDir || "/alchemy-inspector"

::method safeToken class private
  use strict arg value
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
  if out = "" then out = "PHASE"
  return out

::method rootCount class private
  use strict arg roots
  signal on syntax name countFailed
  if roots == .nil then return 0
  return roots~items
countFailed:
  return 0


::method formatCapturedCondition class private
  prefix = "Inspector Clouseau failure"
  stage = "unknown"
  c = ""
  d = ""
  rcText = ""
  siglText = ""
  co = .nil
  if arg() >= 1 then prefix = arg(1)
  if arg() >= 2 then stage = arg(2)
  if arg() >= 3 then c = arg(3)
  if arg() >= 4 then d = arg(4)
  if arg() >= 5 then rcText = arg(5)
  if arg() >= 6 then siglText = arg(6)
  if arg() >= 7 then co = arg(7)

  msg = prefix || " stage=" || stage || " condition=" || c || " rc=" || rcText || " sigl=" || siglText
  if d \= "" then msg = msg || " description=" || d

  signal on syntax name formatDone
  if co \== .nil then do
    msg = msg || " object=" || co
    if co~hasMethod("CONDITION") then msg = msg || " co_condition=" || co~condition
    if co~hasMethod("DESCRIPTION") then msg = msg || " co_description=" || co~description
    if co~hasMethod("ERRORTEXT") then msg = msg || " errortext=" || co~errortext
    if co~hasMethod("INSTRUCTION") then msg = msg || " instruction=" || co~instruction
    if co~hasMethod("PROGRAM") then msg = msg || " program=" || co~program
    if co~hasMethod("CODE") then msg = msg || " code=" || co~code
  end
formatDone:
  signal off syntax
  return msg


::method conditionSummary class private
  c = condition("C")
  d = condition("D")
  rcText = ""
  siglText = ""
  if symbol("RC") = "VAR" then rcText = rc
  if symbol("SIGL") = "VAR" then siglText = sigl
  msg = "condition=" || c || " rc=" || rcText || " sigl=" || siglText
  if d \= "" then msg = msg || " description=" || d
  signal on syntax name done
  co = condition("O")
  if co \== .nil then do
    msg = msg || " object=" || co
    if co~hasMethod("CONDITION") then msg = msg || " co_condition=" || co~condition
    if co~hasMethod("DESCRIPTION") then msg = msg || " co_description=" || co~description
    if co~hasMethod("ERRORTEXT") then msg = msg || " errortext=" || co~errortext
    if co~hasMethod("INSTRUCTION") then msg = msg || " instruction=" || co~instruction
    if co~hasMethod("PROGRAM") then msg = msg || " program=" || co~program
    if co~hasMethod("CODE") then msg = msg || " code=" || co~code
  end
done:
  return msg

::method writeDiagnostic class private
  dataDir = "."
  message = ""
  if arg() >= 1 then dataDir = arg(1)
  if arg() >= 2 then message = arg(2)
  if dataDir == .nil | dataDir = "" then dataDir = "."
  path = value("ALCHEMY_INSPECTOR_INSTALL_LOG",, "ENVIRONMENT")
  if path = "" then path = dataDir || "/alchemy-inspector-install.log"
  signal on syntax name diagDone
  signal on notready name diagDone
  f = .Stream~new(path)
  f~open("write append")
  f~lineOut(date("S") || "T" || time() || " " || message)
  f~close
diagDone:
  signal off syntax
  signal off notready
  return .true

::method logInfo class private
  use strict arg logger, message
  signal on syntax name noLog
  if logger \== .nil then return logger~emit("INFO", "AlchemyInspectorRules", "install", "inspector", message, "")
noLog:
  return .false

::method logFail class private
  use strict arg logger, message
  signal on syntax name noLog
  if logger \== .nil then return logger~emit("ERROR", "AlchemyInspectorRules", "install", "inspector", message, "")
noLog:
  return .false

::requires "inspector/InspectorClouseau.cls"

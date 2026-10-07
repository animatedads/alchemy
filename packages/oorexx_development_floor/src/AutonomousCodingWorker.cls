/* AutonomousCodingWorker.cls
   First bounded autonomous coding loop for Development Floor.

   Authority boundaries:
   - Development Manager owns assignment/execution binding and acceptance.
   - WLU Authority must admit work before the worker invokes a model or test.
   - AIProviderRequest/Reply is the narrow provider boundary.
   - the model proposes one bounded source body using a tiny validated JSON grammar; it receives no shell,
     filesystem, WLU, provider credential, cloud or deployment authority.
   - deterministic ooRexx compile/run evidence drives one mandatory second bite.
   - accounting records provider token facts separately from WLU consumption.
*/

::class DFAutonomousCodingBuild public
::constant API_VERSION "development.floor.autonomous-coding/0.1"
::constant MAX_INSTRUCTION_BYTES 65536
::constant MAX_SOURCE_BYTES 131072
::constant MAX_EVIDENCE_BYTES 8192

::class DFCodingRunOutcome public
::attribute ok get
::attribute code get
::attribute detail get
::attribute filePath get
::attribute sourceSha256 get
::attribute initialCompileRc get
::attribute initialRunRc get
::attribute finalCompileRc get
::attribute finalRunRc get
::attribute finalStdout get
::attribute secondBiteAction get
::attribute inputTokens get
::attribute outputTokens get
::attribute consumedMicroWlu get
::attribute claimedReasoningSummary get

::method init
  expose ok code detail filePath sourceSha256 initialCompileRc initialRunRc finalCompileRc finalRunRc finalStdout secondBiteAction inputTokens outputTokens consumedMicroWlu claimedReasoningSummary
  use strict arg okArg, codeArg, detailArg="", filePathArg="", sourceShaArg="", initialCompileArg = (-1), initialRunArg = (-1), finalCompileArg = (-1), finalRunArg = (-1), finalStdoutArg="", secondBiteArg="", inputTokensArg=0, outputTokensArg=0, consumedArg=0, claimedReasoningArg=""
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  filePath = filePathArg~string
  sourceSha256 = sourceShaArg~string
  initialCompileRc = initialCompileArg
  initialRunRc = initialRunArg
  finalCompileRc = finalCompileArg
  finalRunRc = finalRunArg
  finalStdout = finalStdoutArg~string
  secondBiteAction = secondBiteArg~string~upper
  inputTokens = inputTokensArg
  outputTokens = outputTokensArg
  consumedMicroWlu = consumedArg
  claimedReasoningSummary = claimedReasoningArg~string

::class DFCodingWorkerUtil
::method shellQuote
  use strict arg valueArg
  text = valueArg~string
  text = text~changestr("'", "'\\''")
  return "'" || text || "'"

::method safeFilename
  use strict arg valueArg
  name = valueArg~string~strip
  if name = "" then return .false
  if name~length > 128 then return .false
  if name~pos("/") > 0 then return .false
  if name~pos("\\") > 0 then return .false
  if name~pos("..") > 0 then return .false
  if name~left(1) = "." then return .false
  return .true

::method readFile
  use strict arg path, maxBytes=0
  s = .Stream~new(path)
  if s~query("exists") = "" then return .Array~of(.false, "NOT_FOUND", "")
  opened = s~open("READ")
  if opened \= "READY:" then return .Array~of(.false, opened, "")
  count = s~chars
  if maxBytes > 0 then do
    if count > maxBytes then do
      ignore = s~close
      return .Array~of(.false, "TOO_LARGE", "")
    end
  end
  if count > 0 then text = s~charIn(1, count)
  else text = ""
  ignore = s~close
  return .Array~of(.true, "", text)

::method writeFile
  use strict arg path, text
  s = .Stream~new(path)
  opened = s~open("WRITE REPLACE")
  if opened \= "READY:" then return .false
  ignore = s~charOut(text)
  ignore = s~close
  return .true

::method ensureDirectory
  use strict arg path
  commandText = "mkdir -p -- " || self~shellQuote(path)
  address system commandText
  return rc = 0

::method runCommand
  use strict arg commandText, outputPath
  full = commandText || " >" || self~shellQuote(outputPath) || " 2>&1"
  address system full
  return rc

::method sha256
  use strict arg path
  outputPath = path || ".sha256.tmp"
  commandText = "sha256sum -- " || self~shellQuote(path)
  commandRc = self~runCommand(commandText, outputPath)
  if commandRc \= 0 then do
    ignore = SysFileDelete(outputPath)
    return ""
  end
  read = self~readFile(outputPath, 1024)
  ignore = SysFileDelete(outputPath)
  if \read[1] then return ""
  return word(read[3], 1)

::method normalizedOutput
  use strict arg text
  normalized = text~changestr("0d0a"x, "0a"x)~changestr("0d"x, "0a"x)
  do while normalized~right(1) = "0a"x
    normalized = normalized~left(normalized~length - 1)
  end
  return normalized


::class DFCodingWorkerDiagnostic
::method redacted class
  use strict arg detail
  if detail == .nil then return ""
  text = detail~string
  if text = "" then return ""
  return "[detail-redacted length=" || text~length || "]"

::class DFAutonomousCodingWorker public
::method init
  expose manager provider util journal
  use strict arg managerArg, providerArg, journalArg=.nil
  if managerArg == .nil then raise syntax 93.900 array("Autonomous coding worker requires Development Manager")
  if providerArg == .nil then raise syntax 93.900 array("Autonomous coding worker requires model provider")
  if \providerArg~hasMethod("COMPLETE") then raise syntax 93.900 array("Model provider must implement complete(request)")
  manager = managerArg
  provider = providerArg
  journal = journalArg
  util = .DFCodingWorkerUtil~new

::method runHelloWorld
  expose manager provider util journal
  use strict arg assignmentId, instructionPath, workspaceRoot, modelId, expectedStdout="HELLO WORLD", maxOutputTokens=20000, initialModelMicroWlu=1000000, testMicroWlu=100000, secondModelMicroWlu=1000000, finalTestMicroWlu=100000

  assignment = manager~assignments~at(assignmentId)
  if assignment == .nil then return .DFCodingRunOutcome~new(.false, "ASSIGNMENT_NOT_FOUND")
  signal on syntax name admissionDenied
  reservation = manager~requireAssignmentWorkAdmission(assignmentId)
  signal off syntax

  instructionRead = util~readFile(instructionPath, .DFAutonomousCodingBuild~MAX_INSTRUCTION_BYTES)
  if \instructionRead[1] then return self~terminalFailure(assignmentId, "INSTRUCTIONS_UNAVAILABLE", instructionRead[2], 0, 0, 0)
  if \util~ensureDirectory(workspaceRoot) then return self~terminalFailure(assignmentId, "WORKSPACE_UNAVAILABLE", workspaceRoot, 0, 0, 0)

  prompt = self~initialPrompt(assignment, instructionRead[3])
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "MODEL_REQUEST_INITIAL", "implement/bite1.prompt.txt", prompt, assignmentId)
  initialReply = provider~complete(.AIProviderRequest~new(modelId, prompt, maxOutputTokens))
  initialReasoning = self~providerReasoningSummary
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "CLAIMED_REASONING_INITIAL", "implement/bite1.reasoning-summary.txt", initialReasoning, assignmentId)
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "MODEL_RESPONSE_INITIAL", "implement/bite1.response.json", initialReply~text, "ok=" || initialReply~ok || " code=" || initialReply~code)
  consumed = initialModelMicroWlu
  ignore = manager~consumeAssignmentWork(assignmentId, initialModelMicroWlu, "coding-model-initial")
  inputTokens = initialReply~usage~inputTokens
  outputTokens = initialReply~usage~outputTokens
  ignore = self~recordTokens(assignmentId, inputTokens, outputTokens, "coding-model-initial")
  if \initialReply~ok then return self~terminalFailure(assignmentId, initialReply~code, initialReply~detail, consumed, inputTokens, outputTokens)

  parsed = self~parseInitialProposal(initialReply~text)
  if \parsed[1] then return self~terminalFailure(assignmentId, "MODEL_PROPOSAL_INVALID", parsed[2], consumed, inputTokens, outputTokens)
  filename = "hello.rex"
  sourceText = parsed[3]
  if sourceText~length > .DFAutonomousCodingBuild~MAX_SOURCE_BYTES then return self~terminalFailure(assignmentId, "MODEL_SOURCE_TOO_LARGE", sourceText~length, consumed, inputTokens, outputTokens)
  filePath = workspaceRoot
  if filePath~right(1) \= "/" then filePath ||= "/"
  filePath ||= filename
  if \util~writeFile(filePath, sourceText) then return self~terminalFailure(assignmentId, "SOURCE_WRITE_FAILED", filePath, consumed, inputTokens, outputTokens)
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "SOURCE_INITIAL", "implement/source.initial.rex", sourceText, assignmentId)

  firstCheck = self~checkOoRexx(filePath, workspaceRoot, expectedStdout, "initial")
  if journal \== .nil then do
    ev = self~evidenceJson(firstCheck, expectedStdout)
    ignore = journal~persist("VERIFY", "EVIDENCE_INITIAL", "verify/initial.evidence.json", ev, assignmentId)
  end
  consumed += testMicroWlu
  ignore = manager~consumeAssignmentWork(assignmentId, testMicroWlu, "coding-test-initial")

  secondPrompt = self~secondBitePrompt(assignment, sourceText, firstCheck, expectedStdout)
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "MODEL_REQUEST_SECOND_BITE", "implement/bite2.prompt.txt", secondPrompt, assignmentId)
  secondReply = provider~complete(.AIProviderRequest~new(modelId, secondPrompt, maxOutputTokens))
  secondReasoning = self~providerReasoningSummary
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "CLAIMED_REASONING_SECOND_BITE", "implement/bite2.reasoning-summary.txt", secondReasoning, assignmentId)
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "MODEL_RESPONSE_SECOND_BITE", "implement/bite2.response.json", secondReply~text, "ok=" || secondReply~ok || " code=" || secondReply~code)
  consumed += secondModelMicroWlu
  ignore = manager~consumeAssignmentWork(assignmentId, secondModelMicroWlu, "coding-model-second-bite")
  inputTokens += secondReply~usage~inputTokens
  outputTokens += secondReply~usage~outputTokens
  ignore = self~recordTokens(assignmentId, secondReply~usage~inputTokens, secondReply~usage~outputTokens, "coding-model-second-bite")
  if \secondReply~ok then return self~terminalFailure(assignmentId, secondReply~code, secondReply~detail, consumed, inputTokens, outputTokens, filePath, firstCheck)

  second = self~parseSecondBite(secondReply~text)
  if \second[1] then return self~terminalFailure(assignmentId, "SECOND_BITE_INVALID", second[2], consumed, inputTokens, outputTokens, filePath, firstCheck)
  action = second[3]
  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "SECOND_BITE_VALIDATED", "implement/bite2.action.txt", action || "0a"x, assignmentId)
  if action = "REPLACE" then do
    replacement = second[4]
    if replacement~length > .DFAutonomousCodingBuild~MAX_SOURCE_BYTES then return self~terminalFailure(assignmentId, "MODEL_SOURCE_TOO_LARGE", replacement~length, consumed, inputTokens, outputTokens, filePath, firstCheck)
    if \util~writeFile(filePath, replacement) then return self~terminalFailure(assignmentId, "SOURCE_WRITE_FAILED", filePath, consumed, inputTokens, outputTokens, filePath, firstCheck)
    sourceText = replacement
  end

  if journal \== .nil then ignore = journal~persist("IMPLEMENT", "SOURCE_FINAL", "implement/source.final.rex", sourceText, "action=" || action)
  finalCheck = self~checkOoRexx(filePath, workspaceRoot, expectedStdout, "final")
  if journal \== .nil then do
    ev = self~evidenceJson(finalCheck, expectedStdout)
    ignore = journal~persist("VERIFY", "EVIDENCE_FINAL", "verify/final.evidence.json", ev, assignmentId)
  end
  consumed += finalTestMicroWlu
  ignore = manager~consumeAssignmentWork(assignmentId, finalTestMicroWlu, "coding-test-final")
  sha = util~sha256(filePath)
  ok = finalCheck[1]
  if ok then code = "OK"
  else code = "DETERMINISTIC_TEST_FAILED"
  ignore = manager~settleAssignmentWork(assignmentId, consumed)
  claimedReasoning = "INITIAL:" || "0a"x || initialReasoning || "0a"x || "SECOND_BITE:" || "0a"x || secondReasoning
  return .DFCodingRunOutcome~new(ok, code, finalCheck[6], filePath, sha, firstCheck[2], firstCheck[3], finalCheck[2], finalCheck[3], finalCheck[5], action, inputTokens, outputTokens, consumed, claimedReasoning)

admissionDenied:
  say "Autonomous worker WLU admission syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  return .DFCodingRunOutcome~new(.false, "WLU_NOT_ADMITTED", "assignment lacks admitted WLU")

::method initialPrompt
  use strict arg assignment, instructions
  text = "Task: " || assignment~objective || "0a"x
  text ||= "Language: " || assignment~language || "0a"x
  text ||= instructions || "0a"x
  text ||= 'Return JSON only, exactly one field: {"source":"<ooRexx source>"}' || "0a"x
  text ||= "No markdown. No filename. No rationale. No extra fields."
  return text

::method secondBitePrompt
  use strict arg assignment, sourceText, check, expectedStdout
  evidence = check[6]
  if evidence~length > 2048 then evidence = evidence~left(2048)
  text = "Repair check for: " || assignment~objective || "0a"x
  text ||= "Expected stdout: " || expectedStdout || "0a"x
  text ||= "Source:" || "0a"x || sourceText || "0a"x
  text ||= "Evidence:" || "0a"x || evidence || "0a"x
  text ||= 'Return JSON only: {"action":"KEEP"} or {"action":"REPLACE","source":"<replacement ooRexx source>"}.' || "0a"x
  text ||= "No markdown. No rationale. No extra fields."
  return text

::method parseInitialProposal
  use strict arg text
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object")
  if data~items \= 1 then return .Array~of(.false, "unexpected-fields")
  source = data~at("source")
  if source == .nil then return .Array~of(.false, "source-missing")
  if \source~isa(.String) then source = source~string
  if source~string~strip = "" then return .Array~of(.false, "source-empty")
  return .Array~of(.true, "", source~string)
invalid:
  say "Autonomous worker model JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  return .Array~of(.false, "invalid-json")

::method parseSecondBite
  use strict arg text
  signal on syntax name invalid
  data = .JSON~fromJSON(text)
  signal off syntax
  if \data~isa(.Directory) then return .Array~of(.false, "not-object")
  actionValue = data~at("action")
  if actionValue == .nil then return .Array~of(.false, "action-missing")
  action = actionValue~string~strip~upper
  if action = "KEEP" then do
    if data~items \= 1 then return .Array~of(.false, "unexpected-fields")
    return .Array~of(.true, "", action, "")
  end
  if action = "REPLACE" then do
    if data~items \= 2 then return .Array~of(.false, "unexpected-fields")
    source = data~at("source")
    if source == .nil then return .Array~of(.false, "replacement-source-missing")
    if source~string~strip = "" then return .Array~of(.false, "replacement-source-empty")
    return .Array~of(.true, "", action, source~string)
  end
  return .Array~of(.false, "action-unsupported")
invalid:
  say "Autonomous worker model JSON syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  return .Array~of(.false, "invalid-json")

::method checkOoRexx
  expose util journal
  use strict arg filePath, workspaceRoot, expectedStdout, label="check"
  if journal == .nil then do
    compileLog = workspaceRoot || "/" || label || ".compile.log"
    runLog = workspaceRoot || "/" || label || ".run.log"
  end
  else do
    compileLog = journal~artifactPath("verify/" || label || ".compile.log")
    runLog = journal~artifactPath("verify/" || label || ".run.log")
  end
  rexxcBin = value("DF_REXXC",, "ENVIRONMENT")
  rexxBin = value("DF_REXX",, "ENVIRONMENT")
  if rexxcBin = "" then rexxcBin = "rexxc"
  if rexxBin = "" then rexxBin = "rexx"
  compileCommand = util~shellQuote(rexxcBin) || " " || util~shellQuote(filePath)
  compileRc = util~runCommand(compileCommand, compileLog)
  compileRead = util~readFile(compileLog, .DFAutonomousCodingBuild~MAX_EVIDENCE_BYTES)
  if compileRead[1] then compileText = compileRead[3]
  else compileText = compileRead[2]
  runRc = -1
  runText = ""
  if compileRc = 0 then do
    runCommand = util~shellQuote(rexxBin) || " " || util~shellQuote(filePath)
    runRc = util~runCommand(runCommand, runLog)
    runRead = util~readFile(runLog, .DFAutonomousCodingBuild~MAX_EVIDENCE_BYTES)
    if runRead[1] then runText = runRead[3]
    else runText = runRead[2]
  end
  normalized = util~normalizedOutput(runText)
  ok = compileRc = 0
  if ok then ok = runRc = 0
  if ok then ok = normalized = expectedStdout
  evidence = "compile_rc=" || compileRc || " run_rc=" || runRc || "0a"x || "stdout=" || normalized || "0a"x || "compile_log=" || compileText
  return .Array~of(ok, compileRc, runRc, compileText, normalized, evidence)

::method evidenceJson
  use strict arg check, expectedStdout
  text = '{"schema":"development.floor.deterministic-evidence/0.1"'
  text ||= ',"compile_rc":' || check[2]
  text ||= ',"run_rc":' || check[3]
  text ||= ',"stdout":"' || self~jsonEscape(check[5]) || '"'
  text ||= ',"expected_stdout":"' || self~jsonEscape(expectedStdout) || '"'
  if check[1] then match = "true"
  else match = "false"
  text ||= ',"pass":' || match || '}' || "0a"x
  return text

::method jsonEscape
  use strict arg valueArg
  value = valueArg~string
  value = value~changestr('\\', '\\\\')
  value = value~changestr('"', '\\"')
  value = value~changestr("0d"x, '\\r')
  value = value~changestr("0a"x, '\\n')
  value = value~changestr("09"x, '\\t')
  return value

::method providerReasoningSummary
  expose provider
  if provider~hasMethod("LASTREASONINGSUMMARY") then return provider~lastReasoningSummary
  return ""

::method recordTokens
  expose manager
  use strict arg assignmentId, inputTokens, outputTokens, externalRef
  if inputTokens > 0 then ignore = manager~recordAssignmentResourceUse(assignmentId, "LLM_INPUT", inputTokens, "INPUT_TOKEN", externalRef, "provider reported input tokens")
  if outputTokens > 0 then ignore = manager~recordAssignmentResourceUse(assignmentId, "LLM_OUTPUT", outputTokens, "OUTPUT_TOKEN", externalRef, "provider reported output tokens")
  return .true

::method terminalFailure
  expose manager util
  use arg assignmentId, code, detail="", consumed=0, inputTokens=0, outputTokens=0, filePath="", firstCheck=.nil
  if consumed > 0 then do
    signal on syntax name settlementIgnored
    ignore = manager~settleAssignmentWork(assignmentId, consumed)
    signal off syntax
  end
  initialCompile = -1
  initialRun = -1
  if firstCheck \== .nil then do
    initialCompile = firstCheck[2]
    initialRun = firstCheck[3]
  end
  sha = ""
  if filePath <> "" then sha = util~sha256(filePath)
  return .DFCodingRunOutcome~new(.false, code, detail, filePath, sha, initialCompile, initialRun, initialCompile, initialRun, "", "", inputTokens, outputTokens, consumed)
settlementIgnored:
  say "Autonomous worker settlement syntax failure rc=" rc "sigl=" sigl "conditionC=" condition("C") "conditionD=" .DFCodingWorkerDiagnostic~redacted(condition("D"))
  signal off syntax
  return .DFCodingRunOutcome~new(.false, code, detail, filePath, "", -1, -1, -1, -1, "", "", inputTokens, outputTokens, consumed)

::requires "DevelopmentFloor.cls"
::requires "AIProviderAccess.cls"
::requires "json.cls"

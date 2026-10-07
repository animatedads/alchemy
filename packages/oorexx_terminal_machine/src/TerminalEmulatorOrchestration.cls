/*
 * TerminalEmulatorOrchestration.cls - checkpoint-bound emulator event runner.
 *
 * v0.21 turns the v0.20 exact-token execution boundary into an orchestration
 * primitive for real emulator instruction and device-event loops.  The
 * orchestrator owns the exact TerminalEmulatorExecutionTicket internally:
 * emulator handlers never receive it and therefore cannot accidentally commit
 * or roll back somebody else's attempt.
 *
 * Instruction discipline:
 *   checkpoint -> FETCH -> DECODE -> EXECUTE -> COMMIT
 *                   \          \          \
 *                    +----------+----------+-> failure/SYNTAX -> ROLLBACK
 *
 * A failed attempt stays in the Journal Pointed State graph.  After code or
 * data repair, retryInstruction() creates a new attempt linked to the failed
 * event by immutable, value-free history evidence.
 *
 * This is local EMULATOR/TESTBED/REPLAY_SANDBOX machinery only.  It adds no
 * authority over TN5250LiveSession, TerminalSessionOwner, broker/service
 * objects, credentials, WLU reservations or remote host state.
 */

::class TerminalEmulatorOrchestrationBuild public
::constant RELEASE "0.21"
::constant API_VERSION "terminal.emulator.orchestration/0.1"
::constant JOURNAL_API "terminal.emulator.journal/0.2"


/* Immutable value evidence supplied to an emulator handler.  It deliberately
 * contains no checkpoint object, execution ticket, state machine, boundary or
 * handler authority reference. */
::class TerminalEmulatorEvent public
::attribute eventId get
::attribute kind get
::attribute name get
::attribute attemptNumber get
::attribute retryOfEventId get

::method init
  expose eventId kind name attemptNumber retryOfEventId
  use strict arg eventIdArg, kindArg, nameArg, attemptNumberArg, retryOfEventIdArg = ""
  eventId = eventIdArg~string
  kind = kindArg~string~strip~upper
  name = nameArg~string
  attemptNumber = attemptNumberArg
  retryOfEventId = retryOfEventIdArg~string


/* Detached debugger evidence for one completed orchestration attempt.  Phase
 * traces contain only phase/status/code strings, never fetch/decode/execute
 * values. */
::class TerminalEmulatorEventHistoryEntry public
::attribute eventId get
::attribute kind get
::attribute name get
::attribute attemptNumber get
::attribute retryOfEventId get
::attribute checkpointId get
::attribute outcome get
::attribute terminalPhase get
::attribute code get
::attribute detail get
::attribute progressMarker get

::method init
  expose eventId kind name attemptNumber retryOfEventId checkpointId outcome terminalPhase code detail progressMarker phaseTrace
  use strict arg eventIdArg, kindArg, nameArg, attemptNumberArg, retryOfEventIdArg, checkpointIdArg, outcomeArg, terminalPhaseArg, codeArg, detailArg, progressMarkerArg, phaseTraceArg
  eventId = eventIdArg~string
  kind = kindArg~string~strip~upper
  name = nameArg~string
  attemptNumber = attemptNumberArg
  retryOfEventId = retryOfEventIdArg~string
  checkpointId = checkpointIdArg~string
  outcome = outcomeArg~string~strip~upper
  terminalPhase = terminalPhaseArg~string~strip~upper
  code = codeArg~string
  detail = detailArg~string
  progressMarker = progressMarkerArg~string
  phaseTrace = .TerminalUtil~copyArray(phaseTraceArg)

::method phases
  expose phaseTrace
  return .TerminalUtil~copyArray(phaseTrace)


/* Explicit marker for the three fixed instruction phases.  A pipeline object
 * must inherit this mixin and implement emulatorFetch, emulatorDecode and
 * emulatorExecute.  The orchestrator does not accept arbitrary method names. */
::class TerminalEmulatorInstructionPipeline mixinclass Object public
::method terminalEmulatorInstructionPipeline
  return .true


/* Explicit marker for a non-instruction event handler.  Device/timer/DMA/etc.
 * events use one fixed emulatorHandleEvent entry point. */
::class TerminalEmulatorEventHandler mixinclass Object public
::method terminalEmulatorEventHandler
  return .true


::class TerminalEmulatorEventOrchestrator subclass TerminalAlchemyObject public
::attribute historyLimit get
::attribute dispatchCount get
::attribute committedCount get
::attribute rolledBackCount get
::attribute faultCount get
::attribute retryCount get
::attribute lastEventId get
::attribute lastOutcome get
::attribute lastFaultCode get

::method init
  expose machine boundary history historyById historyLimit nextEventSequence dispatchCount committedCount rolledBackCount faultCount retryCount lastEventId lastOutcome lastFaultCode
  use strict arg machineArg, historyLimitArg = 256, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if machineArg == .nil then raise syntax 88.900 array("TerminalEmulatorEventOrchestrator requires TerminalEmulatorStateMachine")
  if \machineArg~isA(.TerminalEmulatorStateMachine) then raise syntax 88.900 array("TerminalEmulatorEventOrchestrator requires TerminalEmulatorStateMachine")
  if \datatype(historyLimitArg, "W") | historyLimitArg < 1 | historyLimitArg > 10000 then raise syntax 88.900 array("Terminal emulator orchestration history limit must be 1..10000")

  machine = machineArg
  boundary = .TerminalEmulatorExecutionBoundary~new(machineArg, alchemySealerArg, alchemyCapabilityAuthorityArg)
  history = .array~new
  historyById = .table~new
  historyLimit = historyLimitArg
  nextEventSequence = 1
  dispatchCount = 0
  committedCount = 0
  rolledBackCount = 0
  faultCount = 0
  retryCount = 0
  lastEventId = ""
  lastOutcome = ""
  lastFaultCode = ""

  meta = .directory~new
  meta["emulator_orchestration_api"] = .TerminalEmulatorOrchestrationBuild~API_VERSION
  meta["emulator_journal_api"] = .TerminalEmulatorOrchestrationBuild~JOURNAL_API
  meta["ticket_boundary"] = "EXACT_TICKET_RETAINED_INSIDE_ORCHESTRATOR"
  meta["semantic_boundary"] = "LOCAL_EMULATOR_EVENTS_ONLY_NOT_REMOTE_HOST_EXECUTION"
  self~initTerminalAlchemy("Checkpoint-bound instruction/event orchestration for local emulators", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("historyLimit", "CUSTOMER", "bounded retained event-history evidence count")
  self~registerStateVariable("dispatchCount", "CUSTOMER", "orchestration attempts begun")
  self~registerStateVariable("committedCount", "CUSTOMER", "attempts committed")
  self~registerStateVariable("rolledBackCount", "CUSTOMER", "attempts successfully rolled back")
  self~registerStateVariable("faultCount", "CUSTOMER", "handler/result faults observed")
  self~registerStateVariable("retryCount", "CUSTOMER", "explicit retries linked to prior failed attempts")
  self~registerStateVariable("lastEventId", "CUSTOMER", "last orchestration event identity")
  self~registerStateVariable("lastOutcome", "CUSTOMER", "last orchestration outcome")
  self~registerStateVariable("lastFaultCode", "CUSTOMER", "last bounded fault code")
  /* machine/boundary/history/historyById and exact execution tickets are capability/context objects and are never registered. */
  self~registerMethodContract("RUNINSTRUCTION", "checkpoint then run fixed FETCH/DECODE/EXECUTE phases and exact-token commit/rollback", .array~of("NAME", "PIPELINE", "CONTEXT", "PROGRESS_MARKER", "RETRY_OF_EVENT_ID"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RETRYINSTRUCTION", "retry one previously rolled-back instruction and link debugger history", .array~of("PREVIOUS_EVENT_ID", "PIPELINE", "CONTEXT", "PROGRESS_MARKER"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RUNEVENT", "checkpoint then run one explicitly marked non-instruction emulator event handler", .array~of("KIND", "NAME", "HANDLER", "CONTEXT", "PROGRESS_MARKER", "RETRY_OF_EVENT_ID"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("RETRYEVENT", "retry one previously rolled-back non-instruction event and link debugger history", .array~of("PREVIOUS_EVENT_ID", "HANDLER", "CONTEXT", "PROGRESS_MARKER"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("HISTORY", "return a detached bounded array of immutable value-free event history", .array~of("LIMIT"), "ARRAY", .false, "FALSE", "INTERNAL", "NORMAL", "READ", "USE")
  self~registerMethodContract("EVENTBYID", "return immutable event-history evidence by opaque event id", .array~of("EVENT_ID"), "TERMINALEMULATOREVENTHISTORYENTRY", .false, "FALSE", "INTERNAL", "NORMAL", "READ", "USE")

::method runInstruction
  expose machine boundary dispatchCount retryCount
  use strict arg nameArg, pipelineArg, contextArg = .nil, progressMarkerArg = "", retryOfEventIdArg = ""
  name = nameArg~string
  if name~strip == "" then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT", "instruction name is empty")
  validHandler = self~validateInstructionPipeline(pipelineArg)
  if \validHandler~ok then return validHandler
  retryOf = retryOfEventIdArg~string
  if retryOf \== "" then do
    validRetry = self~validateRetry(retryOf, "INSTRUCTION")
    if \validRetry~ok then return validRetry
    retryCount += 1
  end

  event = self~newEvent("INSTRUCTION", name, retryOf)
  dispatchCount += 1
  checkpointMeta = self~checkpointMetadata(event)
  begun = boundary~begin("INSTRUCTION:" || name, "before " || event~eventId || " " || name, checkpointMeta)
  if \begun~ok then return begun
  ticket = begun~value
  checkpointId = ticket~checkpointId
  phases = .array~new
  currentPhase = "FETCH"
  signal on syntax name instructionSyntaxFailure

  fetched = self~normaliseResult(pipelineArg~emulatorFetch(event, contextArg))
  if \fetched~ok then do
    phases~append("FETCH:FAIL:" || fetched~code)
    signal off syntax
    return self~failAttempt(event, ticket, checkpointId, "FETCH", fetched, progressMarkerArg, phases)
  end
  phases~append("FETCH:OK")

  currentPhase = "DECODE"
  decoded = self~normaliseResult(pipelineArg~emulatorDecode(event, fetched~value, contextArg))
  if \decoded~ok then do
    phases~append("DECODE:FAIL:" || decoded~code)
    signal off syntax
    return self~failAttempt(event, ticket, checkpointId, "DECODE", decoded, progressMarkerArg, phases)
  end
  phases~append("DECODE:OK")

  currentPhase = "EXECUTE"
  executed = self~normaliseResult(pipelineArg~emulatorExecute(event, decoded~value, contextArg))
  if \executed~ok then do
    phases~append("EXECUTE:FAIL:" || executed~code)
    signal off syntax
    return self~failAttempt(event, ticket, checkpointId, "EXECUTE", executed, progressMarkerArg, phases)
  end
  phases~append("EXECUTE:OK")

  signal off syntax
  committed = self~commitAttempt(event, ticket, checkpointId, progressMarkerArg, phases)
  if \committed~ok then return committed
  return .TerminalResult~success(executed~value)

instructionSyntaxFailure:
  signal off syntax
  detail = self~boundedDetail(condition("D"))
  phases~append(currentPhase || ":SYNTAX")
  failure = .TerminalResult~failure("TERMINAL_EMULATOR_HANDLER_SYNTAX", detail)
  return self~failAttempt(event, ticket, checkpointId, currentPhase, failure, progressMarkerArg, phases)

::method retryInstruction
  use strict arg previousEventIdArg, pipelineArg, contextArg = .nil, progressMarkerArg = ""
  previousId = previousEventIdArg~string
  valid = self~validateRetry(previousId, "INSTRUCTION")
  if \valid~ok then return valid
  previous = valid~value
  return self~runInstruction(previous~name, pipelineArg, contextArg, progressMarkerArg, previousId)

::method runEvent
  expose boundary dispatchCount retryCount
  use strict arg kindArg, nameArg, handlerArg, contextArg = .nil, progressMarkerArg = "", retryOfEventIdArg = ""
  kind = kindArg~string~strip~upper
  name = nameArg~string
  if kind == "" then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT_KIND", "event kind is empty")
  if kind == "INSTRUCTION" then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT_KIND", "instruction events require runInstruction")
  if name~strip == "" then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT", "event name is empty")
  validHandler = self~validateEventHandler(handlerArg)
  if \validHandler~ok then return validHandler
  retryOf = retryOfEventIdArg~string
  if retryOf \== "" then do
    validRetry = self~validateRetry(retryOf, kind)
    if \validRetry~ok then return validRetry
    retryCount += 1
  end

  event = self~newEvent(kind, name, retryOf)
  dispatchCount += 1
  checkpointMeta = self~checkpointMetadata(event)
  begun = boundary~begin(kind || ":" || name, "before " || event~eventId || " " || name, checkpointMeta)
  if \begun~ok then return begun
  ticket = begun~value
  checkpointId = ticket~checkpointId
  phases = .array~new
  currentPhase = "HANDLE"
  signal on syntax name eventSyntaxFailure

  handled = self~normaliseResult(handlerArg~emulatorHandleEvent(event, contextArg))
  if \handled~ok then do
    phases~append("HANDLE:FAIL:" || handled~code)
    signal off syntax
    return self~failAttempt(event, ticket, checkpointId, "HANDLE", handled, progressMarkerArg, phases)
  end
  phases~append("HANDLE:OK")

  signal off syntax
  committed = self~commitAttempt(event, ticket, checkpointId, progressMarkerArg, phases)
  if \committed~ok then return committed
  return .TerminalResult~success(handled~value)

eventSyntaxFailure:
  signal off syntax
  detail = self~boundedDetail(condition("D"))
  phases~append(currentPhase || ":SYNTAX")
  failure = .TerminalResult~failure("TERMINAL_EMULATOR_HANDLER_SYNTAX", detail)
  return self~failAttempt(event, ticket, checkpointId, currentPhase, failure, progressMarkerArg, phases)

::method retryEvent
  use strict arg previousEventIdArg, handlerArg, contextArg = .nil, progressMarkerArg = ""
  previousId = previousEventIdArg~string
  valid = self~validateRetry(previousId, "")
  if \valid~ok then return valid
  previous = valid~value
  if previous~kind == "INSTRUCTION" then return .TerminalResult~failure("TERMINAL_EMULATOR_RETRY_KIND", "instruction requires retryInstruction")
  return self~runEvent(previous~kind, previous~name, handlerArg, contextArg, progressMarkerArg, previousId)

::method history
  expose history
  use strict arg limitArg = 0
  if \datatype(limitArg, "W") | limitArg < 0 then return .array~new
  out = .array~new
  start = 1
  if limitArg > 0 & history~items > limitArg then start = history~items - limitArg + 1
  do i = start to history~items
    out~append(history[i])
  end
  return out

::method eventById
  expose historyById
  use strict arg eventIdArg
  return historyById~at(eventIdArg~string)

::method newEvent private
  expose nextEventSequence
  use strict arg kindArg, nameArg, retryOfArg
  seq = nextEventSequence
  nextEventSequence += 1
  id = "EVT-" || right(seq, 10, "0")
  return .TerminalEmulatorEvent~new(id, kindArg, nameArg, seq, retryOfArg)

::method checkpointMetadata private
  use strict arg eventArg
  meta = .directory~new
  meta["event_id"] = eventArg~eventId
  meta["event_kind"] = eventArg~kind
  meta["event_name"] = eventArg~name
  meta["attempt"] = eventArg~attemptNumber~string
  if eventArg~retryOfEventId \== "" then meta["retry_of"] = eventArg~retryOfEventId
  return meta

::method normaliseResult private
  use strict arg valueArg
  if valueArg == .nil then return .TerminalResult~success(.nil)
  if valueArg~isA(.TerminalResult) then return valueArg
  return .TerminalResult~success(valueArg)

::method validateInstructionPipeline private
  use strict arg pipelineArg
  if pipelineArg == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "pipeline required")
  if \pipelineArg~isA(.TerminalEmulatorInstructionPipeline) then return .TerminalResult~failure("TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "pipeline must inherit TerminalEmulatorInstructionPipeline")
  if \pipelineArg~hasMethod("EMULATORFETCH") then return .TerminalResult~failure("TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "emulatorFetch required")
  if \pipelineArg~hasMethod("EMULATORDECODE") then return .TerminalResult~failure("TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "emulatorDecode required")
  if \pipelineArg~hasMethod("EMULATOREXECUTE") then return .TerminalResult~failure("TERMINAL_EMULATOR_INSTRUCTION_PIPELINE", "emulatorExecute required")
  return .TerminalResult~success(pipelineArg)

::method validateEventHandler private
  use strict arg handlerArg
  if handlerArg == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT_HANDLER", "handler required")
  if \handlerArg~isA(.TerminalEmulatorEventHandler) then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT_HANDLER", "handler must inherit TerminalEmulatorEventHandler")
  if \handlerArg~hasMethod("EMULATORHANDLEEVENT") then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT_HANDLER", "emulatorHandleEvent required")
  return .TerminalResult~success(handlerArg)

::method validateRetry private
  expose historyById
  use strict arg previousEventIdArg, expectedKindArg = ""
  previous = historyById~at(previousEventIdArg~string)
  if previous == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_RETRY_NOT_FOUND", previousEventIdArg)
  if previous~outcome \== "ROLLED_BACK" then return .TerminalResult~failure("TERMINAL_EMULATOR_RETRY_OUTCOME", previous~outcome)
  expected = expectedKindArg~string~strip~upper
  if expected \== "" & previous~kind \== expected then return .TerminalResult~failure("TERMINAL_EMULATOR_RETRY_KIND", previous~kind)
  return .TerminalResult~success(previous)

::method commitAttempt private
  expose boundary committedCount lastEventId lastOutcome lastFaultCode
  use strict arg eventArg, ticketArg, checkpointIdArg, progressMarkerArg, phasesArg
  marker = progressMarkerArg~string
  if marker == "" then marker = eventArg~eventId
  committed = boundary~commit(ticketArg, marker)
  if \committed~ok then do
    phasesArg~append("COMMIT:FAIL:" || committed~code)
    if boundary~active then do
      rolled = boundary~rollback(ticketArg, "COMMIT_FAILURE")
      if rolled~ok then phasesArg~append("ROLLBACK:OK")
      else phasesArg~append("ROLLBACK:FAIL:" || rolled~code)
    end
    self~recordAttempt(eventArg, checkpointIdArg, "COMMIT_FAILED", "COMMIT", committed~code, committed~detail, marker, phasesArg)
    lastEventId = eventArg~eventId
    lastOutcome = "COMMIT_FAILED"
    lastFaultCode = committed~code
    return committed
  end
  phasesArg~append("COMMIT:OK")
  committedCount += 1
  lastEventId = eventArg~eventId
  lastOutcome = "COMMITTED"
  lastFaultCode = ""
  self~recordAttempt(eventArg, checkpointIdArg, "COMMITTED", "COMMIT", "OK", "", marker, phasesArg)
  self~alchemyTouch("EMULATOR_EVENT_COMMIT")
  return .TerminalResult~success(eventArg)

::method failAttempt private
  expose boundary rolledBackCount faultCount lastEventId lastOutcome lastFaultCode
  use strict arg eventArg, ticketArg, checkpointIdArg, phaseArg, failureArg, progressMarkerArg, phasesArg
  faultCount += 1
  rolled = boundary~rollback(ticketArg, failureArg~code)
  marker = progressMarkerArg~string
  if rolled~ok then do
    phasesArg~append("ROLLBACK:OK")
    rolledBackCount += 1
    outcome = "ROLLED_BACK"
    returnFailure = failureArg
  end
  else do
    phasesArg~append("ROLLBACK:FAIL:" || rolled~code)
    outcome = "ROLLBACK_FAILED"
    returnFailure = .TerminalResult~failure("TERMINAL_EMULATOR_ORCHESTRATION_ROLLBACK_FAILED", failureArg~code || ":" || rolled~code || ":" || rolled~detail)
  end
  lastEventId = eventArg~eventId
  lastOutcome = outcome
  lastFaultCode = failureArg~code
  self~recordAttempt(eventArg, checkpointIdArg, outcome, phaseArg, failureArg~code, failureArg~detail, marker, phasesArg)
  self~alchemyTouch("EMULATOR_EVENT_FAULT")
  return returnFailure

::method recordAttempt private
  expose history historyById historyLimit
  use strict arg eventArg, checkpointIdArg, outcomeArg, phaseArg, codeArg, detailArg, progressMarkerArg, phasesArg
  entry = .TerminalEmulatorEventHistoryEntry~new(eventArg~eventId, eventArg~kind, eventArg~name, eventArg~attemptNumber, eventArg~retryOfEventId, checkpointIdArg, outcomeArg, phaseArg, codeArg, self~boundedDetail(detailArg), progressMarkerArg, phasesArg)
  history~append(entry)
  historyById[eventArg~eventId] = entry
  do while history~items > historyLimit
    oldest = history[1]
    history~remove(1)
    historyById~remove(oldest~eventId)
  end
  return entry

::method boundedDetail private
  use strict arg detailArg
  text = detailArg~string
  if text~length > 512 then text = text~left(512)
  return text

::requires "TerminalEmulatorJournal.cls"

/*
 * TerminalEmulatorJournal.cls - journal-pointed emulator state integration.
 *
 * This is an emulator/testbed boundary, not a live-host rollback mechanism.
 * It adapts ooRexx Journal Pointed State v0.1 into Terminal Machine without
 * vendoring that package or allowing its live-method repair facility to become
 * arbitrary terminal/session mutation authority.
 *
 * Core rule:
 *   machine state may move backward on its retained journal branch;
 *   installed emulator code deliberately moves forward.
 *
 * A TerminalEmulatorStateMachine coordinates multiple journalled components at
 * one pointer-only State-of-the-Nation checkpoint.  Failed speculative futures
 * remain retained by JournalPointedState and can be reconstructed after a
 * repaired retry forks from the same pre-event checkpoint.
 *
 * IMPORTANT SECURITY / SEMANTIC BOUNDARY
 * --------------------------------------
 * This facility is for EMULATOR, TESTBED and REPLAY_SANDBOX state only.  It is
 * not authority to rewind a real host, a TN5250LiveSession, a broker, transport
 * or TerminalSessionOwner.  Live patching requires the explicit
 * TerminalEmulatorPatchable marker; merely exposing setMethod() or an
 * installLiveMethod()-shaped method is insufficient.
 */

::class TerminalEmulatorJournalBuild public
::constant RELEASE "0.20"
::constant API_VERSION "terminal.emulator.journal/0.2"
::constant JOURNAL_API "oorexx_journal_pointed_state/0.1"


/* One named emulator component backed by JournalPointedState.  The underlying
 * journal object and State-of-the-Nation controller are capabilities and are
 * deliberately absent from Alchemy registered state. */
::class TerminalJournalComponent subclass TerminalAlchemyObject public
::attribute componentId get
::attribute journalId get

::method init
  expose componentId journalId journalState
  use strict arg componentIdArg, initialArg = .nil, requestedJournalIdArg = "", alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  componentId = componentIdArg~string~strip
  if componentId == "" then raise syntax 88.900 array("Terminal journal component id must not be empty")
  if initialArg == .nil then initialArg = .directory~new
  if \initialArg~isA(.Directory) then raise syntax 88.900 array("Terminal journal component initial state must be a Directory")
  requestedId = requestedJournalIdArg~string
  if requestedId == "" then requestedId = "TERMINAL-" || componentId
  journalState = .JournalPointedState~new(initialArg, requestedId)
  journalId = journalState~journalId

  meta = .directory~new
  meta["emulator_journal_api"] = .TerminalEmulatorJournalBuild~API_VERSION
  meta["journal_api"] = .TerminalEmulatorJournalBuild~JOURNAL_API
  meta["component_id"] = componentId
  self~initTerminalAlchemy("Journal-pointed state component for an emulator/testbed", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("componentId", "CUSTOMER", "named emulator State-of-the-Nation component")
  self~registerStateVariable("journalId", "CUSTOMER", "opaque journal identity")
  self~registerMethodContract("PUT", "replace one immutable/copy-on-write state value and append a journal node", .array~of("KEY", "VALUE", "TAG", "METADATA"), "JOURNALPOINT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("BEGINEDIT", "begin one batched atomic journal edit", .array~of("TAG", "METADATA"), "JOURNALEDIT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("RECONSTRUCT", "materialise detached component state at a retained journal point without moving the live head", .array~of("POINT"), "DIRECTORY", .false, "FALSE", "INTERNAL", "NORMAL", "READ", "USE")

::method at
  expose journalState
  use strict arg key
  return journalState~at(key)

::method hasIndex
  expose journalState
  use strict arg key
  return journalState~hasIndex(key)

::method allIndexes
  expose journalState
  return journalState~allIndexes

::method items
  expose journalState
  return journalState~items

::method snapshot
  expose journalState
  return journalState~snapshot

::method beginEdit
  expose journalState
  use strict arg tagArg = "", metadataArg = .nil
  return journalState~beginEdit(tagArg, metadataArg)

::method put
  expose journalState
  use strict arg key, value, tagArg = "", metadataArg = .nil
  p = journalState~put(key, value, tagArg, metadataArg)
  self~alchemyTouch("EMULATOR_STATE_PUT")
  return p

::method remove
  expose journalState
  use strict arg key, tagArg = "", metadataArg = .nil
  p = journalState~remove(key, tagArg, metadataArg)
  self~alchemyTouch("EMULATOR_STATE_REMOVE")
  return p

::method clear
  expose journalState
  use strict arg tagArg = "CLEAR", metadataArg = .nil
  p = journalState~clear(tagArg, metadataArg)
  self~alchemyTouch("EMULATOR_STATE_CLEAR")
  return p

::method journalPoint
  expose journalState
  return journalState~journalPoint

::method currentPoint
  forward message("JOURNALPOINT")

::method headNodeId
  expose journalState
  return journalState~headNodeId

::method retainedNodeCount
  expose journalState
  return journalState~retainedNodeCount

::method reconstruct
  expose journalState
  use strict arg pointArg
  return journalState~reconstruct(pointArg)

::method diff
  expose journalState
  use strict arg fromPointArg, toPointArg
  return journalState~diff(fromPointArg, toPointArg)

/* StateOfNationController participant contract. */
::method journalCanMoveTo
  expose journalState
  use strict arg pointArg
  return journalState~journalCanMoveTo(pointArg)

::method journalMoveTo
  expose journalState
  use strict arg pointArg, notifyArg = .true
  p = journalState~journalMoveTo(pointArg, notifyArg)
  self~alchemyTouch("EMULATOR_STATE_MOVE")
  return p

::method journalAttachController
  expose journalState
  use strict arg controllerArg, componentIdArg
  journalState~journalAttachController(controllerArg, componentIdArg)
  return self

::method journalDetachController
  expose journalState
  journalState~journalDetachController
  return self


/* Coordinates pointer-only checkpoints across multiple journal participants. */
::class TerminalEmulatorStateMachine subclass TerminalAlchemyObject public
::attribute mode get
::attribute checkpointCount get
::attribute restoreCount get
::attribute lastCheckpointId get

::method init
  expose mode controller components checkpointHistory checkpointCount restoreCount lastCheckpointId progressGeneration
  use strict arg modeArg = "EMULATOR", alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  mode = modeArg~string~strip~upper
  if mode == "REPLAY" then mode = "REPLAY_SANDBOX"
  if mode \== "EMULATOR" & mode \== "TESTBED" & mode \== "REPLAY_SANDBOX" then
    raise syntax 88.900 array("Terminal emulator journal refuses live-host mode", mode)

  controller = .StateOfNationController~new
  components = .table~new
  checkpointHistory = .array~new
  checkpointCount = 0
  restoreCount = 0
  lastCheckpointId = ""
  progressGeneration = 0

  meta = .directory~new
  meta["emulator_journal_api"] = .TerminalEmulatorJournalBuild~API_VERSION
  meta["journal_api"] = .TerminalEmulatorJournalBuild~JOURNAL_API
  meta["mode"] = mode
  meta["semantic_boundary"] = "LOCAL_EMULATOR_STATE_ONLY_NOT_REMOTE_HOST_ROLLBACK"
  self~initTerminalAlchemy("State-of-the-Nation controller for journalled emulator/testbed components", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("mode", "CUSTOMER", "emulator-only execution mode")
  self~registerStateVariable("checkpointCount", "CUSTOMER", "pointer-only checkpoints created")
  self~registerStateVariable("restoreCount", "CUSTOMER", "successful state restores")
  self~registerStateVariable("lastCheckpointId", "CUSTOMER", "latest opaque State-of-the-Nation checkpoint id")
  /* controller/components/checkpointHistory are capability-bearing live objects and are not registered. */
  self~registerMethodContract("CREATECOMPONENT", "create and register a journalled emulator state component", .array~of("COMPONENT_ID", "INITIAL", "JOURNAL_ID"), "TERMINALJOURNALCOMPONENT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("CHECKPOINT", "capture pointer-only State-of-the-Nation positions before an emulator event", .array~of("LABEL", "EVENT", "METADATA"), "STATEOFNATIONCHECKPOINT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("RESTORE", "restore all registered emulator components to one retained checkpoint", .array~of("CHECKPOINT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")
  self~registerMethodContract("STATEOFNATION", "return detached component journal pointers without machine-state values", .array~new, "DIRECTORY", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("CHECKPOINTBYID", "resolve one retained local emulator checkpoint by opaque id", .array~of("CHECKPOINT_ID"), "STATEOFNATIONCHECKPOINT", .false, "FALSE", "INTERNAL", "NORMAL", "READ", "USE")
  self~registerMethodContract("MATERIALISECHECKPOINT", "materialise component state at one retained checkpoint without moving the live heads", .array~of("CHECKPOINT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "READ", "USE")
  self~registerMethodContract("TIMELINE", "create a read-only branch-inspection facade over retained emulator checkpoints", .array~of("ALCHEMY_SEALER", "ALCHEMY_CAPABILITY_AUTHORITY"), "TERMINALEMULATORTIMELINE", .false, "FALSE", "INTERNAL", "NORMAL", "READ", "USE")

::method createComponent
  expose components controller
  use strict arg componentIdArg, initialArg = .nil, journalIdArg = "", alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  id = componentIdArg~string~strip
  if id == "" then return .TerminalResult~failure("TERMINAL_JOURNAL_COMPONENT_ID", "component id is empty")
  if components~at(id) \== .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_COMPONENT_EXISTS", id)
  component = .TerminalJournalComponent~new(id, initialArg, journalIdArg, alchemySealerArg, alchemyCapabilityAuthorityArg)
  controller~register(id, component)
  components~put(component, id)
  self~alchemyTouch("EMULATOR_COMPONENT_REGISTER")
  return .TerminalResult~success(component)

::method registerComponent
  expose components controller
  use strict arg componentArg
  if componentArg == .nil | \componentArg~isA(.TerminalJournalComponent) then return .TerminalResult~failure("TERMINAL_JOURNAL_COMPONENT_TYPE", "TerminalJournalComponent required")
  id = componentArg~componentId
  if components~at(id) \== .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_COMPONENT_EXISTS", id)
  controller~register(id, componentArg)
  components~put(componentArg, id)
  self~alchemyTouch("EMULATOR_COMPONENT_REGISTER")
  return .TerminalResult~success(componentArg)

::method stateComponent
  expose components
  use strict arg componentIdArg
  return components~at(componentIdArg~string)

::method componentIds
  expose components
  out = .array~new
  do id over components
    out~append(id)
  end
  return out

::method stateOfNation
  expose components
  positions = .directory~new
  do id over components
    positions[id] = components[id]~journalPoint
  end
  return positions

::method checkpoint
  expose controller checkpointHistory checkpointCount lastCheckpointId
  use strict arg labelArg = "", eventArg = "EMULATOR_EVENT", metadataArg = .nil
  cp = controller~checkpoint(labelArg, eventArg, metadataArg)
  checkpointHistory~append(cp)
  checkpointCount += 1
  lastCheckpointId = cp~checkpointId
  self~alchemyTouch("EMULATOR_CHECKPOINT")
  ignore = self~terminalObservationEvent(checkpointCount, "EMULATOR_CHECKPOINT:" || lastCheckpointId)
  return cp

::method latestCheckpoint
  expose checkpointHistory
  if checkpointHistory~items == 0 then return .nil
  return checkpointHistory[checkpointHistory~items]

/* 0 = latest, 1 = one checkpoint earlier, etc. */
::method checkpointBack
  expose checkpointHistory
  use strict arg countArg = 0
  if \datatype(countArg, "W") | countArg < 0 then return .nil
  index = checkpointHistory~items - countArg
  if index < 1 | index > checkpointHistory~items then return .nil
  return checkpointHistory[index]

::method checkpointById
  expose controller
  use strict arg checkpointIdArg
  signal on syntax name notFound
  return controller~checkpointById(checkpointIdArg)
notFound:
  return .nil

/* Explicitly materialise emulator component values at a retained checkpoint.
 * This is a debugger/export convenience, not a deep-copy persistence format:
 * Journal Pointed State's immutable/copy-on-write value ownership rule still
 * applies to values stored inside each returned Directory. */
::method materialiseCheckpoint
  expose components
  use strict arg checkpointArg
  if checkpointArg == .nil | \checkpointArg~hasMethod("POSITIONS") then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT", "checkpoint with positions required")
  positions = checkpointArg~positions
  out = .directory~new
  do id over components
    if \positions~hasIndex(id) then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_COMPONENT", id)
    if \components[id]~journalCanMoveTo(positions[id]) then return .TerminalResult~failure("TERMINAL_JOURNAL_POINT_UNAVAILABLE", id)
    out[id] = components[id]~reconstruct(positions[id])
  end
  return .TerminalResult~success(out)

::method timeline
  use strict arg alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  return .TerminalEmulatorTimeline~new(self, alchemySealerArg, alchemyCapabilityAuthorityArg)

::method preflightRestore
  expose components
  use strict arg checkpointArg
  if checkpointArg == .nil | \checkpointArg~hasMethod("POSITIONS") then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT", "checkpoint with positions required")
  positions = checkpointArg~positions
  do id over components
    if \positions~hasIndex(id) then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_COMPONENT", id)
    if \components[id]~journalCanMoveTo(positions[id]) then return .TerminalResult~failure("TERMINAL_JOURNAL_POINT_UNAVAILABLE", id)
  end
  return .TerminalResult~success(checkpointArg)

::method restore
  expose controller restoreCount lastCheckpointId
  use strict arg checkpointArg
  preflight = self~preflightRestore(checkpointArg)
  if \preflight~ok then return preflight
  cp = controller~restore(checkpointArg)
  restoreCount += 1
  lastCheckpointId = cp~checkpointId
  self~alchemyTouch("EMULATOR_RESTORE")
  ignore = self~terminalLifecycleEvent("EMULATOR_STATE_RESTORED", cp~checkpointId)
  return .TerminalResult~success(cp)

::method restoreBack
  use strict arg countArg = 0
  cp = self~checkpointBack(countArg)
  if cp == .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", countArg)
  return self~restore(cp)

::method noteProgress
  expose controller progressGeneration
  use strict arg sourceArg, markerArg, contextArg = .nil
  rec = controller~noteProgress(sourceArg, markerArg, contextArg)
  progressGeneration = rec["generation"]
  return rec

::method progress
  expose controller
  use strict arg sourceArg
  return controller~progress(sourceArg)

::method progressWatcher
  expose controller
  use strict arg sourceArg, thresholdArg = 2
  return .StateProgressWatcher~new(controller, sourceArg, thresholdArg)


/* Detached checkpoint evidence suitable for debugger/front-end display.  It
 * retains JournalPoint value objects, but never a StateOfNationController,
 * component, journal, live emulator target or mutable machine reference. */
::class TerminalEmulatorCheckpointEvidence public
::attribute checkpointId get
::attribute label get
::attribute eventName get
::attribute timestamp get
::attribute componentCount get

::method init
  expose checkpointId label eventName timestamp componentCount positions metadata
  use strict arg checkpointArg
  if checkpointArg == .nil | \checkpointArg~hasMethod("POSITIONS") then raise syntax 88.900 array("checkpoint evidence requires StateOfNationCheckpoint")
  checkpointId = checkpointArg~checkpointId
  label = checkpointArg~label
  eventName = checkpointArg~eventName
  timestamp = checkpointArg~timestamp
  positions = .TerminalUtil~copyDirectory(checkpointArg~positions)
  metadata = self~safeMetadata(checkpointArg~metadata)
  componentCount = positions~items

::method positions
  expose positions
  return .TerminalUtil~copyDirectory(positions)

::method metadata
  expose metadata
  return .TerminalUtil~copyDirectory(metadata)

::method safeMetadata private
  use strict arg sourceArg
  out = .directory~new
  if sourceArg == .nil | \sourceArg~isA(.Directory) then return out
  do key over sourceArg
    value = sourceArg[key]
    if value~isA(.String) then out[key] = value~string
    else out[key] = "<OBJECT>"
  end
  return out


/* Detached structural branch evidence.  It intentionally reports changed keys
 * and journal node identities/tags, not old/new state values.  Full values can
 * only be materialised explicitly through TerminalEmulatorTimeline~materialise. */
::class TerminalEmulatorBranchEvidence public
::attribute fromCheckpointId get
::attribute toCheckpointId get
::attribute componentCount get
::attribute undoNodeCount get
::attribute redoNodeCount get
::attribute createdAt get

::method init
  expose fromCheckpointId toCheckpointId componentCount undoNodeCount redoNodeCount createdAt componentPlans
  use strict arg fromIdArg, toIdArg, plansArg, undoCountArg, redoCountArg
  fromCheckpointId = fromIdArg~string
  toCheckpointId = toIdArg~string
  componentPlans = self~copyPlans(plansArg)
  componentCount = componentPlans~items
  undoNodeCount = undoCountArg
  redoNodeCount = redoCountArg
  createdAt = .DateTime~new~utcIsoDate

::method componentPlans
  expose componentPlans
  return self~copyPlans(componentPlans)

::method copyPlans private
  use strict arg sourceArg
  out = .directory~new
  do id over sourceArg
    sourcePlan = sourceArg[id]
    plan = .directory~new
    plan["fromPoint"] = sourcePlan["fromPoint"]~string
    plan["toPoint"] = sourcePlan["toPoint"]~string
    plan["undoCount"] = sourcePlan["undoCount"]
    plan["redoCount"] = sourcePlan["redoCount"]
    plan["undo"] = self~copyNodeSummaries(sourcePlan["undo"])
    plan["redo"] = self~copyNodeSummaries(sourcePlan["redo"])
    out[id] = plan
  end
  return out

::method copyNodeSummaries private
  use strict arg sourceArg
  out = .array~new
  do sourceSummary over sourceArg
    summary = .directory~new
    summary["nodeId"] = sourceSummary["nodeId"]~string
    summary["parentId"] = sourceSummary["parentId"]~string
    summary["tag"] = sourceSummary["tag"]~string
    summary["timestamp"] = sourceSummary["timestamp"]~string
    summary["changedKeys"] = .TerminalUtil~copyArray(sourceSummary["changedKeys"])
    out~append(summary)
  end
  return out


/* Read-only time-travel/debugger facade.  The machine reference is deliberately
 * not registered with Alchemy.  Branch evidence contains topology/tags/keys but
 * no state values; materialise() is the explicit value-bearing debugger path. */
::class TerminalEmulatorTimeline subclass TerminalAlchemyObject public
::attribute inspectionCount get
::attribute lastFromCheckpointId get
::attribute lastToCheckpointId get

::method init
  expose machine inspectionCount lastFromCheckpointId lastToCheckpointId
  use strict arg machineArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if machineArg == .nil | \machineArg~isA(.TerminalEmulatorStateMachine) then raise syntax 88.900 array("TerminalEmulatorTimeline requires TerminalEmulatorStateMachine")
  machine = machineArg
  inspectionCount = 0
  lastFromCheckpointId = ""
  lastToCheckpointId = ""
  meta = .directory~new
  meta["emulator_journal_api"] = .TerminalEmulatorJournalBuild~API_VERSION
  meta["timeline_boundary"] = "READ_ONLY_LOCAL_EMULATOR_HISTORY"
  self~initTerminalAlchemy("Read-only retained-branch debugger for journalled emulator state", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("inspectionCount", "CUSTOMER", "timeline inspections performed")
  self~registerStateVariable("lastFromCheckpointId", "CUSTOMER", "last structural branch-diff origin")
  self~registerStateVariable("lastToCheckpointId", "CUSTOMER", "last structural branch-diff destination")
  /* machine is a live capability/context reference and is not registered. */
  self~registerMethodContract("CHECKPOINT", "return detached evidence for one retained checkpoint", .array~of("CHECKPOINT"), "TERMINALEMULATORCHECKPOINTEVIDENCE", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("BRANCH", "return value-free structural evidence between two retained checkpoints", .array~of("FROM", "TO"), "TERMINALRESULT", .false, "FALSE", "CUSTOMER", "NORMAL", "READ", "USE")
  self~registerMethodContract("MATERIALISE", "explicitly reconstruct value-bearing emulator component state without moving live heads", .array~of("CHECKPOINT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "READ", "USE")

::method resolveCheckpoint private
  expose machine
  use strict arg checkpointArg
  if checkpointArg == .nil then return .nil
  if checkpointArg~hasMethod("POSITIONS") then return checkpointArg
  return machine~checkpointById(checkpointArg~string)

::method checkpoint
  expose inspectionCount
  use strict arg checkpointArg
  cp = self~resolveCheckpoint(checkpointArg)
  if cp == .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", checkpointArg)
  inspectionCount += 1
  self~alchemyTouch("EMULATOR_TIMELINE_CHECKPOINT")
  return .TerminalResult~success(.TerminalEmulatorCheckpointEvidence~new(cp))

::method materialise
  expose machine inspectionCount
  use strict arg checkpointArg
  cp = self~resolveCheckpoint(checkpointArg)
  if cp == .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", checkpointArg)
  materialised = machine~materialiseCheckpoint(cp)
  if materialised~ok then do
    inspectionCount += 1
    self~alchemyTouch("EMULATOR_TIMELINE_MATERIALISE")
  end
  return materialised

::method branch
  expose machine inspectionCount lastFromCheckpointId lastToCheckpointId
  use strict arg fromArg, toArg
  fromCp = self~resolveCheckpoint(fromArg)
  toCp = self~resolveCheckpoint(toArg)
  if fromCp == .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", fromArg)
  if toCp == .nil then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_NOT_FOUND", toArg)

  fromPositions = fromCp~positions
  toPositions = toCp~positions
  plans = .directory~new
  totalUndo = 0
  totalRedo = 0
  do id over machine~componentIds
    if \fromPositions~hasIndex(id) | \toPositions~hasIndex(id) then return .TerminalResult~failure("TERMINAL_JOURNAL_CHECKPOINT_COMPONENT", id)
    component = machine~stateComponent(id)
    raw = component~diff(fromPositions[id], toPositions[id])
    plan = .directory~new
    plan["fromPoint"] = raw["from"]~string
    plan["toPoint"] = raw["to"]~string
    undo = self~summariseNodes(raw["undo"])
    redo = self~summariseNodes(raw["redo"])
    plan["undo"] = undo
    plan["redo"] = redo
    plan["undoCount"] = undo~items
    plan["redoCount"] = redo~items
    totalUndo += undo~items
    totalRedo += redo~items
    plans[id] = plan
  end

  inspectionCount += 1
  lastFromCheckpointId = fromCp~checkpointId
  lastToCheckpointId = toCp~checkpointId
  self~alchemyTouch("EMULATOR_TIMELINE_BRANCH")
  evidence = .TerminalEmulatorBranchEvidence~new(lastFromCheckpointId, lastToCheckpointId, plans, totalUndo, totalRedo)
  return .TerminalResult~success(evidence)

::method summariseNodes private
  use strict arg nodesArg
  out = .array~new
  do node over nodesArg
    summary = .directory~new
    summary["nodeId"] = node~nodeId
    summary["parentId"] = node~parentId
    summary["tag"] = node~tag
    summary["timestamp"] = node~timestamp
    keys = .array~new
    do delta over node~deltas
      keys~append(delta~key)
    end
    summary["changedKeys"] = keys
    out~append(summary)
  end
  return out


/* Exact-token instruction/event boundary.  It makes the common emulator rule
 * "checkpoint before speculative execution" difficult to forget and rejects
 * stale/cross-boundary completion tokens.  It does not patch code itself. */
::class TerminalEmulatorExecutionTicket public
::attribute sequence get
::attribute checkpointId get
::attribute label get
::attribute eventName get
::attribute startedAt get

::method init
  expose sequence checkpointId label eventName startedAt
  use strict arg sequenceArg, checkpointIdArg, labelArg, eventNameArg
  sequence = sequenceArg
  checkpointId = checkpointIdArg~string
  label = labelArg~string
  eventName = eventNameArg~string
  startedAt = .DateTime~new~utcIsoDate


::class TerminalEmulatorExecutionBoundary subclass TerminalAlchemyObject public
::attribute state get
::attribute startedCount get
::attribute committedCount get
::attribute rolledBackCount get
::attribute lastCheckpointId get
::attribute lastOutcome get

::method init
  expose machine state nextSequence activeTicket activeCheckpoint startedCount committedCount rolledBackCount lastCheckpointId lastOutcome
  use strict arg machineArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if machineArg == .nil | \machineArg~isA(.TerminalEmulatorStateMachine) then raise syntax 88.900 array("TerminalEmulatorExecutionBoundary requires TerminalEmulatorStateMachine")
  machine = machineArg
  state = "IDLE"
  nextSequence = 1
  activeTicket = .nil
  activeCheckpoint = .nil
  startedCount = 0
  committedCount = 0
  rolledBackCount = 0
  lastCheckpointId = ""
  lastOutcome = ""
  meta = .directory~new
  meta["emulator_journal_api"] = .TerminalEmulatorJournalBuild~API_VERSION
  meta["execution_boundary"] = "CHECKPOINT_BEFORE_SPECULATIVE_EVENT"
  self~initTerminalAlchemy("Exact-token speculative execution boundary for local emulators", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("state", "CUSTOMER", "IDLE or ACTIVE")
  self~registerStateVariable("startedCount", "CUSTOMER", "execution attempts started")
  self~registerStateVariable("committedCount", "CUSTOMER", "successful speculative attempts committed")
  self~registerStateVariable("rolledBackCount", "CUSTOMER", "failed speculative attempts restored")
  self~registerStateVariable("lastCheckpointId", "CUSTOMER", "last execution checkpoint id")
  self~registerStateVariable("lastOutcome", "CUSTOMER", "last COMMITTED or ROLLED_BACK outcome")
  /* machine/activeTicket/activeCheckpoint are authority/context references and are not registered. */
  self~registerMethodContract("BEGIN", "checkpoint before one speculative emulator instruction/event and issue an exact completion ticket", .array~of("EVENT", "LABEL", "CONTEXT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("COMMIT", "commit the exact active attempt without moving journal state", .array~of("TICKET", "PROGRESS_MARKER", "CONTEXT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("ROLLBACK", "restore all emulator components to the exact active attempt checkpoint", .array~of("TICKET", "REASON", "CONTEXT"), "TERMINALRESULT", .false, "FALSE", "INTERNAL", "SENSITIVE", "MUTATE", "USE")

::method begin
  expose machine state nextSequence activeTicket activeCheckpoint startedCount lastCheckpointId
  use strict arg eventNameArg, labelArg = "", contextArg = .nil
  if state == "ACTIVE" then return .TerminalResult~failure("TERMINAL_EMULATOR_ATTEMPT_ACTIVE", activeTicket~sequence)
  eventName = eventNameArg~string~strip
  if eventName == "" then return .TerminalResult~failure("TERMINAL_EMULATOR_EVENT", "event name is empty")
  label = labelArg~string
  if label == "" then label = "before " || eventName
  activeCheckpoint = machine~checkpoint(label, eventName, contextArg)
  activeTicket = .TerminalEmulatorExecutionTicket~new(nextSequence, activeCheckpoint~checkpointId, label, eventName)
  nextSequence += 1
  state = "ACTIVE"
  startedCount += 1
  lastCheckpointId = activeCheckpoint~checkpointId
  self~alchemyTouch("EMULATOR_ATTEMPT_BEGIN")
  return .TerminalResult~success(activeTicket)

::method active
  expose state
  return state == "ACTIVE"

::method commit
  expose machine state activeTicket activeCheckpoint committedCount lastCheckpointId lastOutcome
  use strict arg ticketArg, progressMarkerArg = "", contextArg = .nil
  valid = self~validateTicket(ticketArg)
  if \valid~ok then return valid
  if progressMarkerArg~string \== "" then ignore = machine~noteProgress(activeTicket~eventName, progressMarkerArg, contextArg)
  committedCount += 1
  lastCheckpointId = activeCheckpoint~checkpointId
  lastOutcome = "COMMITTED"
  completed = activeTicket
  activeTicket = .nil
  activeCheckpoint = .nil
  state = "IDLE"
  self~alchemyTouch("EMULATOR_ATTEMPT_COMMIT")
  return .TerminalResult~success(completed)

::method rollback
  expose machine state activeTicket activeCheckpoint rolledBackCount lastCheckpointId lastOutcome
  use strict arg ticketArg, reasonArg = "FAULT", contextArg = .nil
  valid = self~validateTicket(ticketArg)
  if \valid~ok then return valid
  restored = machine~restore(activeCheckpoint)
  if \restored~ok then return restored
  rolledBackCount += 1
  lastCheckpointId = activeCheckpoint~checkpointId
  lastOutcome = "ROLLED_BACK"
  rolled = activeTicket
  activeTicket = .nil
  activeCheckpoint = .nil
  state = "IDLE"
  self~alchemyTouch("EMULATOR_ATTEMPT_ROLLBACK")
  ignore = self~terminalLifecycleEvent("EMULATOR_ATTEMPT_ROLLED_BACK", reasonArg~string)
  return .TerminalResult~success(rolled)

::method validateTicket private
  expose state activeTicket activeCheckpoint
  use strict arg ticketArg
  if state \== "ACTIVE" | activeTicket == .nil | activeCheckpoint == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_ATTEMPT_NONE", "no active attempt")
  if ticketArg == .nil | \ticketArg~isA(.TerminalEmulatorExecutionTicket) then return .TerminalResult~failure("TERMINAL_EMULATOR_ATTEMPT_TICKET", "execution ticket required")
  if ticketArg \== activeTicket then return .TerminalResult~failure("TERMINAL_EMULATOR_ATTEMPT_STALE", ticketArg~sequence)
  if ticketArg~checkpointId \== activeCheckpoint~checkpointId then return .TerminalResult~failure("TERMINAL_EMULATOR_ATTEMPT_STALE", ticketArg~checkpointId)
  return .TerminalResult~success(ticketArg)


/* Explicit opt-in marker for objects whose methods may be repaired in-place.
 * This deliberately does not apply to live terminal/session/service objects. */
::class TerminalEmulatorPatchable mixinclass Object public
::method terminalEmulatorPatchable
  return .true

::method installLiveMethod
  use strict arg methodNameArg, sourceArg
  self~setMethod(methodNameArg, sourceArg, "OBJECT")
  return .true


/* Front-end driven code-forward/state-backward recovery with a stricter target
 * boundary than the generic Journal Pointed State coordinator. */
::class TerminalEmulatorRecoveryCoordinator subclass TerminalAlchemyObject public
::attribute recoveryCount get
::attribute lastCheckpointId get
::attribute lastMethodName get

::method init
  expose machine frontEnd armedCheckpoint recoveryCount lastCheckpointId lastMethodName
  use strict arg machineArg, frontEndArg, alchemySealerArg = .nil, alchemyCapabilityAuthorityArg = .nil
  if machineArg == .nil | \machineArg~isA(.TerminalEmulatorStateMachine) then raise syntax 88.900 array("TerminalEmulatorRecoveryCoordinator requires TerminalEmulatorStateMachine")
  if frontEndArg == .nil | \frontEndArg~hasMethod("STATERECOVERYREQUEST") then raise syntax 88.900 array("terminal emulator recovery front end must implement stateRecoveryRequest")
  machine = machineArg
  frontEnd = frontEndArg
  armedCheckpoint = .nil
  recoveryCount = 0
  lastCheckpointId = ""
  lastMethodName = ""

  meta = .directory~new
  meta["emulator_journal_api"] = .TerminalEmulatorJournalBuild~API_VERSION
  meta["repair_boundary"] = "TERMINAL_EMULATOR_PATCHABLE_ONLY"
  self~initTerminalAlchemy("Code-forward/state-backward recovery coordinator for local emulators", meta, alchemySealerArg, alchemyCapabilityAuthorityArg)
  self~registerExternalRequirement("library", "oorexx_journal_pointed_state", "0.1", .true)
  self~registerStateVariable("recoveryCount", "CUSTOMER", "successful live emulator repairs")
  self~registerStateVariable("lastCheckpointId", "CUSTOMER", "last recovery checkpoint id")
  self~registerStateVariable("lastMethodName", "CUSTOMER", "last repaired emulator method name")
  /* machine/frontEnd/armedCheckpoint are live authority/context references and are not registered. */
  self~registerMethodContract("ARM", "checkpoint all journalled components before the emulator event to be retried", .array~of("LABEL", "CONTEXT"), "STATEOFNATIONCHECKPOINT", .false, "FALSE", "INTERNAL", "NORMAL", "MUTATE", "USE")
  self~registerMethodContract("RECOVER", "request an explicitly marked emulator method patch then rewind state to the armed checkpoint", .array~of("REASON", "TARGET", "METHOD_NAME", "CONTEXT"), "TERMINALRESULT", .true, "FALSE", "INTERNAL", "SECURITY_BOUNDARY", "MUTATE", "USE")

::method arm
  expose machine armedCheckpoint lastCheckpointId
  use strict arg labelArg = "instruction-boundary", contextArg = .nil
  armedCheckpoint = machine~checkpoint(labelArg, "RECOVERY_ARM", contextArg)
  lastCheckpointId = armedCheckpoint~checkpointId
  return armedCheckpoint

::method armedCheckpoint
  expose armedCheckpoint
  return armedCheckpoint

::method recover public protected
  expose machine frontEnd armedCheckpoint recoveryCount lastCheckpointId lastMethodName
  use strict arg reasonArg, targetArg, methodNameArg, contextArg = .nil
  if armedCheckpoint == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_RECOVERY_NOT_ARMED", "no checkpoint armed")
  if \self~isAllowedPatchTarget(targetArg) then return .TerminalResult~failure("TERMINAL_EMULATOR_PATCH_TARGET_DENIED", methodNameArg)

  preflight = machine~preflightRestore(armedCheckpoint)
  if \preflight~ok then return preflight

  request = .StateRecoveryRequest~new(armedCheckpoint, reasonArg, targetArg, methodNameArg, contextArg)
  response = frontEnd~stateRecoveryRequest(request)
  if response == .nil then return .TerminalResult~failure("TERMINAL_EMULATOR_PATCH_UNAVAILABLE", methodNameArg)

  patchTarget = targetArg
  patchName = methodNameArg~string
  source = response
  scope = "OBJECT"
  if response~isA(.Directory) then do
    if response~hasIndex("target") then patchTarget = response["target"]
    if response~hasIndex("methodName") then patchName = response["methodName"]~string
    if \response~hasIndex("source") then return .TerminalResult~failure("TERMINAL_EMULATOR_PATCH_SOURCE", "recovery response lacks source")
    source = response["source"]
    if response~hasIndex("scope") then scope = response["scope"]~string~upper
  end

  if scope \== "OBJECT" then return .TerminalResult~failure("TERMINAL_EMULATOR_PATCH_SCOPE", scope)
  if \self~isAllowedPatchTarget(patchTarget) then return .TerminalResult~failure("TERMINAL_EMULATOR_PATCH_TARGET_DENIED", patchName)

  patchTarget~installLiveMethod(patchName, source)
  restored = machine~restore(armedCheckpoint)
  if \restored~ok then return restored

  recoveryCount += 1
  lastCheckpointId = armedCheckpoint~checkpointId
  lastMethodName = patchName
  self~alchemyTouch("EMULATOR_LIVE_REPAIR")
  ignore = self~terminalAuthorityEvent("EMULATOR_METHOD_REPAIRED", patchName, lastCheckpointId)
  recovery = .StateRecoveryResult~new(.true, armedCheckpoint, request, patchTarget, patchName)
  return .TerminalResult~success(recovery)

::method isAllowedPatchTarget private
  use strict arg targetArg
  if targetArg == .nil then return .false
  if \targetArg~hasMethod("TERMINALEMULATORPATCHABLE") then return .false
  if targetArg~terminalEmulatorPatchable \== .true then return .false
  if \targetArg~hasMethod("INSTALLLIVEMETHOD") then return .false
  return .true


::requires "TerminalAlchemy.cls"
::requires "TerminalCore.cls"
::requires "JournalPointedState.cls"

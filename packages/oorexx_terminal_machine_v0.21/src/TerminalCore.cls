/*
 * Generic ooRexx terminal core v0.2
 *
 * The core deliberately knows nothing about 5250, 3270, VT100, Telnet,
 * EBCDIC, sockets, or AI agents.  Concrete terminal personalities provide
 * their own model and action codecs above this substrate.
 *
 * Invariants:
 *   - TerminalSnapshot objects are detached immutable evidence.
 *   - TerminalWatchAlong receives snapshots only and has no input path.
 *   - KnownTerminalState is an interpretation of evidence, never evidence.
 *   - Observed transitions are knowledge, never action authority.
 */

::class TerminalBuild public
::constant PRODUCT "ooRexx Generic Terminal Core"
::constant RELEASE "0.2"
::constant API_VERSION "terminal.core/0.2"

::class TerminalStatus public
::constant READY "READY"
::constant HOST_WAIT "HOST_WAIT"
::constant OPERATOR_WAIT "OPERATOR_WAIT"
::constant CLOSED "CLOSED"
::constant ERROR "ERROR"

::class TerminalMatchStatus public
::constant MATCH "MATCH"
::constant NO_MATCH "NO_MATCH"
::constant AMBIGUOUS "AMBIGUOUS"

::class TerminalResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get

::method init
  expose ok code detail value
  use arg okArg, codeArg = "", detailArg = "", valueArg = .nil
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  value = valueArg

::method success class
  use arg valueArg = .nil
  return self~new(.true, "OK", "", valueArg)

::method failure class
  use arg codeArg, detailArg = ""
  return self~new(.false, codeArg, detailArg, .nil)

::class TerminalUtil public
::method copyArray class
  use arg source
  target = .array~new
  if source == .nil then return target
  do item over source
    target~append(item)
  end
  return target

::method copyDirectory class
  use arg source
  target = .directory~new
  if source == .nil then return target
  do key over source
    target[key] = source[key]
  end
  return target

::method cloneFieldArray class
  use arg source
  target = .array~new
  if source == .nil then return target
  do item over source
    if item == .nil then iterate
    if item~hasMethod("COPYDETACHED") then target~append(item~copyDetached)
    else target~append(item)
  end
  return target

::method safeString class
  use arg value
  if value == .nil then return ""
  return value~string

/* Stable non-cryptographic content identifier for snapshots/layouts.
 * It is deliberately not a password verifier or security primitive. */
::method stableDigest class
  use arg valueArg
  numeric digits 30
  text = self~safeString(valueArg)
  h = 2166136261
  do i = 1 to text~length
    octet = x2d(text~substr(i,1)~c2x)
    h = (h * 65599 + octet) // 4294967296
  end
  return right(d2x(h), 8, "0")

::class TerminalCapabilities public
::method init
  expose entries
  entries = .table~new

::method add
  expose entries
  use arg capability
  key = capability~string~strip~upper
  if key == "" then return self
  entries~put(.true, key)
  return self

::method remove
  expose entries
  use arg capability
  key = capability~string~strip~upper
  entries~remove(key)
  return self

::method has
  expose entries
  use arg capability
  key = capability~string~strip~upper
  return entries~at(key) \== .nil

::method names
  expose entries
  namesOut = .array~new
  do key over entries
    namesOut~append(key)
  end
  return namesOut

::method copyDetached
  expose entries
  copy = .TerminalCapabilities~new
  do key over entries
    copy~add(key)
  end
  return copy

::class TerminalFieldSnapshot public
::attribute fieldId get
::attribute row get
::attribute column get
::attribute length get
::attribute value get
::attribute inputCapable get
::attribute protected get
::attribute nonDisplay get
::attribute modified get
::attribute numeric get
::attribute attributes get

::method init
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  use arg fieldIdArg, rowArg, columnArg, lengthArg, valueArg = "", inputArg = .false, protectedArg = .true, nonDisplayArg = .false, modifiedArg = .false, numericArg = .false, attributesArg = .nil
  fieldId = fieldIdArg~string
  row = rowArg
  column = columnArg
  length = lengthArg
  value = valueArg~string
  inputCapable = inputArg == .true
  protected = protectedArg == .true
  nonDisplay = nonDisplayArg == .true
  modified = modifiedArg == .true
  numeric = numericArg == .true
  attributes = .TerminalUtil~copyDirectory(attributesArg)

::method attribute
  expose attributes
  use arg name
  return attributes[name~string]

::method copyDetached
  expose fieldId row column length value inputCapable protected nonDisplay modified numeric attributes
  return .TerminalFieldSnapshot~new(fieldId, row, column, length, value, inputCapable, protected, nonDisplay, modified, numeric, attributes)

::method displayValue
  expose value nonDisplay length
  if \nonDisplay then return value
  if length <= 0 then return "<SECRET>"
  return copies("*", length)


::class TerminalOperatorCondition public
::attribute state get
::attribute code get
::attribute kind get
::attribute message get
::attribute origin get
::attribute cursorRow get
::attribute cursorColumn get
::attribute recoverable get
::attribute recoveryActions get

::method init
  expose state code kind message origin cursorRow cursorColumn recoverable recoveryActions
  use arg stateArg = "", codeArg = "", kindArg = "", messageArg = "", originArg = "", rowArg = 0, columnArg = 0, recoverableArg = .false, recoveryArg = .nil
  state = stateArg~string~strip~upper
  code = codeArg~string
  kind = kindArg~string~strip~upper
  message = messageArg~string
  origin = originArg~string~strip~upper
  cursorRow = rowArg
  cursorColumn = columnArg
  recoverable = recoverableArg == .true
  recoveryActions = .TerminalUtil~copyArray(recoveryArg)

::method copyDetached
  expose state code kind message origin cursorRow cursorColumn recoverable recoveryActions
  return .TerminalOperatorCondition~new(state, code, kind, message, origin, cursorRow, cursorColumn, recoverable, recoveryActions)

::class TerminalSnapshot public
::attribute generation get
::attribute terminalType get
::attribute rows get
::attribute columns get
::attribute cursorRow get
::attribute cursorColumn get
::attribute keyboardState get
::attribute sessionState get
::attribute contentDigest get
::attribute layoutFingerprint get
::attribute timestamp get

::method init
  expose generation terminalType rows columns cursorRow cursorColumn keyboardState sessionState contentDigest layoutFingerprint timestamp capabilities textRows fields metadata
  use arg generationArg, terminalTypeArg, rowsArg, columnsArg, cursorRowArg, cursorColumnArg, keyboardStateArg, sessionStateArg, textRowsArg, fieldsArg = .nil, capabilitiesArg = .nil, metadataArg = .nil, contentDigestArg = "", layoutFingerprintArg = "", timestampArg = ""
  generation = generationArg
  terminalType = terminalTypeArg~string
  rows = rowsArg
  columns = columnsArg
  cursorRow = cursorRowArg
  cursorColumn = cursorColumnArg
  keyboardState = keyboardStateArg~string~upper
  sessionState = sessionStateArg~string~upper
  textRows = .TerminalUtil~copyArray(textRowsArg)
  fields = .TerminalUtil~cloneFieldArray(fieldsArg)
  if capabilitiesArg == .nil then capabilities = .TerminalCapabilities~new
  else capabilities = capabilitiesArg~copyDetached
  metadata = .TerminalUtil~copyDirectory(metadataArg)
  contentDigest = contentDigestArg~string
  layoutFingerprint = layoutFingerprintArg~string
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::method capabilities
  expose capabilities
  return capabilities~copyDetached

::method textRows
  expose textRows
  return .TerminalUtil~copyArray(textRows)

::method fields
  expose fields
  return .TerminalUtil~cloneFieldArray(fields)

::method metadata
  expose metadata
  return .TerminalUtil~copyDirectory(metadata)

::method operatorCondition
  expose metadata
  state = .TerminalUtil~safeString(metadata["operatorState"])~strip~upper
  if state == "" then return .nil
  recovery = .array~new
  recoveryText = .TerminalUtil~safeString(metadata["operatorRecovery"])~strip
  if recoveryText \= "" then do item over recoveryText~makeArray(",")
    action = item~strip~upper
    if action \= "" then recovery~append(action)
  end
  return .TerminalOperatorCondition~new(state, .TerminalUtil~safeString(metadata["operatorErrorCode"]), .TerminalUtil~safeString(metadata["operatorErrorKind"]), .TerminalUtil~safeString(metadata["operatorErrorMessage"]), .TerminalUtil~safeString(metadata["operatorErrorOrigin"]), metadata["operatorErrorCursorRow"], metadata["operatorErrorCursorColumn"], metadata["operatorRecoverable"] == 1 | metadata["operatorRecoverable"] == .true, recovery)

::method rowText
  expose textRows rows
  use arg rowNumber
  if rowNumber < 1 | rowNumber > rows then return ""
  if rowNumber > textRows~items then return ""
  return textRows[rowNumber]

::method field
  expose fields
  use arg id
  wanted = id~string
  do f over fields
    if f~fieldId == wanted then return f~copyDetached
  end
  return .nil

::method fieldAt
  expose fields columns rows
  use arg rowArg, columnArg
  if rowArg < 1 | rowArg > rows | columnArg < 1 | columnArg > columns then return .nil
  wanted = ((rowArg - 1) * columns) + columnArg
  do f over fields
    startPos = ((f~row - 1) * columns) + f~column
    lastPos = startPos + f~length - 1
    if wanted >= startPos & wanted <= lastPos then return f~copyDetached
  end
  return .nil

::method visibleText
  expose textRows
  textOut = ""
  first = .true
  do line over textRows
    if first then first = .false
    else textOut ||= "0a"x
    textOut ||= line
  end
  return textOut

::method copyDetached
  expose generation terminalType rows columns cursorRow cursorColumn keyboardState sessionState textRows fields capabilities metadata contentDigest layoutFingerprint timestamp
  return .TerminalSnapshot~new(generation, terminalType, rows, columns, cursorRow, cursorColumn, keyboardState, sessionState, textRows, fields, capabilities, metadata, contentDigest, layoutFingerprint, timestamp)

::class TerminalAction public
::attribute generation get
::attribute kind get
::attribute name get
::attribute value get
::attribute actor get
::attribute timestamp get

::method init
  expose generation kind name value actor timestamp
  use arg generationArg, kindArg, nameArg = "", valueArg = "", actorArg = "", timestampArg = ""
  generation = generationArg
  kind = kindArg~string~upper
  name = nameArg~string
  value = valueArg~string
  actor = actorArg~string
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::class TerminalTraceEvent public
::attribute sequence get
::attribute eventType get
::attribute generation get
::attribute payload get
::attribute timestamp get

::method init
  expose sequence eventType generation payload timestamp
  use arg sequenceArg, eventTypeArg, generationArg, payloadArg = .nil, timestampArg = ""
  sequence = sequenceArg
  eventType = eventTypeArg~string~upper
  generation = generationArg
  payload = payloadArg
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::class TerminalTrace subclass TerminalAlchemyObject public
::method init
  expose events nextSequence
  use arg sealerArg = .nil, alchemyAuthorityArg = .nil
  self~initTerminalAlchemy("Detached-safe terminal trace collector", .nil, sealerArg, alchemyAuthorityArg)
  events = .array~new
  nextSequence = 1
  self~registerStateVariable("nextSequence", "CUSTOMER", "next trace sequence number")
  self~registerMethodContract("APPENDSNAPSHOT", "append a detached terminal snapshot", .array~of("SNAPSHOT"), "TERMINALTRACE", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("APPENDACTION", "append a safe terminal action record", .array~of("ACTION"), "TERMINALTRACE", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("SNAPSHOTS", "return detached snapshots", .array~new, "ARRAY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")

::method appendSnapshot
  expose events nextSequence
  use arg snapshot
  events~append(.TerminalTraceEvent~new(nextSequence, "SNAPSHOT", snapshot~generation, snapshot~copyDetached))
  nextSequence += 1
  self~alchemyTouch("TRACE_SNAPSHOT")
  ignore = self~terminalObservationEvent(snapshot~generation, "TRACE_SNAPSHOT")
  return self

::method appendAction
  expose events nextSequence
  use arg action
  events~append(.TerminalTraceEvent~new(nextSequence, "ACTION", action~generation, action))
  nextSequence += 1
  return self

::method appendNote
  expose events nextSequence
  use arg generationArg, note
  events~append(.TerminalTraceEvent~new(nextSequence, "NOTE", generationArg, note~string))
  nextSequence += 1
  return self

::method events
  expose events
  return .TerminalUtil~copyArray(events)

::method snapshotCount
  expose events
  count = 0
  do event over events
    if event~eventType == "SNAPSHOT" then count += 1
  end
  return count

::method snapshots
  expose events
  snapshotsOut = .array~new
  do event over events
    if event~eventType == "SNAPSHOT" then snapshotsOut~append(event~payload~copyDetached)
  end
  return snapshotsOut

::class TerminalReplay subclass TerminalAlchemyObject public
::attribute position get

::method init
  expose snapshots position
  use arg trace, sealerArg = .nil, alchemyAuthorityArg = .nil
  self~initTerminalAlchemy("Read-only replay cursor over detached terminal snapshots", .nil, sealerArg, alchemyAuthorityArg)
  snapshots = trace~snapshots
  self~registerStateVariable("position", "CUSTOMER", "current replay position")
  self~registerMethodContract("SEEK", "seek to a terminal generation", .array~of("GENERATION"), "TERMINALRESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  self~registerMethodContract("CURRENT", "return current detached snapshot", .array~new, "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")
  if snapshots~items > 0 then position = 1
  else position = 0

::method count
  expose snapshots
  return snapshots~items

::method current
  expose snapshots position
  if position < 1 | position > snapshots~items then return .nil
  return snapshots[position]~copyDetached

::method seek
  expose snapshots position
  use arg generationArg
  do i = 1 to snapshots~items
    if snapshots[i]~generation == generationArg then do
      position = i
      return .TerminalResult~success(snapshots[i]~copyDetached)
    end
  end
  return .TerminalResult~failure("GENERATION_NOT_FOUND", generationArg)

::method next
  expose snapshots position
  if position < snapshots~items then position += 1
  return self~current

::method previous
  expose snapshots position
  if position > 1 then position -= 1
  return self~current

::method freeze
  expose snapshots position
  if position < 1 | position > snapshots~items then return .nil
  current = snapshots[position]~copyDetached
  previous = .nil
  if position > 1 then previous = snapshots[position - 1]~copyDetached
  return .FrozenTerminalState~new(current, previous, position)

::class FrozenTerminalState public
::attribute snapshot get
::attribute previousSnapshot get
::attribute tracePosition get
::attribute frozenAt get

::method init
  expose snapshot previousSnapshot tracePosition frozenAt
  use arg snapshotArg, previousArg = .nil, tracePositionArg = 0
  snapshot = snapshotArg~copyDetached
  if previousArg == .nil then previousSnapshot = .nil
  else previousSnapshot = previousArg~copyDetached
  tracePosition = tracePositionArg
  frozenAt = .DateTime~new~utcIsoDate

::class TerminalWatchAlong subclass TerminalAlchemyObject public
::attribute capacity get
::attribute lastSeenGeneration get

::method init
  expose history capacity lastSeenGeneration
  use arg capacityArg = 64, sealerArg = .nil, alchemyAuthorityArg = .nil
  self~initTerminalAlchemy("Read-only terminal watch-along observer", .nil, sealerArg, alchemyAuthorityArg)
  if capacityArg < 1 then capacityArg = 1
  capacity = capacityArg
  history = .array~new
  lastSeenGeneration = 0
  self~registerStateVariable("capacity", "CUSTOMER", "bounded retained snapshot count")
  self~registerStateVariable("lastSeenGeneration", "CUSTOMER", "most recently observed terminal generation")
  self~registerMethodContract("OBSERVE", "observe one detached terminal snapshot", .array~of("SNAPSHOT"), "TERMINALWATCHALONG", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CURRENT", "return most recent detached snapshot", .array~new, "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")

::method observe
  expose history capacity lastSeenGeneration
  use arg snapshot
  detached = snapshot~copyDetached
  history~append(detached)
  lastSeenGeneration = detached~generation
  do while history~items > capacity
    history~remove(1)
  end
  self~alchemyTouch("OBSERVE")
  ignore = self~terminalObservationEvent(lastSeenGeneration, "WATCH_ALONG")
  return self

::method current
  expose history
  if history~items == 0 then return .nil
  return history[history~items]~copyDetached

::method back
  expose history
  use arg count = 1
  index = history~items - count
  if index < 1 | index > history~items then return .nil
  return history[index]~copyDetached

::method history
  expose history
  historyOut = .array~new
  do snap over history
    historyOut~append(snap~copyDetached)
  end
  return historyOut

::method rows
  use arg fromRow, toRow, snapshotArg = .nil
  if snapshotArg == .nil then snapshot = self~current
  else snapshot = snapshotArg
  if snapshot == .nil then return ""
  if fromRow < 1 then fromRow = 1
  if toRow > snapshot~rows then toRow = snapshot~rows
  if toRow < fromRow then return ""
  rowsOut = ""
  do row = fromRow to toRow
    if rowsOut \== "" then rowsOut ||= "0a"x
    rowsOut ||= right(row, 2) || "  " || snapshot~rowText(row)
  end
  return rowsOut

::method snippet
  use arg radius = 2, snapshotArg = .nil
  if snapshotArg == .nil then snapshot = self~current
  else snapshot = snapshotArg
  if snapshot == .nil then return ""
  caps = snapshot~capabilities
  if caps~has("CHARACTER_GRID") then do
    center = snapshot~cursorRow
    if center < 1 then center = 1
    fromRow = center - radius
    toRow = center + radius
    return self~rows(fromRow, toRow, snapshot)
  end
  /* Stream-like terminals: show the most recent lines without inventing a grid. */
  fromRow = snapshot~rows - (radius * 2)
  if fromRow < 1 then fromRow = 1
  textOut = ""
  do row = fromRow to snapshot~rows
    if textOut \== "" then textOut ||= "0a"x
    textOut ||= snapshot~rowText(row)
  end
  return textOut

::method look
  use arg radius = 3
  snapshot = self~current
  if snapshot == .nil then return "NO SNAPSHOT"
  header = "Terminal: " || snapshot~terminalType || "  generation: " || snapshot~generation || "  state: " || snapshot~sessionState
  caps = snapshot~capabilities
  if caps~has("CHARACTER_GRID") then header ||= "0a"x || "keyboard: " || snapshot~keyboardState || "  cursor: r" || snapshot~cursorRow || " c" || snapshot~cursorColumn
  else header ||= "0a"x || "keyboard: " || snapshot~keyboardState || "  mode: STREAM"
  return header || "0a0a"x || self~snippet(radius, snapshot)

/* Criterion operators are deliberately explicit and inspectable. */
::class KnownStateCriterion public
::attribute criterionId get
::attribute kind get
::attribute arg1 get
::attribute arg2 get
::attribute negate get

::method init
  expose criterionId kind arg1 arg2 negate
  use arg criterionIdArg, kindArg, arg1Arg = "", arg2Arg = "", negateArg = .false
  criterionId = criterionIdArg~string
  kind = kindArg~string~strip~upper
  arg1 = arg1Arg
  arg2 = arg2Arg
  negate = negateArg == .true

::method evaluate
  expose kind arg1 arg2 negate criterionId
  use arg snapshot
  matched = .false
  detail = ""

  select
    when kind == "TERMINAL_TYPE_EQ" then do
      matched = snapshot~terminalType == arg1~string
      detail = snapshot~terminalType
    end
    when kind == "LAYOUT_FINGERPRINT_EQ" then do
      matched = snapshot~layoutFingerprint == arg1~string
      detail = snapshot~layoutFingerprint
    end
    when kind == "CONTENT_DIGEST_EQ" then do
      matched = snapshot~contentDigest == arg1~string
      detail = snapshot~contentDigest
    end
    when kind == "KEYBOARD_EQ" then do
      matched = snapshot~keyboardState == arg1~string~upper
      detail = snapshot~keyboardState
    end
    when kind == "SESSION_STATE_EQ" then do
      matched = snapshot~sessionState == arg1~string~upper
      detail = snapshot~sessionState
    end
    when kind == "OPERATOR_STATE_EQ" then do
      condition = snapshot~operatorCondition
      if condition \== .nil then do
        matched = condition~state == arg1~string~strip~upper
        detail = condition~state
      end
      else detail = "NO_OPERATOR_CONDITION"
    end
    when kind == "OPERATOR_ERROR_KIND_EQ" then do
      condition = snapshot~operatorCondition
      if condition \== .nil then do
        matched = condition~kind == arg1~string~strip~upper
        detail = condition~kind
      end
      else detail = "NO_OPERATOR_CONDITION"
    end
    when kind == "OPERATOR_ERROR_CODE_EQ" then do
      condition = snapshot~operatorCondition
      if condition \== .nil then do
        matched = condition~code == arg1~string
        detail = condition~code
      end
      else detail = "NO_OPERATOR_CONDITION"
    end
    when kind == "CAPABILITY" then do
      caps = snapshot~capabilities
      matched = caps~has(arg1)
      detail = arg1~string~upper
    end
    when kind == "ROW_CONTAINS" then do
      rowNumber = arg1
      rowText = snapshot~rowText(rowNumber)
      matched = pos(arg2~string, rowText) > 0
      detail = rowText
    end
    when kind == "FIELD_VALUE_EQ" then do
      f = snapshot~field(arg1)
      if f \== .nil then do
        matched = f~value == arg2~string
        detail = f~value
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "FIELD_VALUE_CONTAINS" then do
      f = snapshot~field(arg1)
      if f \== .nil then do
        matched = pos(arg2~string, f~value) > 0
        detail = f~value
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "FIELD_INPUT" then do
      f = snapshot~field(arg1)
      if f \== .nil then do
        matched = f~inputCapable
        detail = f~inputCapable
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "FIELD_COUNT_EQ" then do
      matched = snapshot~fields~items == arg1
      detail = snapshot~fields~items
    end
    when kind == "ROW_CONTAINS_CI" then do
      rowNumber = arg1
      rowText = snapshot~rowText(rowNumber)
      matched = pos(arg2~string~upper, rowText~upper) > 0
      detail = rowText
    end
    when kind == "FIELD_AT_INPUT" then do
      f = snapshot~fieldAt(arg1, arg2)
      if f \== .nil then do
        matched = f~inputCapable
        detail = f~fieldId || ":len=" || f~length
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "FIELD_AT_NONDISPLAY" then do
      f = snapshot~fieldAt(arg1, arg2)
      if f \== .nil then do
        matched = f~nonDisplay
        detail = f~fieldId || ":nondisplay=" || f~nonDisplay
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "FIELD_AT_LENGTH_EQ" then do
      parse var arg1 rowWanted "," columnWanted
      f = snapshot~fieldAt(rowWanted, columnWanted)
      if f \== .nil then do
        matched = f~length == arg2
        detail = f~fieldId || ":len=" || f~length
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "CURSOR_IN_FIELD_AT" then do
      f = snapshot~fieldAt(arg1, arg2)
      if f \== .nil then do
        cursorPos = ((snapshot~cursorRow - 1) * snapshot~columns) + snapshot~cursorColumn
        fieldPos = ((f~row - 1) * snapshot~columns) + f~column
        lastPos = fieldPos + f~length - 1
        matched = cursorPos >= fieldPos & cursorPos <= lastPos
        detail = f~fieldId || ":r" || snapshot~cursorRow || "c" || snapshot~cursorColumn
      end
      else detail = "FIELD_NOT_FOUND"
    end
    when kind == "CURSOR_IN_FIELD" then do
      f = snapshot~field(arg1)
      if f \== .nil then do
        cursorPos = ((snapshot~cursorRow - 1) * snapshot~columns) + snapshot~cursorColumn
        fieldPos = ((f~row - 1) * snapshot~columns) + f~column
        lastPos = fieldPos + f~length - 1
        matched = cursorPos >= fieldPos & cursorPos <= lastPos
        detail = "r" || snapshot~cursorRow || "c" || snapshot~cursorColumn
      end
      else detail = "FIELD_NOT_FOUND"
    end
    otherwise return .KnownStateCriterionResult~new(criterionId, .false, "UNSUPPORTED_CRITERION:" || kind)
  end

  if negate then matched = \matched
  return .KnownStateCriterionResult~new(criterionId, matched, detail)

::class KnownStateCriterionResult public
::attribute criterionId get
::attribute matched get
::attribute detail get

::method init
  expose criterionId matched detail
  use arg idArg, matchedArg, detailArg = ""
  criterionId = idArg~string
  matched = matchedArg == .true
  detail = detailArg~string

::class KnownStateAnnotation public
::attribute annotationId get
::attribute author get
::attribute description get
::attribute status get
::attribute timestamp get
::attribute supersedes get

::method init
  expose annotationId author description status timestamp supersedes
  use arg annotationIdArg, authorArg, descriptionArg, statusArg = "CONFIRMED", supersedesArg = "", timestampArg = ""
  annotationId = annotationIdArg~string
  author = authorArg~string
  description = descriptionArg~string
  status = statusArg~string~upper
  supersedes = supersedesArg~string
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::class KnownStateTransition public
::attribute fromStateId get
::attribute actionKind get
::attribute actionName get
::attribute toStateId get
::attribute observationCount get
::attribute note get

::method init
  expose fromStateId actionKind actionName toStateId observationCount note
  use arg fromArg, actionKindArg, actionNameArg, toArg, observationCountArg = 1, noteArg = ""
  fromStateId = fromArg~string
  actionKind = actionKindArg~string~upper
  actionName = actionNameArg~string
  toStateId = toArg~string
  observationCount = observationCountArg
  note = noteArg~string

::class KnownTerminalState public
::attribute stateId get
::attribute name get
::attribute description get
::attribute createdBy get
::attribute createdAt get

::method init
  expose stateId name description createdBy createdAt criteria annotations transitions exemplars
  use arg stateIdArg, nameArg, descriptionArg = "", createdByArg = ""
  stateId = stateIdArg~string
  name = nameArg~string
  description = descriptionArg~string
  createdBy = createdByArg~string
  createdAt = .DateTime~new~utcIsoDate
  criteria = .array~new
  annotations = .array~new
  transitions = .array~new
  exemplars = .array~new

::method addCriterion
  expose criteria
  use arg criterion
  criteria~append(criterion)
  return self

::method criteria
  expose criteria
  return .TerminalUtil~copyArray(criteria)

::method addAnnotation
  expose annotations
  use arg annotation
  annotations~append(annotation)
  return self

::method annotations
  expose annotations
  return .TerminalUtil~copyArray(annotations)

::method addTransition
  expose transitions
  use arg transition
  transitions~append(transition)
  return self

::method transitions
  expose transitions
  return .TerminalUtil~copyArray(transitions)

::method addExemplar
  expose exemplars
  use arg frozenState
  exemplars~append(frozenState)
  return self

::method exemplarCount
  expose exemplars
  return exemplars~items

::method exemplars
  expose exemplars
  return .TerminalUtil~copyArray(exemplars)

::method match
  expose criteria stateId name
  use arg snapshot
  evidence = .array~new
  if criteria~items == 0 then return .KnownStateCandidateResult~new(stateId, name, .false, evidence, "NO_CRITERIA")
  allMatched = .true
  do criterion over criteria
    criterionOutcome = criterion~evaluate(snapshot)
    evidence~append(criterionOutcome)
    if \criterionOutcome~matched then allMatched = .false
  end
  return .KnownStateCandidateResult~new(stateId, name, allMatched, evidence, "")

::class KnownStateCandidateResult public
::attribute stateId get
::attribute name get
::attribute matched get
::attribute evidence get
::attribute detail get

::method init
  expose stateId name matched evidence detail
  use arg stateIdArg, nameArg, matchedArg, evidenceArg, detailArg = ""
  stateId = stateIdArg~string
  name = nameArg~string
  matched = matchedArg == .true
  evidence = .TerminalUtil~copyArray(evidenceArg)
  detail = detailArg~string

::class KnownStateMatchResult public
::attribute status get
::attribute candidates get

::method init
  expose status candidates
  use arg statusArg, candidatesArg
  status = statusArg~string~upper
  candidates = .TerminalUtil~copyArray(candidatesArg)

::method matchedStateId
  expose status candidates
  if status \== .TerminalMatchStatus~MATCH then return ""
  if candidates~items \== 1 then return ""
  return candidates[1]~stateId

/* Detached semantic observation.  It records only the interpretation result,
 * not the screen contents which produced it. */
::class TerminalKnownStateObservation public
::attribute generation get
::attribute status get
::attribute stateId get
::attribute candidateStateIds get
::attribute timestamp get

::method init
  expose generation status stateId candidateStateIds timestamp
  use arg generationArg, statusArg, stateIdArg = "", candidateIdsArg = .nil, timestampArg = ""
  generation = generationArg
  status = statusArg~string~strip~upper
  stateId = stateIdArg~string
  candidateStateIds = .TerminalUtil~copyArray(candidateIdsArg)
  if timestampArg == "" then timestamp = .DateTime~new~utcIsoDate
  else timestamp = timestampArg~string

::method copyDetached
  expose generation status stateId candidateStateIds timestamp
  return .TerminalKnownStateObservation~new(generation, status, stateId, candidateStateIds, timestamp)

/*
 * Read-only semantic watcher.  A KnownStateCatalog remains knowledge, never
 * authority: this tracker interprets committed snapshots but has no terminal
 * mutation methods and cannot turn an observed transition into permission to
 * perform the next action.
 */
::class TerminalKnownStateTracker subclass TerminalAlchemyObject public
::attribute capacity get
::attribute currentGeneration get
::attribute currentStatus get
::attribute currentStateId get
::attribute previousKnownStateId get
::attribute transitionCount get

::method init
  expose catalog history capacity currentGeneration currentStatus currentStateId previousKnownStateId transitionCount lastKnownStateId
  use arg catalogArg, capacityArg = 64, sealerArg = .nil, alchemyAuthorityArg = .nil
  if catalogArg == .nil then raise syntax 88.900 array("TerminalKnownStateTracker requires a KnownStateCatalog")
  if \catalogArg~hasMethod("MATCH") then raise syntax 88.900 array("TerminalKnownStateTracker catalog must implement match(snapshot)")
  if \capacityArg~datatype("W") | capacityArg < 1 then capacityArg = 64
  self~initTerminalAlchemy("Read-only semantic terminal-state tracker", .nil, sealerArg, alchemyAuthorityArg)
  catalog = catalogArg
  history = .array~new
  capacity = capacityArg
  currentGeneration = 0
  currentStatus = .TerminalMatchStatus~NO_MATCH
  currentStateId = ""
  previousKnownStateId = ""
  transitionCount = 0
  lastKnownStateId = ""
  self~registerStateVariable("capacity", "CUSTOMER", "bounded semantic observation history")
  self~registerStateVariable("currentGeneration", "CUSTOMER", "latest interpreted terminal generation")
  self~registerStateVariable("currentStatus", "CUSTOMER", "MATCH, NO_MATCH or AMBIGUOUS")
  self~registerStateVariable("currentStateId", "CUSTOMER", "unique current semantic state id when matched")
  self~registerStateVariable("previousKnownStateId", "CUSTOMER", "previous distinct uniquely matched state id")
  self~registerStateVariable("transitionCount", "CUSTOMER", "count of distinct unique known-state changes observed")
  self~registerStateVariable("lastKnownStateId", "INTERNAL", "most recent uniquely matched state used for transition tracking")
  self~registerMethodContract("OBSERVE", "interpret one committed detached terminal snapshot", .array~of("SNAPSHOT"), "TERMINALKNOWNSTATETRACKER", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("CURRENT", "return latest detached semantic observation", .array~new, "ANY", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")

::method observe
  expose catalog history capacity currentGeneration currentStatus currentStateId previousKnownStateId transitionCount lastKnownStateId
  use arg snapshot
  if snapshot == .nil then return self
  generation = snapshot~generation

  /* Watchers can be attached after a terminal already has history, and callers
   * may redundantly publish a generation.  Never let an older snapshot rewind
   * the semantic present. */
  if generation < currentGeneration then return self
  if generation == currentGeneration & history~items > 0 then return self

  matched = catalog~match(snapshot)
  candidateIds = .array~new
  do candidate over matched~candidates
    candidateIds~append(candidate~stateId)
  end
  nextStateId = matched~matchedStateId

  if matched~status == .TerminalMatchStatus~MATCH then do
    if lastKnownStateId \== "" then do
      if nextStateId \== lastKnownStateId then do
        previousKnownStateId = lastKnownStateId
        transitionCount += 1
      end
    end
    lastKnownStateId = nextStateId
  end

  currentGeneration = generation
  currentStatus = matched~status
  currentStateId = nextStateId
  observation = .TerminalKnownStateObservation~new(generation, currentStatus, currentStateId, candidateIds)
  history~append(observation)
  do while history~items > capacity
    history~remove(1)
  end
  self~alchemyTouch("KNOWN_STATE_OBSERVE")
  ignore = self~terminalObservationEvent(generation, "KNOWN_STATE:" || currentStatus || ":" || currentStateId)
  return self

::method current
  expose history
  if history~items == 0 then return .nil
  return history[history~items]~copyDetached

::method back
  expose history
  use arg count = 1
  index = history~items - count
  if index < 1 | index > history~items then return .nil
  return history[index]~copyDetached

::method history
  expose history
  out = .array~new
  do item over history
    out~append(item~copyDetached)
  end
  return out

::class KnownStateCatalog subclass TerminalAlchemyObject public
::method init
  expose states
  use arg sealerArg = .nil, alchemyAuthorityArg = .nil
  self~initTerminalAlchemy("Semantic known-terminal-state catalogue", .nil, sealerArg, alchemyAuthorityArg)
  states = .table~new
  self~registerMethodContract("REGISTER", "register semantic terminal state", .array~of("KNOWN_STATE"), "TERMINALRESULT", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("MATCH", "match detached snapshot against semantic states", .array~of("SNAPSHOT"), "KNOWNSTATEMATCHRESULT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")

::method register
  expose states
  use arg knownState
  id = knownState~stateId
  if states~at(id) \== .nil then return .TerminalResult~failure("STATE_EXISTS", id)
  states~put(knownState, id)
  return .TerminalResult~success(knownState)

::method state
  expose states
  use arg stateId
  return states~at(stateId~string)

::method states
  expose states
  statesOut = .array~new
  do id over states
    statesOut~append(states[id])
  end
  return statesOut

::method match
  expose states
  use arg snapshot
  matched = .array~new
  do id over states
    candidate = states[id]~match(snapshot)
    if candidate~matched then matched~append(candidate)
  end
  select
    when matched~items == 0 then status = .TerminalMatchStatus~NO_MATCH
    when matched~items == 1 then status = .TerminalMatchStatus~MATCH
    otherwise status = .TerminalMatchStatus~AMBIGUOUS
  end
  return .KnownStateMatchResult~new(status, matched)

::method freezeAsKnownState
  use arg frozenState, stateId, name, description = "", createdBy = ""
  known = .KnownTerminalState~new(stateId, name, description, createdBy)
  known~addExemplar(frozenState)
  return known

/*
 * Generic session: concrete models must implement snapshot() and actions.
 * Watchers are one-way sinks.  They are never passed to the model.
 */
::class TerminalSession subclass TerminalAlchemyObject public
::attribute sessionId get
::attribute trace get
::attribute lastAgentObservedGeneration get

::method init
  expose sessionId model trace watchers lastAgentObservedGeneration
  use arg sessionIdArg, modelArg, traceArg = .nil, sealerArg = .nil, alchemyAuthorityArg = .nil
  sessionId = sessionIdArg~string
  meta = .directory~new
  meta["session_id"] = sessionId
  self~initTerminalAlchemy("Generic terminal session coordinator", meta, sealerArg, alchemyAuthorityArg)
  model = modelArg
  if traceArg == .nil then trace = .TerminalTrace~new(sealerArg, alchemyAuthorityArg)
  else trace = traceArg
  watchers = .array~new
  lastAgentObservedGeneration = 0
  self~registerStateVariable("sessionId", "CUSTOMER", "terminal session identity")
  self~registerStateVariable("lastAgentObservedGeneration", "CUSTOMER", "generation last handed to an agent")
  self~registerMethodContract("ADDWATCHER", "attach read-only watcher", .array~of("WATCHER"), "TERMINALSESSION", .false, "AUTO", "INTERNAL", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("COMMIT", "publish current model snapshot", .array~new, "TERMINALSNAPSHOT", .false, "AUTO", "CUSTOMER", "NORMAL", "MUTATE", "NONE")
  self~registerMethodContract("OBSERVEFORAGENT", "return detached current snapshot and record generation", .array~new, "TERMINALSNAPSHOT", .false, "AUTO", "CUSTOMER", "NORMAL", "READ", "NONE")

::method addWatcher
  expose watchers
  use arg watcher
  watchers~append(watcher)
  return self

::method commit
  expose model trace watchers
  snapshot = model~snapshot
  trace~appendSnapshot(snapshot)
  do watcher over watchers
    watcher~observe(snapshot)
  end
  self~alchemyTouch("COMMIT")
  ignore = self~terminalObservationEvent(snapshot~generation, "SESSION_COMMIT")
  return snapshot~copyDetached

::method observeForAgent
  expose model lastAgentObservedGeneration
  snapshot = model~snapshot
  lastAgentObservedGeneration = snapshot~generation
  self~alchemyTouch("OBSERVE_FOR_AGENT")
  ignore = self~terminalObservationEvent(snapshot~generation, "AGENT_OBSERVE")
  return snapshot~copyDetached

::method noteAction
  expose trace
  use arg action
  trace~appendAction(action)
  return self

::requires "TerminalAlchemy.cls"

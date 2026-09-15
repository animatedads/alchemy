/*
 * IBM 5250 personality v0.6 above the generic terminal core.
 *
 * The personality establishes the presentation-space, field/MDT, AID and agent action
 * contracts.  Telnet/TN5250E wire negotiation and raw datastream orders are
 * deliberately separate codecs and will not be allowed to leak into the core.
 */

::class Terminal5250Build public
::constant PRODUCT "ooRexx 5250 Terminal Personality"
::constant RELEASE "0.6"
::constant API_VERSION "terminal.5250/0.6"

::class AID5250 public
::constant ENTER "F1"x
::constant HELP "F3"x
::constant ROLL_DOWN "F4"x
::constant ROLL_UP "F5"x
::constant ROLL_LEFT "09"x
::constant ROLL_RIGHT "DA"x
::constant PA1 "6C"x
::constant PA2 "6E"x
::constant PA3 "6B"x
::constant CLEAR "BD"x
::constant PRINT "F6"x
::constant RECORD_BACKSPACE "F8"x
::constant F1 "31"x
::constant F2 "32"x
::constant F3 "33"x
::constant F4 "34"x
::constant F5 "35"x
::constant F6 "36"x
::constant F7 "37"x
::constant F8 "38"x
::constant F9 "39"x
::constant F10 "3A"x
::constant F11 "3B"x
::constant F12 "3C"x
::constant F13 "B1"x
::constant F14 "B2"x
::constant F15 "B3"x
::constant F16 "B4"x
::constant F17 "B5"x
::constant F18 "B6"x
::constant F19 "B7"x
::constant F20 "B8"x
::constant F21 "B9"x
::constant F22 "BA"x
::constant F23 "BB"x
::constant F24 "BC"x

::method fromName class
  use arg nameArg
  name = nameArg~string~strip~upper
  select
    when name == "ENTER" then return self~ENTER
    when name == "HELP" then return self~HELP
    when name == "PAGEDOWN" | name == "ROLLDOWN" then return self~ROLL_DOWN
    when name == "PAGEUP" | name == "ROLLUP" then return self~ROLL_UP
    when name == "ROLLLEFT" then return self~ROLL_LEFT
    when name == "ROLLRIGHT" then return self~ROLL_RIGHT
    when name == "PA1" then return self~PA1
    when name == "PA2" then return self~PA2
    when name == "PA3" then return self~PA3
    when name == "CLEAR" then return self~CLEAR
    when name == "PRINT" then return self~PRINT
    when name == "F1" then return self~F1
    when name == "F2" then return self~F2
    when name == "F3" then return self~F3
    when name == "F4" then return self~F4
    when name == "F5" then return self~F5
    when name == "F6" then return self~F6
    when name == "F7" then return self~F7
    when name == "F8" then return self~F8
    when name == "F9" then return self~F9
    when name == "F10" then return self~F10
    when name == "F11" then return self~F11
    when name == "F12" then return self~F12
    when name == "F13" then return self~F13
    when name == "F14" then return self~F14
    when name == "F15" then return self~F15
    when name == "F16" then return self~F16
    when name == "F17" then return self~F17
    when name == "F18" then return self~F18
    when name == "F19" then return self~F19
    when name == "F20" then return self~F20
    when name == "F21" then return self~F21
    when name == "F22" then return self~F22
    when name == "F23" then return self~F23
    when name == "F24" then return self~F24
    otherwise return .nil
  end

::class PresentationSpace5250 subclass FieldTerminalModel public
::attribute homeRow get
::attribute homeColumn get
::attribute messageWaiting get
::attribute cursorBlink get
::attribute lastAlarm get
::attribute pendingReadKind get
::attribute pendingAidName get
::attribute pendingControlSignal get

::method init
  expose pendingReadModified pendingReadKind pendingAidName pendingControlSignal homeRow homeColumn messageWaiting cursorBlink lastAlarm
  caps = .TerminalCapabilities~new
  caps~add("CHARACTER_GRID")
  caps~add("CURSOR_ADDRESSING")
  caps~add("PROTECTED_FIELDS")
  caps~add("INPUT_FIELDS")
  caps~add("FIELD_ATTRIBUTES")
  caps~add("AID_KEYS")
  caps~add("FUNCTION_KEYS")
  caps~add("READ_MODIFIED")
  caps~add("WTD_BASE_ORDERS")
  caps~add("QUERY_REPLY")
  caps~add("SYSTEM_REQUEST")
  caps~add("READ_MODIFIED_IMMEDIATE_ALT")
  caps~add("ERROR_RESET")
  caps~add("OPERATOR_ERROR_STATE")
  caps~add("CURSOR_TEXT_INPUT")
  caps~add("FIELD_NAVIGATION")
  self~init:super("IBM5250", 24, 80, caps)
  self~setMetadata("family", "IBM_5250")
  self~setMetadata("manual", "IBM SC30-3533-04")
  pendingReadModified = .nil
  pendingReadKind = ""
  pendingAidName = ""
  pendingControlSignal = ""
  self~setMetadata("pendingRead", "")
  self~setMetadata("pendingAid", "")
  self~setMetadata("pendingControlSignal", "")
  self~setMetadata("operatorState", "")
  self~setMetadata("operatorErrorCode", "")
  self~setMetadata("operatorErrorKind", "")
  self~setMetadata("operatorErrorMessage", "")
  self~setMetadata("operatorErrorOrigin", "")
  self~setMetadata("operatorErrorCursorRow", 0)
  self~setMetadata("operatorErrorCursorColumn", 0)
  self~setMetadata("operatorRecoverable", 0)
  self~setMetadata("operatorRecovery", "")
  self~setMetadata("operatorPreviousKeyboardState", "")
  self~setMetadata("operatorPreviousSessionState", "")
  self~setMetadata("operatorPreviousCursorBlink", 0)
  self~setMetadata("errorRow", 24)
  self~setMetadata("systemICDefined", 0)
  homeRow = 1
  homeColumn = 1
  messageWaiting = .false
  cursorBlink = .false
  lastAlarm = .false

::method setHome
  expose homeRow homeColumn
  use arg rowArg, columnArg
  if self~linearPosition(rowArg, columnArg) = 0 then return .TerminalResult~failure("CURSOR_RANGE", "home outside presentation space")
  homeRow = rowArg
  homeColumn = columnArg
  self~setMetadata("systemICDefined", 1)
  return .TerminalResult~success

::method clearHome
  expose homeRow homeColumn
  homeRow = 1
  homeColumn = 1
  self~setMetadata("systemICDefined", 0)
  return self

::method setIndicators
  expose messageWaiting cursorBlink lastAlarm
  use arg messageWaitingArg = .nil, cursorBlinkArg = .nil, alarmArg = .nil
  if messageWaitingArg \== .nil then messageWaiting = messageWaitingArg == .true
  if cursorBlinkArg \== .nil then cursorBlink = cursorBlinkArg == .true
  if alarmArg \== .nil then lastAlarm = alarmArg == .true
  self~setMetadata("messageWaiting", messageWaiting)
  self~setMetadata("cursorBlink", cursorBlink)
  self~setMetadata("alarm", lastAlarm)
  return self

::method setPendingRead
  expose pendingReadKind pendingAidName pendingReadModified
  use arg kindArg, controlBytes = "0000"x
  kind = kindArg~string~strip~upper
  if kind \= "READ_INPUT" & kind \= "READ_MDT" & kind \= "READ_MDT_ALT" then return .TerminalResult~failure("READ_KIND", kind)
  if controlBytes~length \= 2 then return .TerminalResult~failure("READ_CONTROL", controlBytes~c2x)
  pendingReadKind = kind
  self~setMetadata("pendingRead", kind)
  self~setMetadata("pendingReadControl", controlBytes~c2x)

  /* IBM 5494 keyboard semantics permit an AID to predate the READ command.
   * If an AID is already pending, the arriving READ services it now. */
  if pendingAidName \= "" then do
    built = self~buildReadModified(pendingAidName)
    if \built~ok then return built
    built~value~readKind = pendingReadKind
    pendingReadModified = built~value
    pendingAidName = ""
    self~setMetadata("pendingAid", "")
  end
  return .TerminalResult~success

::method clearPendingRead
  expose pendingReadKind
  pendingReadKind = ""
  self~setMetadata("pendingRead", "")
  self~setMetadata("pendingReadControl", "")
  return self

::method clearPendingAID
  expose pendingReadModified pendingAidName
  pendingReadModified = .nil
  pendingAidName = ""
  self~setMetadata("pendingAid", "")
  return self

/* RFC 1205 terminal-control signals are not AID bytes.  Keep them on a
 * separate path so SYSREQ/ATTN/TRQ can never be mistaken for ordinary field
 * input. */
::method queueControlSignal
  expose pendingControlSignal
  use arg signalArg
  name = signalArg~string~strip~upper
  if name \= "SYSTEM_REQUEST" & name \= "ATTENTION" & name \= "TEST_REQUEST" then,
    return .TerminalResult~failure("5250_CONTROL_SIGNAL_UNKNOWN", name)
  if pendingControlSignal \= "" then return .TerminalResult~failure("5250_CONTROL_SIGNAL_PENDING", pendingControlSignal)
  pendingControlSignal = name
  self~setMetadata("pendingControlSignal", name)
  return .TerminalResult~success(name)

::method peekPendingControlSignal
  expose pendingControlSignal
  return pendingControlSignal

::method takePendingControlSignal
  expose pendingControlSignal
  value = pendingControlSignal
  pendingControlSignal = ""
  self~setMetadata("pendingControlSignal", "")
  return value

/* Build an immediate modified-field response.  RFC 1205 specifies AID x'00'
 * for READ MODIFIED IMMEDIATE ALTERNATE.  This is a trusted wire object and
 * may therefore contain nondisplay field values. */
::method buildImmediateModifiedAlternate
  fields = self~modifiedFieldsForWire
  response = .ReadModified5250~new(self~generation, "IMMEDIATE", "00"x, self~cursorRow, self~cursorColumn, fields)
  response~readKind = "READ_MDT_IMMEDIATE_ALT"
  return response

::method operatorErrorActive
  meta = self~metadata
  return .TerminalUtil~safeString(meta["operatorState"])~strip \= ""

::method enterOperatorError
  use arg codeArg, kindArg, messageArg = "", originArg = "LOCAL_KEYING"
  meta = self~metadata
  if .TerminalUtil~safeString(meta["operatorState"])~strip == "" then do
    self~setMetadata("operatorPreviousKeyboardState", self~keyboardState)
    self~setMetadata("operatorPreviousSessionState", self~sessionState)
    self~setMetadata("operatorPreviousCursorBlink", self~cursorBlink)
  end
  self~setMetadata("operatorState", "PRE_HELP_ERROR")
  self~setMetadata("operatorErrorCode", codeArg~string)
  self~setMetadata("operatorErrorKind", kindArg~string~strip~upper)
  self~setMetadata("operatorErrorMessage", messageArg~string)
  self~setMetadata("operatorErrorOrigin", originArg~string~strip~upper)
  self~setMetadata("operatorErrorCursorRow", self~cursorRow)
  self~setMetadata("operatorErrorCursorColumn", self~cursorColumn)
  self~setMetadata("operatorRecoverable", 1)
  self~setMetadata("operatorRecovery", "ERROR_RESET")
  self~setKeyboardState("LOCKED")
  self~setIndicators(.nil, .true, .nil)
  return .TerminalResult~success(self~snapshot~operatorCondition)

::method clearOperatorError
  meta = self~metadata
  if .TerminalUtil~safeString(meta["operatorState"])~strip == "" then return .TerminalResult~failure("5250_NO_OPERATOR_ERROR", "no operator error is active")
  previousKeyboard = .TerminalUtil~safeString(meta["operatorPreviousKeyboardState"])
  previousSession = .TerminalUtil~safeString(meta["operatorPreviousSessionState"])
  previousBlink = meta["operatorPreviousCursorBlink"] == 1 | meta["operatorPreviousCursorBlink"] == .true
  if previousKeyboard == "" then previousKeyboard = "UNLOCKED"
  if previousSession == "" then previousSession = .TerminalStatus~OPERATOR_WAIT
  self~setKeyboardState(previousKeyboard)
  self~setSessionState(previousSession)
  self~setIndicators(.nil, previousBlink, .nil)
  self~setMetadata("operatorState", "")
  self~setMetadata("operatorErrorCode", "")
  self~setMetadata("operatorErrorKind", "")
  self~setMetadata("operatorErrorMessage", "")
  self~setMetadata("operatorErrorOrigin", "")
  self~setMetadata("operatorErrorCursorRow", 0)
  self~setMetadata("operatorErrorCursorColumn", 0)
  self~setMetadata("operatorRecoverable", 0)
  self~setMetadata("operatorRecovery", "")
  self~setMetadata("operatorPreviousKeyboardState", "")
  self~setMetadata("operatorPreviousSessionState", "")
  self~setMetadata("operatorPreviousCursorBlink", 0)
  return .TerminalResult~success(self~snapshot)

::method requireOperatorInputReady
  if self~operatorErrorActive then return .TerminalResult~failure("5250_OPERATOR_ERROR_ACTIVE", "Error Reset is required")
  if self~keyboardState \= "UNLOCKED" then return .TerminalResult~failure("KEYBOARD_LOCKED", self~keyboardState)
  return .TerminalResult~success

::method focusInputField
  use arg fieldIdArg
  ready = self~requireOperatorInputReady
  if \ready~ok then return ready
  f = self~field(fieldIdArg)
  if f == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", fieldIdArg)
  if \f~inputCapable | f~protected then return .TerminalResult~failure("FIELD_PROTECTED", fieldIdArg)
  moved = self~setCursor(f~row, f~column)
  if \moved~ok then return moved
  return .TerminalResult~success(self~snapshot)

::method nextInputField
  ready = self~requireOperatorInputReady
  if \ready~ok then return ready
  f = self~nextInputField:super(self~cursorRow, self~cursorColumn)
  if f == .nil then return .TerminalResult~failure("NO_INPUT_FIELDS", "presentation space has no input field")
  self~setCursor(f~row, f~column)
  return .TerminalResult~success(self~snapshot)

::method previousInputField
  ready = self~requireOperatorInputReady
  if \ready~ok then return ready
  f = self~previousInputField:super(self~cursorRow, self~cursorColumn)
  if f == .nil then return .TerminalResult~failure("NO_INPUT_FIELDS", "presentation space has no input field")
  self~setCursor(f~row, f~column)
  return .TerminalResult~success(self~snapshot)

::method homeCursor
  expose homeRow homeColumn
  ready = self~requireOperatorInputReady
  if \ready~ok then return ready
  meta = self~metadata
  if meta["systemICDefined"] == 1 | meta["systemICDefined"] == .true then do
    targetRow = homeRow
    targetColumn = homeColumn
  end
  else do
    first = self~firstInputField
    if first == .nil then do
      targetRow = 1
      targetColumn = 1
    end
    else do
      targetRow = first~row
      targetColumn = first~column
    end
  end
  if self~cursorRow = targetRow & self~cursorColumn = targetColumn then return .TerminalResult~failure("5250_HOME_RECORD_BACKSPACE_NOT_IMPLEMENTED", "Home at home position is Record Backspace")
  moved = self~setCursor(targetRow, targetColumn)
  if \moved~ok then return moved
  return .TerminalResult~success(self~snapshot)

::method typeAtCursor
  use arg textArg
  ready = self~requireOperatorInputReady
  if \ready~ok then return ready
  text = textArg~string
  if text~length = 0 then return .TerminalResult~success(self~snapshot)
  do i = 1 to text~length
    f = self~fieldAtMutable(self~cursorRow, self~cursorColumn)
    if f == .nil then do
      entered = self~enterOperatorError("0005", "PROTECTED_AREA", "Cursor is not in an input-capable field.", "LOCAL_KEYING")
      return .TerminalResult~failure("5250_OPERATOR_ERROR_0005", "cursor in protected area of display")
    end
    if \f~inputCapable | f~protected then do
      entered = self~enterOperatorError("0005", "PROTECTED_AREA", "Cursor is not in an input-capable field.", "LOCAL_KEYING")
      return .TerminalResult~failure("5250_OPERATOR_ERROR_0005", "cursor in protected area of display")
    end
    if f~attribute("autoEnter") == 1 | f~attribute("autoEnter") == .true then return .TerminalResult~failure("5250_AUTO_ENTER_TEXT_NOT_IMPLEMENTED", f~fieldId)
    startPos = self~linearPosition(f~row, f~column)
    here = self~cursorLinearPosition
    offset = here - startPos + 1
    written = self~operatorWriteCharacter(self~cursorRow, self~cursorColumn, text~substr(i,1))
    if \written~ok then return written
    if offset < f~length then self~setCursorLinear(here + 1)
    else do
      fer = f~attribute("fieldExitRequired") == 1 | f~attribute("fieldExitRequired") == .true
      if \fer then do
        next = self~nextInputField:super(f~row, f~column)
        if next \== .nil then self~setCursor(next~row, next~column)
      end
    end
  end
  return .TerminalResult~success(self~snapshot)

::method refreshFingerprints
  /* Snapshot fingerprints are safe-view fingerprints.  Nondisplay field values
   * are deliberately excluded, so this method can run before WatchAlong/replay. */
  contentText = ""
  snap = self~snapshot:super
  do line over snap~textRows
    contentText ||= line || "0A"x
  end
  layoutText = self~rows || "x" || self~columns || "|" || self~keyboardState || "|"
  do f over self~fieldsForDriver
    layoutText ||= f~fieldId || ":" || f~row || ":" || f~column || ":" || f~length || ":" ||,
                  f~inputCapable || ":" || f~protected || ":" || f~nonDisplay || ";"
  end
  self~setFingerprints(.TerminalUtil~stableDigest(contentText), .TerminalUtil~stableDigest(layoutText))
  return self

::method hostCommit
  self~refreshFingerprints
  self~advanceGeneration
  return self~snapshot

::method setInputField
  use arg fieldId, valueArg
  return self~setFieldValue(fieldId, valueArg)

::method buildReadModified
  expose pendingReadKind
  use arg aidName
  aidByte = .AID5250~fromName(aidName)
  if aidByte == .nil then return .TerminalResult~failure("AID_UNKNOWN", aidName)
  if pendingReadKind = "READ_INPUT" then do
    fields = .array~new
    do f over self~fieldsForDriver
      fields~append(f~wireSnapshot)
    end
  end
  else fields = self~modifiedFieldsForWire
  return .TerminalResult~success(.ReadModified5250~new(self~generation, aidName, aidByte, self~cursorRow, self~cursorColumn, fields))

::method queueReadModified
  expose pendingReadModified pendingReadKind pendingAidName
  use arg aidName
  if self~keyboardState = "LOCKED" then return .TerminalResult~failure("KEYBOARD_LOCKED", "AID not accepted while keyboard is locked")
  aidByte = .AID5250~fromName(aidName)
  if aidByte == .nil then return .TerminalResult~failure("AID_UNKNOWN", aidName)
  normalizedAid = aidName~string~strip~upper

  if pendingReadKind \= "" then do
    built = self~buildReadModified(normalizedAid)
    if \built~ok then return built
    built~value~readKind = pendingReadKind
    pendingReadModified = built~value
    pendingAidName = ""
    self~setMetadata("pendingAid", "")
  end
  else do
    pendingAidName = normalizedAid
    self~setMetadata("pendingAid", pendingAidName)
  end

  ids = .array~new
  do field over self~modifiedFields
    ids~append(field~fieldId)
  end
  return .TerminalResult~success(.AIDReceipt5250~new(self~generation, normalizedAid, ids))

::method peekPendingReadModified
  expose pendingReadModified
  return pendingReadModified

::method takePendingReadModified
  expose pendingReadModified
  pending = pendingReadModified
  pendingReadModified = .nil
  if pending \== .nil then self~clearPendingRead
  return pending

/* Trusted SAVE/RESTORE support.  This object contains nondisplay field values
 * and must never cross the automation/WatchAlong boundary. */
::method capturePrivateState
  expose homeRow homeColumn messageWaiting cursorBlink lastAlarm pendingReadKind pendingAidName pendingReadModified pendingControlSignal
  safe = self~snapshot
  wireFields = .array~new
  do f over self~fieldsForDriver
    wireFields~append(f~wireSnapshot)
  end
  readControl = ""
  meta = self~metadata
  if meta["pendingReadControl"] \== .nil then readControl = meta["pendingReadControl"]~string
  operatorMeta = .directory~new
  do key over meta
    if key~string~startsWith("operator") | key~string == "errorRow" | key~string == "systemICDefined" then operatorMeta[key] = meta[key]
  end
  return .PrivatePresentationState5250~new(safe~textRows, wireFields, self~cursorRow, self~cursorColumn, homeRow, homeColumn, self~keyboardState, self~sessionState, messageWaiting, cursorBlink, lastAlarm, pendingReadKind, readControl, pendingAidName, pendingReadModified, pendingControlSignal, operatorMeta)

::method restorePrivateState
  expose pendingReadModified pendingReadKind pendingAidName pendingControlSignal homeRow homeColumn messageWaiting cursorBlink lastAlarm
  use arg stateArg
  if stateArg == .nil then return .TerminalResult~failure("5250_RESTORE_STATE", "invalid private state")
  if \stateArg~isA(.PrivatePresentationState5250) then return .TerminalResult~failure("5250_RESTORE_STATE", "invalid private state")
  self~clear
  self~clearFormatTable
  rowsIn = stateArg~textRows
  do r = 1 to rowsIn~items
    self~writeText(r, 1, rowsIn[r])
  end
  do f over stateArg~fields
    restored = self~defineOrReplaceField(f~fieldId, f~row, f~column, f~length, f~value, f~inputCapable, f~protected, f~nonDisplay, f~numeric, f~attributes, f~modified)
    if \restored~ok then return restored
  end
  self~setCursor(stateArg~cursorRow, stateArg~cursorColumn)
  homeRow = stateArg~homeRow; homeColumn = stateArg~homeColumn
  self~setKeyboardState(stateArg~keyboardState)
  self~setSessionState(stateArg~sessionState)
  messageWaiting = stateArg~messageWaiting; cursorBlink = stateArg~cursorBlink; lastAlarm = stateArg~lastAlarm
  pendingReadKind = stateArg~pendingReadKind
  pendingAidName = stateArg~pendingAidName
  if stateArg~pendingReadModified == .nil then pendingReadModified = .nil
  else pendingReadModified = stateArg~pendingReadModified~copyDetached
  pendingControlSignal = stateArg~pendingControlSignal
  self~setMetadata("pendingRead", pendingReadKind)
  self~setMetadata("pendingReadControl", stateArg~pendingReadControl)
  self~setMetadata("pendingAid", pendingAidName)
  self~setMetadata("pendingControlSignal", pendingControlSignal)
  self~setIndicators(messageWaiting, cursorBlink, lastAlarm)
  operatorMeta = stateArg~operatorMetadata
  if operatorMeta \== .nil then do key over operatorMeta
    self~setMetadata(key, operatorMeta[key])
  end
  return .TerminalResult~success

::class AIDReceipt5250 public
::attribute generation get
::attribute aidName get
::attribute modifiedFieldIds get
::method init
  expose generation aidName modifiedFieldIds
  use arg generationArg, aidNameArg, idsArg
  generation = generationArg
  aidName = aidNameArg~string~upper
  modifiedFieldIds = .TerminalUtil~copyArray(idsArg)

::class ReadModified5250 public
::attribute readKind
::attribute generation get
::attribute aidName get
::attribute aidByte get
::attribute cursorRow get
::attribute cursorColumn get
::attribute fields get

::method init
  expose readKind generation aidName aidByte cursorRow cursorColumn fields
  use arg generationArg, aidNameArg, aidByteArg, cursorRowArg, cursorColumnArg, fieldsArg
  readKind = "READ_MDT"
  generation = generationArg
  aidName = aidNameArg~string~upper
  aidByte = aidByteArg
  cursorRow = cursorRowArg
  cursorColumn = cursorColumnArg
  fields = .TerminalUtil~cloneFieldArray(fieldsArg)

::method copyDetached
  expose readKind generation aidName aidByte cursorRow cursorColumn fields
  copy = .ReadModified5250~new(generation, aidName, aidByte, cursorRow, cursorColumn, fields)
  copy~readKind = readKind
  return copy

::class PrivatePresentationState5250 public
::attribute textRows get
::attribute fields get
::attribute cursorRow get
::attribute cursorColumn get
::attribute homeRow get
::attribute homeColumn get
::attribute keyboardState get
::attribute sessionState get
::attribute messageWaiting get
::attribute cursorBlink get
::attribute lastAlarm get
::attribute pendingReadKind get
::attribute pendingReadControl get
::attribute pendingAidName get
::attribute pendingReadModified get
::attribute pendingControlSignal get
::attribute operatorMetadata get

::method init
  expose textRows fields cursorRow cursorColumn homeRow homeColumn keyboardState sessionState messageWaiting cursorBlink lastAlarm pendingReadKind pendingReadControl pendingAidName pendingReadModified pendingControlSignal operatorMetadata
  use arg textRowsArg, fieldsArg, cursorRowArg, cursorColumnArg, homeRowArg, homeColumnArg, keyboardArg, sessionArg, messageArg, blinkArg, alarmArg, readKindArg, readControlArg, aidArg, pendingReadArg, controlSignalArg, operatorMetadataArg = .nil
  textRows = .TerminalUtil~copyArray(textRowsArg)
  fields = .TerminalUtil~cloneFieldArray(fieldsArg)
  cursorRow = cursorRowArg; cursorColumn = cursorColumnArg
  homeRow = homeRowArg; homeColumn = homeColumnArg
  keyboardState = keyboardArg~string; sessionState = sessionArg~string
  messageWaiting = messageArg == .true; cursorBlink = blinkArg == .true; lastAlarm = alarmArg == .true
  pendingReadKind = readKindArg~string
  pendingReadControl = readControlArg
  pendingAidName = aidArg~string
  if pendingReadArg == .nil then pendingReadModified = .nil
  else pendingReadModified = pendingReadArg~copyDetached
  pendingControlSignal = controlSignalArg~string
  operatorMetadata = .TerminalUtil~copyDirectory(operatorMetadataArg)

::class Terminal5250AgentPort public
::method init
  expose session model
  use arg sessionArg, modelArg
  session = sessionArg
  model = modelArg
  if model~terminalType \== "IBM5250" then raise syntax 88.900 array("Terminal5250AgentPort requires IBM5250 model")

::method snapshot
  expose session
  return session~observeForAgent

::method setField
  expose session model
  use arg generationArg, fieldId, valueArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  ready = model~requireOperatorInputReady
  if \ready~ok then return ready
  outcome = model~setInputField(fieldId, valueArg)
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "FIELD_INPUT", fieldId, "<VALUE>", actor))
  return outcome

/* Trusted credential path.  This is deliberately not surfaced by
 * TN5250AutomationSession.  Secrets may only be staged into a field that the
 * host itself marked NONDISPLAY. */
::method setCredentialField
  expose session model
  use arg generationArg, fieldId, valueArg, secretArg = .false, actor = "CREDENTIAL_BROKER"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  f = model~field(fieldId)
  if f == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", fieldId)
  if secretArg == .true & \f~nonDisplay then return .TerminalResult~failure("SECRET_FIELD_NOT_NONDISPLAY", fieldId)
  if secretArg \== .true & f~nonDisplay then return .TerminalResult~failure("CREDENTIAL_USER_FIELD_NONDISPLAY", fieldId)
  outcome = model~setInputField(fieldId, valueArg)
  if outcome~ok then do
    if secretArg == .true then safeValue = "<SECRET>"
    else safeValue = "<CREDENTIAL_USER>"
    session~noteAction(.TerminalAction~new(generationArg, "CREDENTIAL_FIELD_INPUT", fieldId, safeValue, actor))
  end
  return outcome

/* Trusted pair staging is transactional at the presentation-space level. */
::method stageCredentialPair
  expose session model
  use arg generationArg, userFieldIdArg, userValueArg, passwordFieldIdArg, passwordValueArg, actor = "CREDENTIAL_BROKER"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  uf = model~field(userFieldIdArg)
  pf = model~field(passwordFieldIdArg)
  if uf == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", userFieldIdArg)
  if pf == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", passwordFieldIdArg)
  if \uf~inputCapable | uf~protected | uf~nonDisplay then return .TerminalResult~failure("CREDENTIAL_USER_FIELD_INVALID", userFieldIdArg)
  if \pf~inputCapable | pf~protected | \pf~nonDisplay then return .TerminalResult~failure("CREDENTIAL_PASSWORD_FIELD_INVALID", passwordFieldIdArg)
  if userValueArg~string~length > uf~length then return .TerminalResult~failure("CREDENTIAL_USER_OVERFLOW", userFieldIdArg)
  if passwordValueArg~string~length > pf~length then return .TerminalResult~failure("CREDENTIAL_PASSWORD_OVERFLOW", passwordFieldIdArg)

  before = model~capturePrivateState
  u = model~setInputField(userFieldIdArg, userValueArg)
  if \u~ok then return u
  p = model~setInputField(passwordFieldIdArg, passwordValueArg)
  if \p~ok then do
    ignore = model~restorePrivateState(before)
    return p
  end
  session~noteAction(.TerminalAction~new(generationArg, "CREDENTIAL_FIELD_INPUT", userFieldIdArg, "<CREDENTIAL_USER>", actor))
  session~noteAction(.TerminalAction~new(generationArg, "CREDENTIAL_FIELD_INPUT", passwordFieldIdArg, "<SECRET>", actor))
  return .TerminalResult~success(model~snapshot)

/* Trusted transactional staging for password-change style panels.  This is
 * deliberately absent from the AI-facing automation session.  All three host
 * fields must be input-capable NONDISPLAY fields. */
::method stageNondisplaySecretTriple
  expose session model
  use arg generationArg, firstFieldIdArg, firstValueArg, secondFieldIdArg, secondValueArg, thirdFieldIdArg, thirdValueArg, actor = "CREDENTIAL_BROKER"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)

  f1 = model~field(firstFieldIdArg)
  f2 = model~field(secondFieldIdArg)
  f3 = model~field(thirdFieldIdArg)
  if f1 == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", firstFieldIdArg)
  if f2 == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", secondFieldIdArg)
  if f3 == .nil then return .TerminalResult~failure("FIELD_NOT_FOUND", thirdFieldIdArg)

  do f over .array~of(f1, f2, f3)
    if \f~inputCapable then return .TerminalResult~failure("SECRET_FIELD_INVALID", f~fieldId)
    if f~protected then return .TerminalResult~failure("SECRET_FIELD_INVALID", f~fieldId)
    if \f~nonDisplay then return .TerminalResult~failure("SECRET_FIELD_NOT_NONDISPLAY", f~fieldId)
  end
  if firstValueArg~string~length > f1~length then return .TerminalResult~failure("SECRET_FIELD_OVERFLOW", firstFieldIdArg)
  if secondValueArg~string~length > f2~length then return .TerminalResult~failure("SECRET_FIELD_OVERFLOW", secondFieldIdArg)
  if thirdValueArg~string~length > f3~length then return .TerminalResult~failure("SECRET_FIELD_OVERFLOW", thirdFieldIdArg)

  before = model~capturePrivateState
  a = model~setInputField(firstFieldIdArg, firstValueArg)
  if \a~ok then return a
  b = model~setInputField(secondFieldIdArg, secondValueArg)
  if \b~ok then do
    ignore = model~restorePrivateState(before)
    return b
  end
  c = model~setInputField(thirdFieldIdArg, thirdValueArg)
  if \c~ok then do
    ignore = model~restorePrivateState(before)
    return c
  end

  session~noteAction(.TerminalAction~new(generationArg, "SECRET_FIELD_INPUT", firstFieldIdArg, "<SECRET>", actor))
  session~noteAction(.TerminalAction~new(generationArg, "SECRET_FIELD_INPUT", secondFieldIdArg, "<SECRET>", actor))
  session~noteAction(.TerminalAction~new(generationArg, "SECRET_FIELD_INPUT", thirdFieldIdArg, "<SECRET>", actor))
  return .TerminalResult~success(model~snapshot)

::method moveCursor
  expose session model
  use arg generationArg, rowArg, columnArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  ready = model~requireOperatorInputReady
  if \ready~ok then return ready
  outcome = model~setCursor(rowArg, columnArg)
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "CURSOR", rowArg || "," || columnArg, "", actor))
  return outcome

::method focusField
  expose session model
  use arg generationArg, fieldIdArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~focusInputField(fieldIdArg)
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "FIELD_FOCUS", fieldIdArg, "", actor))
  return outcome

::method nextInputField
  expose session model
  use arg generationArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~nextInputField
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "FIELD_NAVIGATION", "NEXT", "", actor))
  return outcome

::method previousInputField
  expose session model
  use arg generationArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~previousInputField
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "FIELD_NAVIGATION", "PREVIOUS", "", actor))
  return outcome

::method home
  expose session model
  use arg generationArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~homeCursor
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "CURSOR_HOME", "HOME", "", actor))
  return outcome

::method typeAtCursor
  expose session model
  use arg generationArg, textArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  before = model~snapshot
  outcome = model~typeAtCursor(textArg)
  session~noteAction(.TerminalAction~new(generationArg, "CURSOR_TEXT_INPUT", "TYPE", "<TEXT>", actor))
  return outcome

::method errorReset
  expose session model
  use arg generationArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~clearOperatorError
  if outcome~ok then session~noteAction(.TerminalAction~new(generationArg, "ERROR_RESET", "RESET", "", actor))
  return outcome

::method press
  expose session model
  use arg generationArg, aidName, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~queueReadModified(aidName)
  if outcome~ok then do
    session~noteAction(.TerminalAction~new(generationArg, "AID", aidName~string~upper, "", actor))
    model~setKeyboardState("LOCKED")
    model~setSessionState(.TerminalStatus~HOST_WAIT)
  end
  return outcome

::method systemRequest
  expose session model
  use arg generationArg, actor = "AI"
  if generationArg \== model~generation then return .TerminalResult~failure("STALE_SCREEN", "expected generation " || generationArg || ", actual " || model~generation)
  outcome = model~queueControlSignal("SYSTEM_REQUEST")
  if outcome~ok then do
    session~noteAction(.TerminalAction~new(generationArg, "CONTROL_SIGNAL", "SYSTEM_REQUEST", "", actor))
    model~setKeyboardState("LOCKED")
    model~setSessionState(.TerminalStatus~HOST_WAIT)
  end
  return outcome

::requires "FieldTerminal.cls"

/*
 * KL10Console.cls -- safe host-side keyboard / console facade for the
 * bounded KL10 DTE20 monitor path.
 *
 * This object deliberately does not expose KL10CPU, KL10Dte, memory, or the
 * I/O bus.  Keyboard input is enqueued through the existing architectural
 * DTE20 RX path; machine progress still occurs only through KL10CPU~step().
 *
 * The facade therefore gives an AI/operator terminal-like operations without
 * inventing a command API inside the emulated machine.
 */

::class KL10ConsoleResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute stateToken get
::attribute queuedBytes get

::method init
  expose ok code detail stateToken queuedBytes
  use arg okArg, codeArg, detailArg = "", stateTokenArg = "", queuedBytesArg = 0
  ok = okArg == .true
  code = codeArg~string
  detail = detailArg~string
  stateToken = stateTokenArg~string
  queuedBytes = queuedBytesArg

::method success class
  use arg stateTokenArg = "", queuedBytesArg = 0
  return self~new(.true, "OK", "", stateTokenArg, queuedBytesArg)

::method failure class
  use arg codeArg, detailArg = "", stateTokenArg = "", queuedBytesArg = 0
  return self~new(.false, codeArg, detailArg, stateTokenArg, queuedBytesArg)


::class KL10ConsolePumpResult public
::attribute ok get
::attribute reason get
::attribute steps get
::attribute outputDeltaHex get
::attribute outputDeltaText get
::attribute conditionCode get
::attribute conditionMessage get
::attribute stateToken get
::attribute snapshot get

::method init
  expose ok reason steps outputDeltaHex outputDeltaText conditionCode conditionMessage stateToken snapshot
  use arg okArg, reasonArg, stepsArg, outputDeltaHexArg = "", outputDeltaTextArg = "", conditionCodeArg = "", conditionMessageArg = "", stateTokenArg = "", snapshotArg = .nil
  ok = okArg == .true
  reason = reasonArg~string
  steps = stepsArg
  outputDeltaHex = outputDeltaHexArg~string
  outputDeltaText = outputDeltaTextArg~string
  conditionCode = conditionCodeArg~string
  conditionMessage = conditionMessageArg~string
  stateToken = stateTokenArg~string
  if snapshotArg == .nil then snapshot = .nil
  else snapshot = snapshotArg~copyDetached


::class KL10ConsoleSnapshot public
::attribute generation get
::attribute stateToken get
::attribute terminalType get
::attribute keyboardState get
::attribute sessionState get
::attribute pc get
::attribute instructionCount get
::attribute monitorMode get
::attribute inputReady get
::attribute guestWaitingForInput get
::attribute queuedInputBytes get
::attribute outputBytes get
::attribute outputHex get
::attribute visibleText get
::attribute cursorRow get
::attribute cursorColumn get
::attribute bellCount get
::attribute rows get
::attribute columns get

::method init
  expose generation stateToken terminalType keyboardState sessionState pc instructionCount monitorMode inputReady guestWaitingForInput queuedInputBytes outputBytes outputHex visibleText cursorRow cursorColumn bellCount rows columns
  use arg generationArg, stateTokenArg, terminalTypeArg, keyboardStateArg, sessionStateArg, pcArg, instructionCountArg, monitorModeArg, inputReadyArg, guestWaitingArg, queuedInputBytesArg, outputBytesArg, outputHexArg, visibleTextArg, cursorRowArg, cursorColumnArg, bellCountArg, rowsArg, columnsArg
  generation = generationArg
  stateToken = stateTokenArg~string
  terminalType = terminalTypeArg~string
  keyboardState = keyboardStateArg~string
  sessionState = sessionStateArg~string
  pc = pcArg
  instructionCount = instructionCountArg
  monitorMode = monitorModeArg
  inputReady = inputReadyArg == .true
  guestWaitingForInput = guestWaitingArg == .true
  queuedInputBytes = queuedInputBytesArg
  outputBytes = outputBytesArg
  outputHex = outputHexArg~string
  visibleText = visibleTextArg~string
  cursorRow = cursorRowArg
  cursorColumn = cursorColumnArg
  bellCount = bellCountArg
  rows = rowsArg
  columns = columnsArg

::method capabilities
  caps = .array~new
  caps~append("CHARACTER_STREAM")
  caps~append("CHARACTER_INPUT")
  caps~append("CONTROL_KEYS")
  caps~append("SNAPSHOT")
  caps~append("STALE_ACTION_TOKEN")
  return caps

::method rowText
  expose visibleText rows
  use strict arg rowNumber
  if rowNumber < 1 | rowNumber > rows then return ""
  rest = visibleText
  current = 1
  do forever
    p = pos("0a"x, rest)
    if current = rowNumber then do
      if p = 0 then return rest
      return rest~left(p - 1)
    end
    if p = 0 then return ""
    rest = rest~substr(p + 1)
    current += 1
  end

::method copyDetached
  expose generation stateToken terminalType keyboardState sessionState pc instructionCount monitorMode inputReady guestWaitingForInput queuedInputBytes outputBytes outputHex visibleText cursorRow cursorColumn bellCount rows columns
  return .KL10ConsoleSnapshot~new(generation, stateToken, terminalType, keyboardState, sessionState, pc, instructionCount, monitorMode, inputReady, guestWaitingForInput, queuedInputBytes, outputBytes, outputHex, visibleText, cursorRow, cursorColumn, bellCount, rows, columns)

::method string
  expose generation terminalType keyboardState sessionState pc instructionCount queuedInputBytes outputBytes visibleText
  return terminalType || " generation=" || generation || " state=" || sessionState || -
         " keyboard=" || keyboardState || " pc=" || .LROct~fromDecimal(pc)~right || -
         " icount=" || instructionCount || " rx=" || queuedInputBytes || -
         " tx=" || outputBytes || "0a"x || visibleText


::class KL10ConsoleRenderer public

::method renderHex class
  use strict arg hexArg
  hexText = hexArg~string~space(0)~upper
  if hexText == "" then do
    out = .directory~new
    out["text"] = ""
    out["row"] = 1
    out["column"] = 1
    out["bellCount"] = 0
    out["rows"] = 1
    out["columns"] = 0
    return out
  end
  if hexText~length // 2 \= 0 | \datatype(hexText, "X") then
    raise syntax 40.900 array("KL10 console output is not an even hexadecimal byte string")

  lines = .array~new
  lines~append("")
  row = 1
  column = 1
  bells = 0

  do posn = 1 to hexText~length by 2
    code = x2d(hexText~substr(posn, 2))
    select
      when code = 13 then column = 1                         /* CR */
      when code = 10 then do                                 /* LF */
        row += 1
        lines~append("")
      end
      when code = 8 then do                                  /* BS */
        if column > 1 then column -= 1
      end
      when code = 9 then do                                  /* HT, 8-column stops */
        column = (((column - 1) % 8) + 1) * 8 + 1
      end
      when code = 7 then bells += 1                          /* BEL */
      when code >= 32 & code <= 126 then do
        line = lines[row]
        line = self~putAt(line, column, d2c(code))
        lines[row] = line
        column += 1
      end
      otherwise nop                                          /* preserve in raw hex */
    end
  end

  text = ""
  do i = 1 to lines~items
    if i > 1 then text ||= "0a"x
    text ||= lines[i]
  end

  out = .directory~new
  out["text"] = text
  out["row"] = row
  out["column"] = column
  out["bellCount"] = bells
  out["rows"] = lines~items
  maxColumns = 0
  do line over lines
    if line~length > maxColumns then maxColumns = line~length
  end
  out["columns"] = maxColumns
  return out

::method textFromHex class
  use strict arg hexArg
  return self~renderHex(hexArg)["text"]

::method putAt class private
  use strict arg lineArg, column, char
  line = lineArg~string
  if column < 1 then column = 1
  if line~length < column - 1 then line ||= copies(" ", column - 1 - line~length)
  if line~length < column then return line || char
  if column = 1 then leftPart = ""
  else leftPart = line~left(column - 1)
  if column < line~length then rightPart = line~substr(column + 1)
  else rightPart = ""
  return leftPart || char || rightPart


::class KL10ConsoleKeyboard public

::method init
  expose owner dte
  use strict arg ownerArg, dteArg
  owner = ownerArg
  dte = dteArg

::method type
  expose owner dte
  use arg textArg, expectedToken = .nil
  text = textArg~string
  check = self~preflight(expectedToken)
  if \check~ok then return check
  do i = 1 to text~length
    code = c2d(text~substr(i, 1))
    if code > 127 then
      return .KL10ConsoleResult~failure("NON_7BIT_CHARACTER", "keyboard facade accepts only 7-bit console bytes", owner~stateToken, self~queuedBytes)
  end
  ignored = dte~type(text)
  return .KL10ConsoleResult~success(owner~stateToken, self~queuedBytes)

::method typeLine
  use arg textArg, expectedToken = .nil
  text = textArg~string || d2c(13)
  return self~type(text, expectedToken)

::method press
  expose owner
  use arg keyArg, expectedToken = .nil
  key = keyArg~string~strip~upper
  select
    when key = "ENTER" | key = "RETURN" | key = "CR" then code = 13
    when key = "LINEFEED" | key = "LINE FEED" | key = "LF" then code = 10
    when key = "TAB" | key = "HT" then code = 9
    when key = "BACKSPACE" | key = "BS" then code = 8
    when key = "ESC" | key = "ESCAPE" then code = 27
    when key = "SPACE" then code = 32
    when key = "RUBOUT" | key = "DELETE" | key = "DEL" then code = 127
    when key = "NUL" | key = "NULL" then code = 0
    when key~left(5) = "CTRL-" then return self~control(key~substr(6), expectedToken)
    when key~left(8) = "CONTROL-" then return self~control(key~substr(9), expectedToken)
    when key = "BREAK" then return .KL10ConsoleResult~failure("UNSUPPORTED_SIGNAL_KEY", "DTE20 BREAK is not modeled as a character; no signal path is invented", owner~stateToken, self~queuedBytes)
    otherwise return .KL10ConsoleResult~failure("UNKNOWN_KEY", keyArg, owner~stateToken, self~queuedBytes)
  end
  return self~sendCode(code, expectedToken)

::method control
  expose owner
  use arg keyArg, expectedToken = .nil
  key = keyArg~string~strip~upper
  if key~length \= 1 then
    return .KL10ConsoleResult~failure("BAD_CONTROL_KEY", keyArg, owner~stateToken, self~queuedBytes)
  valid = "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
  if pos(key, valid) = 0 then
    return .KL10ConsoleResult~failure("BAD_CONTROL_KEY", keyArg, owner~stateToken, self~queuedBytes)
  code = c2d(key) // 32
  return self~sendCode(code, expectedToken)

::method sendCode
  expose owner dte
  use arg codeArg, expectedToken = .nil
  check = self~preflight(expectedToken)
  if \check~ok then return check
  if \datatype(codeArg, "W") | codeArg < 0 | codeArg > 127 then
    return .KL10ConsoleResult~failure("BAD_KEY_CODE", codeArg, owner~stateToken, self~queuedBytes)
  ignored = dte~type(d2c(codeArg))
  return .KL10ConsoleResult~success(owner~stateToken, self~queuedBytes)

::method queuedBytes
  expose dte
  return dte~rxHex~length % 2

::method preflight private
  expose owner dte
  use arg expectedToken
  current = owner~stateToken
  if expectedToken \== .nil then do
    if expectedToken~string \= current then
      return .KL10ConsoleResult~failure("STALE_STATE", "keyboard action was based on a different machine state", current, self~queuedBytes)
  end
  if \dte~monitorMode then
    return .KL10ConsoleResult~failure("KEYBOARD_NOT_READY", "DTE monitor mode is not enabled", current, self~queuedBytes)
  return .KL10ConsoleResult~success(current, self~queuedBytes)


::class KL10Console public
::attribute generation get

::method init
  expose cpu dte keyboard generation lastToken lastPumpCondition
  use strict arg cpuArg
  cpu = cpuArg
  if \cpu~ioBus~hasDevice(128) then
    raise syntax 40.900 array("KL10Console requires an attached DTE20 device")
  dte = cpu~dte
  keyboard = .KL10ConsoleKeyboard~new(self, dte)
  generation = 0
  lastToken = ""
  lastPumpCondition = ""

::method keyboard
  expose keyboard
  return keyboard

::method stateToken
  expose cpu dte
  numeric digits 30
  ds = dte~state
  base = cpu~pag~ebPtr
  dtMti = base + self~octToDecLocal("0456")
  if cpu~memory == .nil then inputFlag = -1
  else inputFlag = cpu~memory~physicalWord(dtMti)
  canonical = cpu~pc || "|" || cpu~instructionCount || "|" || -
              ds["statusInternal"] || "|" || ds["servicePending"] || "|" || -
              ds["monitorMode"] || "|" || ds["serviceCount"] || "|" || -
              ds["txHex"] || "|" || ds["rxHex"] || "|" || inputFlag
  return "KLC1-" || cpu~instructionCount || "-" || ds["serviceCount"] || "-" || (ds["txHex"]~length % 2) || "-" || (ds["rxHex"]~length % 2) || "-" || self~stableDigest(canonical)

::method snapshot
  expose cpu dte generation lastToken lastPumpCondition
  token = self~stateToken
  if token \= lastToken then do
    generation += 1
    lastToken = token
  end

  rendered = .KL10ConsoleRenderer~renderHex(dte~txHex)
  ready = self~inputReady
  waiting = self~guestWaitingForInput
  if dte~monitorMode then keyboardState = "UNLOCKED"
  else keyboardState = "LOCKED"
  if lastPumpCondition \= "" then sessionState = "EXECUTION_REFUSED"
  else if waiting then sessionState = "OPERATOR_WAIT"
  else sessionState = "HOST_WAIT"

  return .KL10ConsoleSnapshot~new(generation, token, "DEC-KL10-DTE20", keyboardState, sessionState, -
      cpu~pc, cpu~instructionCount, dte~monitorMode, ready, waiting, dte~rxHex~length % 2, -
      dte~txHex~length % 2, dte~txHex, rendered["text"], rendered["row"], rendered["column"], rendered["bellCount"], rendered["rows"], rendered["columns"])

::method inputReady
  expose cpu dte
  if \dte~monitorMode then return .false
  base = cpu~pag~ebPtr
  dtMti = base + self~octToDecLocal("0456")
  return cpu~memory~physicalWord(dtMti) = 0

::method guestWaitingForInput
  expose cpu dte
  if \self~inputReady then return .false
  if dte~rxHex \= "" then return .false
  proposal = cpu~preview
  if proposal["mnemonic"] \= "SKIPN" then return .false
  if proposal["effectiveAddress"] == .nil then return .false
  expected = cpu~pag~ebPtr + self~octToDecLocal("0456")
  return proposal["effectiveAddress"] = expected

::method pump
  expose cpu dte lastPumpCondition
  use arg maxStepsArg = 1000, stopModeArg = "WAIT"
  if \datatype(maxStepsArg, "W") | maxStepsArg < 0 then
    return .KL10ConsolePumpResult~new(.false, "BAD_STEP_LIMIT", 0, "", "", "", "", self~stateToken, self~snapshot)
  mode = stopModeArg~string~strip~upper
  if mode \= "WAIT" & mode \= "STEPS" & mode \= "OUTPUT" & mode \= "INPUT_DELIVERED" then
    return .KL10ConsolePumpResult~new(.false, "BAD_STOP_MODE", 0, "", "", "", mode, self~stateToken, self~snapshot)

  startHex = dte~txHex
  startRxBytes = dte~rxHex~length % 2
  stepsDone = 0
  lastPumpCondition = ""

  signal on syntax name pumpFailure
  do while stepsDone < maxStepsArg
    if mode = "WAIT" & stepsDone > 0 & self~guestWaitingForInput then do
      signal off syntax
      return self~pumpResult(.true, "OPERATOR_WAIT", stepsDone, startHex)
    end
    ignored = cpu~step
    stepsDone += 1
    if mode = "OUTPUT" & dte~txHex \= startHex then do
      signal off syntax
      return self~pumpResult(.true, "OUTPUT", stepsDone, startHex)
    end
    if mode = "INPUT_DELIVERED" & (dte~rxHex~length % 2) < startRxBytes then do
      signal off syntax
      return self~pumpResult(.true, "INPUT_DELIVERED", stepsDone, startHex)
    end
  end
  signal off syntax

  if mode = "WAIT" & self~guestWaitingForInput then reason = "OPERATOR_WAIT"
  else reason = "STEP_LIMIT"
  return self~pumpResult(.true, reason, stepsDone, startHex)

pumpFailure:
  signal off syntax
  c = condition("O")
  conditionCode = ""
  conditionMessage = ""
  if c~isa(.Directory) then do
    if c~hasIndex("CODE") then conditionCode = c["CODE"]
    if c~hasIndex("MESSAGE") then conditionMessage = c["MESSAGE"]
  end
  lastPumpCondition = conditionCode || ":" || conditionMessage
  return self~pumpResult(.false, "EXECUTION_REFUSED", stepsDone, startHex, conditionCode, conditionMessage)

::method pumpResult private
  expose dte
  use arg okArg, reasonArg, stepsArg, startHex, conditionCodeArg = "", conditionMessageArg = ""
  currentHex = dte~txHex
  if currentHex~left(startHex~length) = startHex then deltaHex = currentHex~substr(startHex~length + 1)
  else deltaHex = ""
  deltaText = .KL10ConsoleRenderer~textFromHex(deltaHex)
  snap = self~snapshot
  return .KL10ConsolePumpResult~new(okArg, reasonArg, stepsArg, deltaHex, deltaText, conditionCodeArg, conditionMessageArg, snap~stateToken, snap)

::method stableDigest private
  use strict arg valueArg
  numeric digits 30
  text = valueArg~string
  h = 2166136261
  do i = 1 to text~length
    octet = c2d(text~substr(i, 1))
    h = (h * 65599 + octet) // 4294967296
  end
  return right(d2x(h), 8, "0")

::method octToDecLocal private
  use strict arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

::requires "KL10IPL.cls"

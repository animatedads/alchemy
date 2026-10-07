/* Generic stream/teletype model v0.1. */

::class StreamTerminalModel public
::attribute terminalType get
::attribute generation get
::attribute keyboardState get
::attribute sessionState get

::method init
  expose terminalType generation keyboardState sessionState capabilities transcript currentLine metadata contentDigest layoutFingerprint historyLines
  use arg terminalTypeArg = "TTY", historyLinesArg = 40, capabilitiesArg = .nil
  terminalType = terminalTypeArg~string
  generation = 0
  keyboardState = "UNLOCKED"
  sessionState = .TerminalStatus~READY
  historyLines = historyLinesArg
  if historyLines < 1 then historyLines = 1
  transcript = .array~new
  currentLine = ""
  if capabilitiesArg == .nil then capabilities = .TerminalCapabilities~new
  else capabilities = capabilitiesArg~copyDetached
  capabilities~add("CHARACTER_STREAM")
  capabilities~add("CHARACTER_INPUT")
  metadata = .directory~new
  contentDigest = ""
  layoutFingerprint = "STREAM"

::method appendText
  expose transcript currentLine
  use arg textArg
  text = textArg~string
  do while pos("0a"x, text) > 0
    p = pos("0a"x, text)
    currentLine ||= left(text, p - 1)
    transcript~append(currentLine)
    currentLine = ""
    text = substr(text, p + 1)
  end
  currentLine ||= text
  return self

::method newline
  expose transcript currentLine
  transcript~append(currentLine)
  currentLine = ""
  return self

::method setKeyboardState
  expose keyboardState
  use arg stateArg
  keyboardState = stateArg~string~upper
  return self

::method setSessionState
  expose sessionState
  use arg stateArg
  sessionState = stateArg~string~upper
  return self

::method setMetadata
  expose metadata
  use arg name, value
  metadata[name~string] = value
  return self

::method advanceGeneration
  expose generation
  generation += 1
  return generation

::method snapshot
  expose terminalType generation keyboardState sessionState capabilities transcript currentLine metadata contentDigest layoutFingerprint historyLines
  lines = .array~new
  start = transcript~items - historyLines + 2
  if start < 1 then start = 1
  do i = start to transcript~items
    lines~append(transcript[i])
  end
  lines~append(currentLine)
  rowCount = lines~items
  maxWidth = 0
  do line over lines
    if line~length > maxWidth then maxWidth = line~length
  end
  return .TerminalSnapshot~new(generation, terminalType, rowCount, maxWidth, rowCount, currentLine~length + 1, keyboardState, sessionState, lines, .nil, capabilities, metadata, contentDigest, layoutFingerprint)

::requires "TerminalCore.cls"

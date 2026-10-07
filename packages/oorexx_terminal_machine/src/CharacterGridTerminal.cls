/* Generic mutable character-grid terminal model v0.2. */

::class CharacterGridModel public
::attribute terminalType get
::attribute rows get
::attribute columns get
::attribute generation get
::attribute cursorRow get
::attribute cursorColumn get
::attribute keyboardState get
::attribute sessionState get

::method init
  expose terminalType rows columns generation cursorRow cursorColumn keyboardState sessionState capabilities textRows metadata contentDigest layoutFingerprint
  use arg terminalTypeArg, rowsArg = 24, columnsArg = 80, capabilitiesArg = .nil
  terminalType = terminalTypeArg~string
  rows = rowsArg
  columns = columnsArg
  generation = 0
  cursorRow = 1
  cursorColumn = 1
  keyboardState = "UNLOCKED"
  sessionState = .TerminalStatus~READY
  textRows = .array~new(rows)
  do r = 1 to rows
    textRows[r] = copies(" ", columns)
  end
  if capabilitiesArg == .nil then capabilities = .TerminalCapabilities~new
  else capabilities = capabilitiesArg~copyDetached
  if \capabilities~has("CHARACTER_GRID") then capabilities~add("CHARACTER_GRID")
  metadata = .directory~new
  contentDigest = ""
  layoutFingerprint = ""

::method capabilities
  expose capabilities
  return capabilities~copyDetached

::method setMetadata
  expose metadata
  use arg name, value
  metadata[name~string] = value
  return self

::method metadata
  expose metadata
  return .TerminalUtil~copyDirectory(metadata)

::method setCursor
  expose cursorRow cursorColumn rows columns
  use arg rowArg, columnArg
  if rowArg < 1 | rowArg > rows | columnArg < 1 | columnArg > columns then return .TerminalResult~failure("CURSOR_RANGE", "cursor outside presentation space")
  cursorRow = rowArg
  cursorColumn = columnArg
  return .TerminalResult~success

::method cursorLinearPosition
  expose cursorRow cursorColumn columns
  return ((cursorRow - 1) * columns) + cursorColumn

::method linearPosition
  expose rows columns
  use arg rowArg, columnArg
  if rowArg < 1 | rowArg > rows | columnArg < 1 | columnArg > columns then return 0
  return ((rowArg - 1) * columns) + columnArg

::method rowForLinearPosition
  expose rows columns
  use arg positionArg
  if positionArg < 1 | positionArg > rows * columns then return 0
  return ((positionArg - 1) % columns) + 1

::method columnForLinearPosition
  expose rows columns
  use arg positionArg
  if positionArg < 1 | positionArg > rows * columns then return 0
  return ((positionArg - 1) // columns) + 1

::method setCursorLinear
  use arg positionArg
  row = self~rowForLinearPosition(positionArg)
  col = self~columnForLinearPosition(positionArg)
  if row == 0 | col == 0 then return .TerminalResult~failure("CURSOR_RANGE", "linear cursor outside presentation space")
  return self~setCursor(row, col)

::method advanceCursor
  expose rows columns
  use arg countArg = 1, wrapArg = .true
  pos = self~cursorLinearPosition + countArg
  maxPos = rows * columns
  if wrapArg then do
    do while pos > maxPos
      pos -= maxPos
    end
    do while pos < 1
      pos += maxPos
    end
  end
  else if pos < 1 | pos > maxPos then return .TerminalResult~failure("CURSOR_RANGE", "cursor advance outside presentation space")
  return self~setCursorLinear(pos)

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

::method resize
  expose rows columns textRows cursorRow cursorColumn
  use arg rowsArg, columnsArg
  if rowsArg < 1 | columnsArg < 1 then return .TerminalResult~failure("SCREEN_SIZE", rowsArg || "x" || columnsArg)
  rows = rowsArg
  columns = columnsArg
  textRows = .array~new(rows)
  do r = 1 to rows
    textRows[r] = copies(" ", columns)
  end
  cursorRow = 1
  cursorColumn = 1
  return .TerminalResult~success

::method eraseLinearRange
  use arg startPosition, endPosition
  if startPosition < 1 | endPosition < startPosition | endPosition > self~rows * self~columns then return .TerminalResult~failure("ERASE_RANGE", startPosition || "-" || endPosition)
  do posNow = startPosition to endPosition
    r = self~rowForLinearPosition(posNow)
    c = self~columnForLinearPosition(posNow)
    self~writeText(r, c, " ")
  end
  return .TerminalResult~success

::method clear
  expose textRows rows columns cursorRow cursorColumn
  do r = 1 to rows
    textRows[r] = copies(" ", columns)
  end
  cursorRow = 1
  cursorColumn = 1
  return self

::method writeText
  expose textRows rows columns
  use arg rowArg, columnArg, textArg
  if rowArg < 1 | rowArg > rows | columnArg < 1 | columnArg > columns then return .TerminalResult~failure("WRITE_RANGE", "write origin outside presentation space")
  text = textArg~string
  available = columns - columnArg + 1
  if text~length > available then text = text~left(available)
  line = textRows[rowArg]
  leftPart = ""
  if columnArg > 1 then leftPart = line~left(columnArg - 1)
  rightStart = columnArg + text~length
  rightPart = ""
  if rightStart <= columns then rightPart = line~substr(rightStart)
  textRows[rowArg] = leftPart || text || rightPart
  return .TerminalResult~success

/* Write through the linear presentation space, allowing normal row wrapping. */
::method writeLinearText
  expose rows columns
  use arg rowArg, columnArg, textArg
  startPos = self~linearPosition(rowArg, columnArg)
  if startPos == 0 then return .TerminalResult~failure("WRITE_RANGE", "write origin outside presentation space")
  text = textArg~string
  if text~length == 0 then return .TerminalResult~success
  if startPos + text~length - 1 > rows * columns then return .TerminalResult~failure("WRITE_RANGE", "write exceeds presentation space")
  do i = 1 to text~length
    posNow = startPos + i - 1
    r = self~rowForLinearPosition(posNow)
    c = self~columnForLinearPosition(posNow)
    self~writeText(r, c, text~substr(i, 1))
  end
  return .TerminalResult~success

::method readLinearText
  expose rows columns textRows
  use arg rowArg, columnArg, lengthArg
  startPos = self~linearPosition(rowArg, columnArg)
  if startPos == 0 | lengthArg < 0 then return ""
  if startPos + lengthArg - 1 > rows * columns then return ""
  textOut = ""
  do i = 0 to lengthArg - 1
    posNow = startPos + i
    r = self~rowForLinearPosition(posNow)
    c = self~columnForLinearPosition(posNow)
    textOut ||= textRows[r]~substr(c, 1)
  end
  return textOut

::method writeCharAtCursor
  expose cursorRow cursorColumn
  use arg charArg, advanceArg = .true
  if charArg~string~length == 0 then return .TerminalResult~success
  outcome = self~writeText(cursorRow, cursorColumn, charArg~string~substr(1, 1))
  if outcome~ok & advanceArg then return self~advanceCursor(1, .true)
  return outcome

::method setFingerprints
  expose contentDigest layoutFingerprint
  use arg contentArg = "", layoutArg = ""
  contentDigest = contentArg~string
  layoutFingerprint = layoutArg~string
  return self

::method advanceGeneration
  expose generation
  generation += 1
  return generation

::method snapshot
  expose terminalType rows columns generation cursorRow cursorColumn keyboardState sessionState capabilities textRows metadata contentDigest layoutFingerprint
  return .TerminalSnapshot~new(generation, terminalType, rows, columns, cursorRow, cursorColumn, keyboardState, sessionState, textRows, .nil, capabilities, metadata, contentDigest, layoutFingerprint)

::requires "TerminalCore.cls"

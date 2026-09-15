/* IBM 5250 inbound READ response encoder v0.3. */

::class TN5250InputBuild public
::constant RELEASE "0.3"
::constant API_VERSION "terminal.5250.input/0.3"

::class ReadModified5250Encoder public
::method aidReturnsData class
  use arg aidByte, readKindArg = "READ_MDT"
  h = aidByte~c2x
  if readKindArg = "READ_MDT_IMMEDIATE_ALT" then return .true
  if h = "F1" | h = "F4" | h = "F5" then return .true
  if readKindArg = "READ_INPUT" then do
    if h = "09" | h = "DA" | h = "3F" | h = "50" then return .true
  end
  n = x2d(h)
  if n >= x2d("31") & n <= x2d("3C") then return .true
  if n >= x2d("B1") & n <= x2d("BC") then return .true
  return .false

::method encode class
  use arg readArg, codePageArg = .nil
  if readArg == .nil then return .TerminalResult~failure("5250_INPUT_MISSING", "")
  if codePageArg == .nil then cp = .CodePage037~new
  else cp = codePageArg
  if readArg~cursorRow < 1 | readArg~cursorRow > 255 | readArg~cursorColumn < 1 | readArg~cursorColumn > 255 then,
    return .TerminalResult~failure("5250_INPUT_CURSOR", readArg~cursorRow || "," || readArg~cursorColumn)
  payload = d2c(readArg~cursorRow) || d2c(readArg~cursorColumn) || readArg~aidByte
  if \self~aidReturnsData(readArg~aidByte, readArg~readKind) then return .TerminalResult~success(payload)

  fields = readArg~fields
  if fields~items = 0 then return .TerminalResult~success(payload)
  if readArg~readKind = "READ_INPUT" then do
    anyModified = .false
    do f over fields
      if f~modified then anyModified = .true
    end
    if \anyModified then return .TerminalResult~success(payload)
    do f over fields
      encoded = self~fieldBytes(f, cp, "READ_INPUT")
      if \encoded~ok then return encoded
      payload ||= encoded~value
    end
    return .TerminalResult~success(payload)
  end

  if readArg~readKind \= "READ_MDT" & readArg~readKind \= "READ_MDT_ALT" & readArg~readKind \= "READ_MDT_IMMEDIATE_ALT" then,
    return .TerminalResult~failure("5250_INPUT_READ_KIND", readArg~readKind)
  encodeMode = readArg~readKind
  if encodeMode = "READ_MDT_IMMEDIATE_ALT" then encodeMode = "READ_MDT_ALT"
  do f over fields
    encoded = self~fieldBytes(f, cp, encodeMode)
    if \encoded~ok then return encoded
    payload ||= "11"x || d2c(f~row) || d2c(f~column) || encoded~value
  end
  return .TerminalResult~success(payload)

::method fieldBytes class private
  use arg fieldArg, cp, mode
  if fieldArg~attribute("transparent") == .true then,
    return .TerminalResult~failure("5250_TRANSPARENT_INPUT_REQUIRES_RAW_BYTES", fieldArg~fieldId)
  if fieldArg~attribute("shift") == "SIGNED_NUMERIC" then,
    return .TerminalResult~failure("5250_SIGNED_NUMERIC_INPUT_NOT_IMPLEMENTED", fieldArg~fieldId)
  text = fieldArg~value
  if mode = "READ_INPUT" then text = text~left(fieldArg~length)
  bytes = cp~encode(text)
  if mode = "READ_INPUT" then bytes = self~nullsToBlanks(bytes)
  else if mode = "READ_MDT" then bytes = self~suppressAllNulls(bytes)
  else if mode = "READ_MDT_ALT" then bytes = self~stripTrailingNulls(bytes)
  return .TerminalResult~success(bytes)

::method nullsToBlanks class private
  use arg bytes
  out = ""
  do i = 1 to bytes~length
    b = bytes~substr(i,1)
    if b = "00"x then out ||= "40"x
    else out ||= b
  end
  return out

::method suppressAllNulls class private
  use arg bytes
  out = ""
  do i = 1 to bytes~length
    b = bytes~substr(i,1)
    if b \= "00"x then out ||= b
  end
  return out

::method stripTrailingNulls class private
  use arg bytes
  n = bytes~length
  do while n > 0 & bytes~substr(n,1) = "00"x
    n -= 1
  end
  if n = 0 then return ""
  return bytes~left(n)

::requires "Terminal5250.cls"
::requires "CodePage5250.cls"

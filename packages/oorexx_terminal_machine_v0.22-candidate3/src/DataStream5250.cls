/*
 * Native IBM 5250 workstation datastream machine v0.6.
 *
 * Authority:
 *   IBM 5494 Remote Control Unit Functions Reference SC30-3533-04,
 *   Chapter 15 (Display Data Streams) and Chapter 16 (Keyboard Functions).
 *   RFC 1205 is applied as an addendum/correction for TN5250 interface details.
 *
 * This class deliberately parses 5250 workstation bytes only.  Telnet and the
 * RFC 1205 logical-record header remain separate layers.
 */

::class DataStream5250Build public
::constant RELEASE "0.6"
::constant API_VERSION "terminal.5250.datastream/0.6"

::class Command5250 public
::constant ESC "04"x
::constant CLEAR_UNIT "40"x
::constant CLEAR_UNIT_ALTERNATE "20"x
::constant CLEAR_FORMAT_TABLE "50"x
::constant WRITE_TO_DISPLAY "11"x
::constant WRITE_ERROR_CODE "21"x
::constant WRITE_ERROR_CODE_TO_WINDOW "22"x
::constant READ_INPUT_FIELDS "42"x
::constant READ_MDT_FIELDS "52"x
::constant READ_MDT_ALTERNATE "82"x
::constant READ_SCREEN "62"x
::constant READ_SCREEN_EXTENDED "64"x
::constant READ_IMMEDIATE "72"x
::constant READ_MDT_IMMEDIATE_ALTERNATE "83"x
::constant SAVE_SCREEN "02"x
::constant SAVE_PARTIAL_SCREEN "03"x
::constant RESTORE_SCREEN "12"x
::constant RESTORE_PARTIAL_SCREEN "13"x
::constant ROLL "23"x
::constant WRITE_STRUCTURED_FIELD "F3"x
::constant WRITE_SINGLE_STRUCTURED_FIELD "F4"x

::class Order5250 public
::constant SOH "01"x
::constant RA "02"x
::constant EA "03"x
::constant TD "10"x
::constant SBA "11"x
::constant WEA "12"x
::constant IC "13"x
::constant MC "14"x
::constant WDSF "15"x
::constant SF "1D"x

::class FieldFormatWord5250 public
::attribute raw get
::attribute rawHex get
::attribute bypass get
::attribute dupEnabled get
::attribute modified get
::attribute shiftCode get
::attribute autoEnter get
::attribute fieldExitRequired get
::attribute monocase get
::attribute mandatoryEnter get
::attribute adjustCode get

::method init
  expose raw rawHex bypass dupEnabled modified shiftCode autoEnter fieldExitRequired monocase mandatoryEnter adjustCode
  use arg bytesArg
  if bytesArg~length \= 2 then raise syntax 88.900 array("FFW requires exactly two bytes")
  raw = bytesArg
  rawHex = raw~c2x
  n = x2d(rawHex)
  if (n % 16384) \= 1 then raise syntax 88.900 array("Not a 5250 FFW: " || rawHex)
  bypass = self~bit(n, 8192)
  dupEnabled = self~bit(n, 4096)
  modified = self~bit(n, 2048)
  shiftCode = (n % 256) // 8
  autoEnter = self~bit(n, 128)
  fieldExitRequired = self~bit(n, 64)
  monocase = self~bit(n, 32)
  mandatoryEnter = self~bit(n, 8)
  adjustCode = n // 8

::method bit private
  use arg value, weight
  return ((value % weight) // 2) = 1

::method numeric
  expose shiftCode
  return shiftCode = 2 | shiftCode = 3 | shiftCode = 5 | shiftCode = 7

::method shiftName
  expose shiftCode
  select
    when shiftCode = 0 then return "ALPHA_SHIFT"
    when shiftCode = 1 then return "ALPHA_ONLY"
    when shiftCode = 2 then return "NUMERIC_SHIFT"
    when shiftCode = 3 then return "NUMERIC_ONLY"
    when shiftCode = 4 then return "KATAKANA_SHIFT"
    when shiftCode = 5 then return "DIGITS_ONLY"
    when shiftCode = 6 then return "IO_FEATURE"
    when shiftCode = 7 then return "SIGNED_NUMERIC"
    otherwise return "UNKNOWN"
  end

::method attributes
  expose rawHex bypass dupEnabled modified autoEnter fieldExitRequired monocase mandatoryEnter adjustCode
  d = .directory~new
  d["ffwHex"] = rawHex
  d["bypass"] = bypass
  d["dupEnabled"] = dupEnabled
  d["mdtFromHost"] = modified
  d["shift"] = self~shiftName
  d["autoEnter"] = autoEnter
  d["fieldExitRequired"] = fieldExitRequired
  d["monocase"] = monocase
  d["mandatoryEnter"] = mandatoryEnter
  d["adjustCode"] = adjustCode
  return d

::class FieldControlWord5250 public
::attribute raw get
::attribute rawHex get
::attribute kind get
::attribute parameter get

::method init
  expose raw rawHex kind parameter
  use arg bytesArg
  if bytesArg~length \= 2 then raise syntax 88.900 array("FCW requires exactly two bytes")
  raw = bytesArg
  rawHex = raw~c2x
  hi = raw~substr(1,1)~c2x
  parameter = x2d(raw~substr(2,1)~c2x)
  select
    when hi = "80" then kind = "RESEQUENCE"
    when rawHex = "8101" then kind = "MAG_STRIPE"
    when rawHex = "8102" then kind = "LIGHT_PEN_CURSOR_SELECT"
    when rawHex = "8103" then kind = "MAG_STRIPE_LIGHT_PEN"
    when rawHex = "8106" then kind = "LIGHT_PEN_ATTENTION"
    when hi = "82" then kind = "IDEOGRAPHIC"
    when hi = "84" then kind = "TRANSPARENT"
    when rawHex = "8501" then kind = "FORWARD_EDGE_TRIGGER"
    when hi = "86" then kind = "CONTINUED_OR_WORD_WRAP"
    when hi = "88" then kind = "CURSOR_PROGRESSION"
    when hi = "89" then kind = "HIGHLIGHTED"
    when hi = "8A" then kind = "MOUSE_SELECTION"
    when rawHex = "B140" then kind = "SELF_CHECK_MOD11"
    when rawHex = "B1A0" then kind = "SELF_CHECK_MOD10"
    otherwise kind = "UNKNOWN"
  end

::method isTransparent
  expose kind
  return kind = "TRANSPARENT"

::class DisplayAttribute5250 public
::attribute raw get
::attribute rawHex get
::attribute nonDisplay get
::attribute blink get
::attribute underscore get
::attribute reverseImage get
::attribute columnSeparator get

::method init
  expose raw rawHex nonDisplay blink underscore reverseImage columnSeparator
  use arg byteArg
  raw = byteArg~substr(1,1)
  rawHex = raw~c2x
  n = x2d(rawHex)
  if n < 32 | n > 63 then raise syntax 88.900 array("Not a 5250 display attribute: " || rawHex)
  /* IBM bit numbering is MSB first.  For monochrome attributes bits 5,6,7
   * all on inhibit display.  The same x'27/2F/37/3F' values are documented
   * as nondisplay in the color table. */
  nonDisplay = rawHex = "27" | rawHex = "2F" | rawHex = "37" | rawHex = "3F"
  columnSeparator = self~bit(n, 16)
  blink = self~bit(n, 8)
  underscore = self~bit(n, 4)
  reverseImage = self~bit(n, 1)

::method bit private
  use arg value, weight
  return ((value % weight) // 2) = 1

::method attributes
  expose rawHex nonDisplay blink underscore reverseImage columnSeparator
  d = .directory~new
  d["displayAttributeHex"] = rawHex
  d["nonDisplay"] = nonDisplay
  d["blink"] = blink
  d["underscore"] = underscore
  d["reverseImage"] = reverseImage
  d["columnSeparator"] = columnSeparator
  return d

::class DataStream5250Outcome public
::attribute commandName get
::attribute responsePayload get
::attribute changed get
::attribute detail get
::attribute consumedBytes

::method init
  expose commandName responsePayload changed detail consumedBytes
  use arg commandArg = "", responseArg = "", changedArg = .false, detailArg = "", consumedArg = 0
  commandName = commandArg~string
  responsePayload = responseArg
  changed = changedArg == .true
  detail = detailArg~string
  consumedBytes = consumedArg

::class QueryReply5250 public
::method for3179 class
  use arg codePageArg = .nil
  if codePageArg == .nil then cp = .CodePage037~new
  else cp = codePageArg
  /* RFC 1205 section 5.3 Query Reply.  This is an honest 24x80 colour
   * 5250-emulator capability declaration, not a copy of a 3180 identity. */
  reply = "0000"x                    /* cursor row/column */
  reply ||= "88"x                    /* inbound WSF AID */
  reply ||= "003A"x                  /* Query Reply structured-field length */
  reply ||= "D97080"x                /* class/type/reply flag */
  reply ||= "0600"x                  /* other WSF / other 5250 emulator */
  reply ||= "000300"x                /* implementation code level 0.3.0 */
  reply ||= copies("00"x, 16)        /* reserved */
  reply ||= "01"x                    /* 5250 display/emulation */
  reply ||= cp~encode("3179")
  reply ||= cp~encode("002")
  reply ||= "02"x                    /* standard keyboard */
  reply ||= "0000"x                  /* ext keyboard id + reserved */
  reply ||= "00000000"x              /* serial */
  reply ||= "0100"x                  /* max input fields = 256 */
  reply ||= "000000"x                /* reserved */
  /* Advertise only capabilities implemented end-to-end in v0.3:
   * limited Row1/Col1 plus PA1/PA2 and PA3.  READ-MDT-Alternate parsing is
   * present for text fields, but v0.3 does not preserve host-originated NULs
   * distinctly enough to advertise that capability.  Do not yet set the
   * combined MC/TD/transparent-field bit either: MC and TD display orders work,
   * but transparent-field inbound bytes are deliberately fail-closed.  Cursor
   * select remains unadvertised.  Read-Modified-Immediate-Alternate is now
   * implemented and advertised. */
  reply ||= "59"x
  reply ||= "11"x                    /* 24x80 + 5292/3179 style colour */
  reply ||= "000000"x                /* reserved/DBCS/graphics */
  reply ||= copies("00"x, 7)
  return reply

::class DataStream5250Machine public
::attribute model get
::attribute codePage get
::attribute currentPosition get
::attribute lastError get

::method init
  expose model codePage currentPosition lastError lastICRow lastICColumn lastMoveKind currentAttribute
  use arg modelArg, codePageArg = .nil
  model = modelArg
  if \model~isA(.PresentationSpace5250) then raise syntax 88.900 array("DataStream5250Machine requires PresentationSpace5250")
  if codePageArg == .nil then codePage = .CodePage037~new
  else codePage = codePageArg
  currentPosition = 1
  lastError = ""
  lastICRow = 0
  lastICColumn = 0
  lastMoveKind = ""
  currentAttribute = "20"x

::method resetAddress
  expose currentPosition
  currentPosition = 1
  return self

::method currentRow
  expose model currentPosition
  return model~rowForLinearPosition(currentPosition)

::method currentColumn
  expose model currentPosition
  return model~columnForLinearPosition(currentPosition)

::method fail private
  expose lastError
  use arg codeArg, detailArg = ""
  lastError = codeArg || ":" || detailArg
  return .TerminalResult~failure(codeArg, detailArg)

::method require private
  use arg bytes, posArg, countArg, labelArg
  if posArg + countArg - 1 > bytes~length then return self~fail("5250_TRUNCATED", labelArg)
  return .TerminalResult~success

::method bitSet private
  use arg valueArg, weightArg
  return ((valueArg % weightArg) // 2) = 1

::method setAddress private
  expose model currentPosition
  use arg rowArg, colArg, allowRowOneColumnZero = .false
  if rowArg = 1 & colArg = 0 & allowRowOneColumnZero then do
    currentPosition = 0
    return .TerminalResult~success
  end
  pos = model~linearPosition(rowArg, colArg)
  if pos = 0 then return self~fail("5250_ADDRESS", rowArg || "," || colArg)
  currentPosition = pos
  return .TerminalResult~success

::method advance private
  expose model currentPosition
  use arg countArg = 1
  currentPosition += countArg
  if currentPosition > model~rows * model~columns + 1 then return self~fail("5250_SCREEN_OVERFLOW", currentPosition)
  return .TerminalResult~success

::method writeDisplayByte private
  expose model codePage currentPosition currentAttribute
  use arg byteArg, transparentArg = .false
  if currentPosition < 1 | currentPosition > model~rows * model~columns then return self~fail("5250_SCREEN_OVERFLOW", currentPosition)
  row = model~rowForLinearPosition(currentPosition)
  col = model~columnForLinearPosition(currentPosition)
  if \transparentArg & codePage~isAttributeByte(byteArg) then do
    currentAttribute = byteArg
    text = " "
  end
  else if transparentArg then do
    /* TD permits every byte value.  Preserve the source byte in the visible
     * one-byte model as ISO-8859-1 where possible; the ordinary EBCDIC path
     * remains separate. */
    text = byteArg
  end
  else text = codePage~decodeDisplayByte(byteArg)
  outcome = model~hostWriteCharacter(row, col, text)
  if \outcome~ok then return outcome
  return self~advance(1)

::method withConsumed private
  use arg resultArg, countArg
  if resultArg~ok then resultArg~value~consumedBytes = countArg
  return resultArg

/* Consume every ESC-delimited command in one workstation-data-stream chain.
 * WTD discovers its own boundary while respecting TD's explicit byte length, so
 * an x'04' inside Transparent Data is not mistaken for the next command. */
::method consumeSequence
  use arg bytes
  offset = 1
  names = ""
  response = ""
  changed = .false
  do while offset <= bytes~length
    part = self~consume(bytes~substr(offset))
    if \part~ok then return part
    out = part~value
    if out~consumedBytes < 1 then return self~fail("5250_SEQUENCE_PROGRESS", offset)
    if names \= "" then names ||= "+"
    names ||= out~commandName
    changed = changed | out~changed
    if out~responsePayload~length > 0 then do
      if response~length > 0 then return self~fail("5250_MULTIPLE_RESPONSES", names)
      response = out~responsePayload
    end
    offset += out~consumedBytes
  end
  return .TerminalResult~success(.DataStream5250Outcome~new(names, response, changed, "", bytes~length))

::method consume
  expose model currentPosition lastError
  use arg bytes
  lastError = ""
  if bytes~length < 2 then return self~fail("5250_COMMAND_SHORT", bytes~c2x)
  if bytes~substr(1,1) \= .Command5250~ESC then return self~fail("5250_ESCAPE_EXPECTED", bytes~substr(1,1)~c2x)
  command = bytes~substr(2,1)
  select
    when command = .Command5250~CLEAR_UNIT then return self~withConsumed(self~consumeClearUnit, 2)
    when command = .Command5250~CLEAR_UNIT_ALTERNATE then do
      if bytes~length < 3 then return self~fail("5250_CUA_PARAMETER", "missing")
      return self~withConsumed(self~consumeClearUnitAlternate(bytes~substr(3,1)), 3)
    end
    when command = .Command5250~CLEAR_FORMAT_TABLE then return self~withConsumed(self~consumeClearFormatTable, 2)
    when command = .Command5250~WRITE_TO_DISPLAY then do
      commandResult = self~consumeWTD(bytes~substr(3))
      if commandResult~ok then commandResult~value~consumedBytes += 2
      return commandResult
    end
    when command = .Command5250~WRITE_ERROR_CODE then do
      commandResult = self~consumeWriteErrorCode(bytes~substr(3))
      if commandResult~ok then commandResult~value~consumedBytes += 2
      return commandResult
    end
    when command = .Command5250~READ_INPUT_FIELDS then do
      if bytes~length < 4 then return self~fail("5250_READ_CONTROL_SHORT", "READ_INPUT")
      return self~withConsumed(self~consumeRead("READ_INPUT", bytes~substr(3,2)), 4)
    end
    when command = .Command5250~READ_MDT_FIELDS then do
      if bytes~length < 4 then return self~fail("5250_READ_CONTROL_SHORT", "READ_MDT")
      return self~withConsumed(self~consumeRead("READ_MDT", bytes~substr(3,2)), 4)
    end
    when command = .Command5250~READ_MDT_ALTERNATE then do
      if bytes~length < 4 then return self~fail("5250_READ_CONTROL_SHORT", "READ_MDT_ALT")
      return self~withConsumed(self~consumeRead("READ_MDT_ALT", bytes~substr(3,2)), 4)
    end
    when command = .Command5250~READ_IMMEDIATE then do
      /* READ IMMEDIATE reads the format table rather than waiting for an AID.
       * We do not yet preserve the byte-exact regeneration/format-table image
       * needed to claim this command honestly. */
      return self~fail("5250_READ_IMMEDIATE_NOT_IMPLEMENTED", "byte-exact format-table read required")
    end
    when command = .Command5250~READ_MDT_IMMEDIATE_ALTERNATE then do
      immediate = model~buildImmediateModifiedAlternate
      encoded = .ReadModified5250Encoder~encode(immediate, self~codePage)
      if \encoded~ok then return encoded
      return self~withConsumed(.TerminalResult~success(.DataStream5250Outcome~new("READ_MDT_IMMEDIATE_ALT", encoded~value, .false)), 2)
    end
    when command = .Command5250~WRITE_STRUCTURED_FIELD then do
      if bytes~length < 4 then return self~fail("5250_WSF_SHORT", bytes~c2x)
      sfLength = x2d(bytes~substr(3,2)~c2x)
      commandResult = self~consumeWSF(bytes~substr(3))
      if commandResult~ok then commandResult~value~consumedBytes = 2 + sfLength
      return commandResult
    end
    otherwise return self~fail("5250_COMMAND_UNSUPPORTED", command~c2x)
  end

::method consumeClearUnit private
  expose model currentPosition
  model~clear
  model~clearFormatTable
  model~clearModifiedAllFields
  model~setKeyboardState("LOCKED")
  model~setSessionState(.TerminalStatus~HOST_WAIT)
  model~clearPendingRead
  model~clearHome
  model~setCursor(1,1)
  model~setIndicators(.false, .false, .false)
  currentPosition = 1
  return .TerminalResult~success(.DataStream5250Outcome~new("CLEAR_UNIT", "", .true))

::method consumeClearUnitAlternate private
  expose model currentPosition
  use arg parameters
  if parameters~length \= 1 then return self~fail("5250_CUA_PARAMETER", parameters~c2x)
  parameter = parameters~c2x
  if parameter = "00" then do
    /* This v0.2 personality declares IBM-3179-2/24x80 only.  A 27x132 CUA
     * would contradict the Query Reply, so reject it instead of resizing
     * behind the advertised capability boundary. */
    return self~fail("5250_SCREEN_SIZE_UNSUPPORTED", "27x132")
  end
  if parameter \= "80" then return self~fail("5250_CUA_PARAMETER", parameter)
  model~clear
  model~setKeyboardState("LOCKED")
  model~setSessionState(.TerminalStatus~HOST_WAIT)
  model~clearPendingAID
  model~clearPendingRead
  model~clearHome
  model~setCursor(1,1)
  currentPosition = 1
  return .TerminalResult~success(.DataStream5250Outcome~new("CLEAR_UNIT_ALTERNATE", "", .true, parameter))

::method consumeClearFormatTable private
  expose model
  model~clearFormatTable
  model~setKeyboardState("LOCKED")
  return .TerminalResult~success(.DataStream5250Outcome~new("CLEAR_FORMAT_TABLE", "", .true))

::method consumeWriteErrorCode private
  expose model codePage
  use arg bytes
  if bytes~length < 1 then return self~fail("5250_WRITE_ERROR_CODE_PARAMETER", "IC or data required")
  p = 1
  if bytes~substr(p,1) = .Order5250~IC then do
    req = self~require(bytes, p + 1, 2, "WRITE ERROR CODE IC")
    if \req~ok then return req
    row = x2d(bytes~substr(p+1,1)~c2x)
    col = x2d(bytes~substr(p+2,1)~c2x)
    if model~linearPosition(row,col) = 0 then return self~fail("5250_IC_ADDRESS", row || "," || col)
    model~setCursor(row,col)
    p += 3
  end
  endAt = bytes~length
  escAt = bytes~pos(.Command5250~ESC, p)
  if escAt > 0 then endAt = escAt - 1
  data = ""
  if p <= endAt then data = bytes~substr(p, endAt - p + 1)
  if data~length > model~columns then return self~fail("5250_WRITE_ERROR_CODE_LENGTH", data~length)

  /* Preserve only the visible interpretation of host-supplied error data.
   * Display attributes are controls, not printable characters. */
  visible = ""
  displayEnabled = .true
  do i = 1 to data~length
    b = data~substr(i,1)
    if codePage~isAttributeByte(b) then do
      attr = .DisplayAttribute5250~new(b)
      displayEnabled = \attr~nonDisplay
      iterate
    end
    if displayEnabled then visible ||= codePage~decode(b)
  end
  entered = model~enterOperatorError("", "HOST_WRITE_ERROR_CODE", visible, "HOST_WRITE_ERROR_CODE")
  if \entered~ok then return entered
  model~clearPendingAID
  return .TerminalResult~success(.DataStream5250Outcome~new("WRITE_ERROR_CODE", "", .true, visible, endAt))

::method consumeRead private
  expose model
  use arg readKind, controlBytes
  model~setPendingRead(readKind, controlBytes)
  model~setSessionState(.TerminalStatus~OPERATOR_WAIT)
  return .TerminalResult~success(.DataStream5250Outcome~new(readKind, "", .true, controlBytes~c2x))

::method consumeWSF private
  use arg bytes
  if bytes~length < 5 then return self~fail("5250_WSF_SHORT", bytes~c2x)
  length = x2d(bytes~substr(1,2)~c2x)
  if length < 5 | length > bytes~length then return self~fail("5250_WSF_LENGTH", length)
  sf = bytes~left(length)
  if sf~substr(3,1) = "D9"x & sf~substr(4,1) = "70"x & sf~substr(5,1) = "00"x then do
    reply = .QueryReply5250~for3179(self~codePage)
    return .TerminalResult~success(.DataStream5250Outcome~new("5250_QUERY", reply, .false))
  end
  return self~fail("5250_WSF_UNSUPPORTED", sf~substr(3,2)~c2x)

::method consumeWTD private
  expose model codePage currentPosition lastICRow lastICColumn lastMoveKind currentAttribute
  use arg bytes
  if bytes~length < 2 then return self~fail("5250_WTD_SHORT", bytes~c2x)
  cc0 = x2d(bytes~substr(1,1)~c2x)
  cc1 = x2d(bytes~substr(2,1)~c2x)
  /* IBM Table 15-2.  IBM numbers bits from the MSB: bits 0-2 are the
   * high three numeric bits (weights x'80', x'40', x'20').  Bits 3-6 are
   * reserved and bit 7 (numeric weight x'01') is the non-stream flag.
   * Every nonzero operation mode resets pending AID and locks the keyboard. */
  cc0Mode = cc0 % 32
  if cc0Mode > 0 then do
    model~clearPendingAID
    model~setKeyboardState("LOCKED")
    model~setSessionState(.TerminalStatus~HOST_WAIT)
  end
  select
    when cc0Mode = 0 then nop
    when cc0Mode = 1 then nop
    when cc0Mode = 2 then model~clearModifiedNonBypassFields
    when cc0Mode = 3 then model~clearModifiedAllFields
    when cc0Mode = 4 then model~nullNonBypassFields(.true)
    when cc0Mode = 5 then do
      model~clearModifiedNonBypassFields
      model~nullNonBypassFields(.false)
    end
    when cc0Mode = 6 then do
      /* Null the fields that carried MDT on entry, then reset MDT. */
      model~nullNonBypassFields(.true)
      model~clearModifiedNonBypassFields
    end
    when cc0Mode = 7 then do
      model~clearModifiedAllFields
      model~nullNonBypassFields(.false)
    end
  end
  model~setMetadata("wtdNonStream", self~bitSet(cc0, 1))

  p = 3
  currentPosition = 1
  /* The Home key is defined from the IC in the most recent WTD.  A WTD
   * without IC therefore removes any older system-IC home address. */
  lastICRow = 0
  lastICColumn = 0
  lastMoveKind = ""
  model~clearHome
  do while p <= bytes~length
    b = bytes~substr(p,1)
    if b = .Command5250~ESC then leave
    select
      when b = .Order5250~SBA then do
        req = self~require(bytes, p + 1, 2, "SBA")
        if \req~ok then return req
        row = x2d(bytes~substr(p+1,1)~c2x)
        col = x2d(bytes~substr(p+2,1)~c2x)
        positioned = self~setAddress(row, col, .true)
        if \positioned~ok then return positioned
        if row = 1 & col = 0 then do
          if p + 3 > bytes~length | bytes~substr(p+3,1) \= .Order5250~SF then return self~fail("5250_SBA_ROW1_COL0_REQUIRES_SF", "")
        end
        p += 3
      end
      when b = .Order5250~IC then do
        req = self~require(bytes, p + 1, 2, "IC")
        if \req~ok then return req
        row = x2d(bytes~substr(p+1,1)~c2x); col = x2d(bytes~substr(p+2,1)~c2x)
        if model~linearPosition(row,col) = 0 then return self~fail("5250_IC_ADDRESS", row || "," || col)
        lastICRow = row; lastICColumn = col; lastMoveKind = "IC"
        model~setHome(row,col)
        p += 3
      end
      when b = .Order5250~MC then do
        req = self~require(bytes, p + 1, 2, "MC")
        if \req~ok then return req
        row = x2d(bytes~substr(p+1,1)~c2x); col = x2d(bytes~substr(p+2,1)~c2x)
        if model~linearPosition(row,col) = 0 then return self~fail("5250_MC_ADDRESS", row || "," || col)
        model~setCursor(row,col)
        lastMoveKind = "MC"
        p += 3
      end
      when b = .Order5250~RA then do
        req = self~require(bytes, p + 1, 3, "RA")
        if \req~ok then return req
        row = x2d(bytes~substr(p+1,1)~c2x); col = x2d(bytes~substr(p+2,1)~c2x)
        target = model~linearPosition(row,col)
        if target = 0 | target < currentPosition then return self~fail("5250_RA_ADDRESS", row || "," || col)
        repeatByte = bytes~substr(p+3,1)
        do while currentPosition <= target
          wr = self~writeDisplayByte(repeatByte)
          if \wr~ok then return wr
        end
        p += 4
      end
      when b = .Order5250~EA then do
        req = self~require(bytes, p + 1, 3, "EA")
        if \req~ok then return req
        row = x2d(bytes~substr(p+1,1)~c2x); col = x2d(bytes~substr(p+2,1)~c2x)
        target = model~linearPosition(row,col)
        if target = 0 | target < currentPosition then return self~fail("5250_EA_ADDRESS", row || "," || col)
        len = x2d(bytes~substr(p+3,1)~c2x)
        if len < 2 | len > 5 then return self~fail("5250_EA_LENGTH", len)
        req = self~require(bytes, p + 4, len - 1, "EA attribute list")
        if \req~ok then return req
        types = bytes~substr(p+4, len-1)
        clearDisplay = .false
        do ti = 1 to types~length
          t = types~substr(ti,1)~c2x
          if t = "00" | t = "FF" then clearDisplay = .true
        end
        if clearDisplay then do posNow = currentPosition to target
          r = model~rowForLinearPosition(posNow); c = model~columnForLinearPosition(posNow)
          model~hostWriteCharacter(r,c," ")
        end
        currentPosition = target + 1
        p += 3 + len
      end
      when b = .Order5250~TD then do
        req = self~require(bytes, p + 1, 2, "TD length")
        if \req~ok then return req
        len = x2d(bytes~substr(p+1,2)~c2x)
        req = self~require(bytes, p + 3, len, "TD data")
        if \req~ok then return req
        do i = 1 to len
          wr = self~writeDisplayByte(bytes~substr(p+2+i,1), .true)
          if \wr~ok then return wr
        end
        p += 3 + len
      end
      when b = .Order5250~WEA then do
        req = self~require(bytes, p + 1, 2, "WEA")
        if \req~ok then return req
        /* Preserve the latest extended attribute in presentation metadata.
         * WEA itself does not modify the current display address. */
        model~setMetadata("lastWEAType", bytes~substr(p+1,1)~c2x)
        model~setMetadata("lastWEAValue", bytes~substr(p+2,1)~c2x)
        p += 3
      end
      when b = .Order5250~SOH then do
        req = self~require(bytes, p + 1, 1, "SOH length")
        if \req~ok then return req
        len = x2d(bytes~substr(p+1,1)~c2x)
        if len < 1 | len > 7 then return self~fail("5250_SOH_LENGTH", len)
        req = self~require(bytes, p + 2, len, "SOH data")
        if \req~ok then return req
        model~clearFormatTable
        model~setMetadata("lastSOH", bytes~substr(p+2,len)~c2x)
        if len >= 4 then do
          errorRow = x2d(bytes~substr(p+5,1)~c2x)
          if errorRow = 0 then errorRow = model~rows
          if errorRow >= 1 & errorRow <= model~rows then model~setMetadata("errorRow", errorRow)
        end
        p += 2 + len
      end
      when b = .Order5250~SF then do
        parsed = self~consumeSF(bytes, p)
        if \parsed~ok then return parsed
        p = parsed~value
      end
      when b = .Order5250~WDSF then return self~fail("5250_WDSF_UNSUPPORTED", "structured field inside WTD")
      otherwise do
        /* Remaining low control values are not generic text.  Data characters
         * specifically include NUL/DUP/FM/SI/SO; other undocumented control
         * values fail closed instead of being guessed. */
        n = x2d(b~c2x)
        if n < 32 & n \= 0 & n \= 14 & n \= 15 & n \= 28 & n \= 30 then return self~fail("5250_WTD_ORDER_UNKNOWN", b~c2x)
        wr = self~writeDisplayByte(b)
        if \wr~ok then return wr
        p += 1
      end
    end
  end

  /* IBM Table 15-3, with IBM/MSB bit numbering mapped to numeric weights. */
  leaveCursor = self~bitSet(cc1, 64)
  resetBlink = self~bitSet(cc1, 32)
  setBlink = self~bitSet(cc1, 16)
  unlock = self~bitSet(cc1, 8)
  alarm = self~bitSet(cc1, 4)
  msgOff = self~bitSet(cc1, 2)
  msgOn = self~bitSet(cc1, 1)
  if resetBlink then model~setIndicators(.nil, .false, .nil)
  if setBlink then model~setIndicators(.nil, .true, .nil)
  if alarm then model~setIndicators(.nil, .nil, .true)
  if msgOff then model~setIndicators(.false, .nil, .nil)
  if msgOn then model~setIndicators(.true, .nil, .nil)
  if unlock & model~keyboardState \= "UNLOCKED" then do
    model~clearPendingAID
    model~setKeyboardState("UNLOCKED")
    model~setSessionState(.TerminalStatus~OPERATOR_WAIT)
    if \leaveCursor & lastMoveKind \= "MC" then do
      if lastICRow > 0 then model~setCursor(lastICRow, lastICColumn)
      else do
        first = model~firstInputField
        if first == .nil then model~setCursor(1,1)
        else model~setCursor(first~row, first~column)
      end
    end
  end
  return .TerminalResult~success(.DataStream5250Outcome~new("WRITE_TO_DISPLAY", "", .true, "", p - 1))

::method consumeSF private
  expose model currentPosition codePage currentAttribute
  use arg bytes, p
  next = p + 1
  req = self~require(bytes, next, 1, "SF first word")
  if \req~ok then return req
  first = bytes~substr(next,1)
  firstN = x2d(first~c2x)
  top2 = firstN % 64
  ffw = .nil
  fcws = .array~new
  if top2 = 1 then do
    req = self~require(bytes, next, 2, "FFW")
    if \req~ok then return req
    ffw = .FieldFormatWord5250~new(bytes~substr(next,2))
    next += 2
    do while next + 1 <= bytes~length
      n = x2d(bytes~substr(next,1)~c2x)
      if n % 64 \= 2 then leave
      fcw = .FieldControlWord5250~new(bytes~substr(next,2))
      if fcw~kind = "UNKNOWN" then return self~fail("5250_FCW_UNKNOWN", fcw~rawHex)
      fcws~append(fcw)
      next += 2
    end
  end
  req = self~require(bytes, next, 3, "SF attribute/length")
  if \req~ok then return req
  attrByte = bytes~substr(next,1)
  attrN = x2d(attrByte~c2x)
  if attrN < 32 | attrN > 63 then return self~fail("5250_SF_ATTRIBUTE", attrByte~c2x)
  attr = .DisplayAttribute5250~new(attrByte)
  fieldLength = x2d(bytes~substr(next+1,2)~c2x)
  if fieldLength < 1 then return self~fail("5250_FIELD_LENGTH", fieldLength)

  /* SBA row1/col0 special case means the attribute is suppressed and the
   * first data position is row1/col1. */
  suppressLeading = currentPosition = 0
  if suppressLeading & ffw \== .nil then do
    if attr~nonDisplay then return self~fail("5250_ROW1_COL1_NONDISPLAY", attr~rawHex)
  end
  if suppressLeading then startPos = 1
  else startPos = currentPosition + 1
  if startPos + fieldLength - 1 > model~rows * model~columns then return self~fail("5250_FIELD_RANGE", fieldLength)
  startRow = model~rowForLinearPosition(startPos)
  startCol = model~columnForLinearPosition(startPos)

  if \suppressLeading then do
    ar = model~rowForLinearPosition(currentPosition); ac = model~columnForLinearPosition(currentPosition)
    model~hostWriteCharacter(ar, ac, " ")
  end
  endingPos = startPos + fieldLength
  if endingPos <= model~rows * model~columns then do
    er = model~rowForLinearPosition(endingPos); ec = model~columnForLinearPosition(endingPos)
    model~hostWriteCharacter(er, ec, " ")
  end

  if ffw \== .nil then do
    attrs = ffw~attributes
    attrs["leadingAttributeHex"] = attr~rawHex
    attrs["fcwCount"] = fcws~items
    attrs["transparent"] = .false
    fcwHex = ""
    do fcw over fcws
      if fcwHex \= "" then fcwHex ||= ","
      fcwHex ||= fcw~rawHex
      if fcw~isTransparent then attrs["transparent"] = .true
    end
    attrs["fcwHex"] = fcwHex
    id = "F" || right(startPos, 4, "0")
    defined = model~defineOrReplaceField(id, startRow, startCol, fieldLength, "", \ffw~bypass, ffw~bypass, attr~nonDisplay, ffw~numeric, attrs, ffw~modified)
    if \defined~ok then return defined
    model~setKeyboardState("LOCKED")
  end
  currentAttribute = attrByte
  currentPosition = startPos
  return .TerminalResult~success(next + 3)

::requires "Terminal5250.cls"
::requires "CodePage5250.cls"

::requires "TN5250Input.cls"

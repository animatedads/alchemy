/*
 * TN5250 display driver v0.3.
 *
 * Boundary:
 *   Telnet -> RFC 1205 logical record -> IBM 5250 workstation datastream.
 *
 * The driver owns no rendering UI.  It advances the native presentation model,
 * optionally commits immutable snapshots into TerminalSession/WatchAlong, and
 * returns raw RFC-1205 records that the transport may frame with IAC EOR.
 */

::class TN5250DisplayDriverBuild public
::constant RELEASE "0.3"
::constant API_VERSION "terminal.tn5250.display-driver/0.3"

::class TN5250DisplayDriverResult public
::attribute inboundOpcodeHex get
::attribute commandName get
::attribute changed get
::attribute snapshot get
::attribute outboundRecords get
::attribute detail get

::method init
  expose inboundOpcodeHex commandName changed snapshot outboundRecords detail
  use arg opcodeArg, commandArg = "", changedArg = .false, snapshotArg = .nil, outboundArg = .nil, detailArg = ""
  inboundOpcodeHex = opcodeArg~string~upper
  commandName = commandArg~string
  changed = changedArg == .true
  snapshot = snapshotArg
  outboundRecords = .TerminalUtil~copyArray(outboundArg)
  detail = detailArg~string

::class TN5250DisplayDriver public
::attribute model get
::attribute session get
::attribute datastream get

::method init
  expose model session datastream saveStates saveCounter
  use arg modelArg, sessionArg = .nil, codePageArg = .nil
  model = modelArg
  if \model~isA(.PresentationSpace5250) then raise syntax 88.900 array("TN5250DisplayDriver requires PresentationSpace5250")
  session = sessionArg
  datastream = .DataStream5250Machine~new(model, codePageArg)
  saveStates = .table~new
  saveCounter = 0

::method commitHostState private
  expose model session
  model~hostCommit
  if session == .nil then return model~snapshot
  return session~commit

::method consumeRecordBytes
  use arg bytesArg
  decoded = .TN5250RecordCodec~decode(bytesArg)
  if \decoded~ok then return decoded
  return self~consumeRecord(decoded~value)

/* Consume the driver's internal AID/read object and turn it into the RFC 1205
 * client-to-server NOP record used for ordinary workstation input.  The raw
 * record may contain nondisplay field data and therefore must remain on the
 * transport path; it is never copied into snapshots or WatchAlong. */
::method takePendingInputRecord
  expose model datastream
  pending = model~peekPendingReadModified
  if pending == .nil then return .TerminalResult~failure("TN5250_NO_PENDING_INPUT", "")
  encoded = .ReadModified5250Encoder~encode(pending, datastream~codePage)
  if \encoded~ok then return encoded
  built = .TN5250RecordCodec~encode(.TN5250Opcode~NOP, encoded~value)
  if \built~ok then return built
  /* Consume the internal secret-bearing object only after a complete outbound
   * RFC record has been built successfully. */
  consumed = model~takePendingReadModified
  return built

::method takePendingInputTelnetFrame
  built = self~takePendingInputRecord
  if \built~ok then return built
  return .TerminalResult~success(.TN5250RecordCodec~telnetFrame(built~value))

::method hasPendingTerminalOutput
  expose model
  if model~peekPendingControlSignal \= "" then return .true
  return model~peekPendingReadModified \== .nil

::method takePendingControlRecord private
  expose model
  signalName = model~peekPendingControlSignal
  if signalName = "" then return .TerminalResult~failure("TN5250_NO_PENDING_CONTROL", "")
  flags = .TN5250Flag~forSignal(signalName)
  if flags == .nil then return .TerminalResult~failure("TN5250_CONTROL_SIGNAL_UNKNOWN", signalName)
  built = .TN5250RecordCodec~encode(.TN5250Opcode~NOP, "", flags)
  if \built~ok then return built
  ignore = model~takePendingControlSignal
  return built

::method takePendingTerminalTelnetFrame
  expose model
  if model~peekPendingControlSignal \= "" then do
    built = self~takePendingControlRecord
    if \built~ok then return built
    return .TerminalResult~success(.TN5250RecordCodec~telnetFrame(built~value))
  end
  if model~peekPendingReadModified \== .nil then return self~takePendingInputTelnetFrame
  return .TerminalResult~failure("TN5250_NO_PENDING_OUTPUT", "")

/* IBM says SAVE data is workstation-specific and the host must return it
 * unchanged on RESTORE.  This implementation therefore uses a small opaque
 * session token on the wire and keeps the secret-bearing saved state inside
 * the trusted driver.  It does not claim byte compatibility with a 5494 save
 * image, only the documented SAVE/RESTORE contract. */
::method saveScreenRecord private
  expose model saveStates saveCounter
  saveCounter += 1
  token = right(d2x(saveCounter), 8, "0")
  saveStates[token] = model~capturePrivateState
  payload = .Command5250~ESC || .Command5250~RESTORE_SCREEN || "ORX1" || token
  return .TN5250RecordCodec~encode(.TN5250Opcode~SAVE_SCREEN, payload)

::method restoreScreenPayload private
  expose model saveStates
  use arg payload
  if payload~length \= 14 then return .TerminalResult~failure("5250_RESTORE_IMAGE_FORMAT", payload~length)
  if payload~substr(1,2) \= .Command5250~ESC || .Command5250~RESTORE_SCREEN then return .TerminalResult~failure("5250_RESTORE_IMAGE_PREFIX", payload~left(2)~c2x)
  if payload~substr(3,4) \= "ORX1" then return .TerminalResult~failure("5250_RESTORE_IMAGE_FOREIGN", payload~substr(3,4)~c2x)
  token = payload~substr(7,8)
  saved = saveStates[token]
  if saved == .nil then return .TerminalResult~failure("5250_RESTORE_IMAGE_UNKNOWN", token)
  return model~restorePrivateState(saved)

::method consumeRecord
  expose model datastream
  use arg record
  opcode = record~opcode
  opcodeHex = opcode~c2x
  outbound = .array~new
  commandName = ""
  changed = .false
  detail = ""

  select
    when opcode == .TN5250Opcode~MESSAGE_LIGHT_ON then do
      model~setIndicators(.true, .nil, .nil)
      commandName = "MESSAGE_LIGHT_ON"
      changed = .true
    end
    when opcode == .TN5250Opcode~MESSAGE_LIGHT_OFF then do
      model~setIndicators(.false, .nil, .nil)
      commandName = "MESSAGE_LIGHT_OFF"
      changed = .true
    end
    when opcode == .TN5250Opcode~CANCEL_INVITE then do
      model~setKeyboardState("LOCKED")
      model~setSessionState(.TerminalStatus~HOST_WAIT)
      model~clearPendingRead
      /* RFC 1205 requires the client to acknowledge Cancel Invite with the
       * same opcode before sending further user data. */
      echo = .TN5250RecordCodec~encode(.TN5250Opcode~CANCEL_INVITE)
      if \echo~ok then return echo
      outbound~append(echo~value)
      commandName = "CANCEL_INVITE"
      changed = .true
    end
    when opcode == .TN5250Opcode~SAVE_SCREEN then do
      if record~payload \= .Command5250~ESC || .Command5250~SAVE_SCREEN then return .TerminalResult~failure("5250_SAVE_REQUEST_FORMAT", record~payload~c2x)
      savedRecord = self~saveScreenRecord
      if \savedRecord~ok then return savedRecord
      outbound~append(savedRecord~value)
      commandName = "SAVE_SCREEN"
      detail = "opaque-session-save"
    end
    when opcode == .TN5250Opcode~RESTORE_SCREEN then do
      restored = self~restoreScreenPayload(record~payload)
      if \restored~ok then return restored
      commandName = "RESTORE_SCREEN"
      changed = .true
      detail = "opaque-session-restore"
    end
    when opcode == .TN5250Opcode~NOP |, 
         opcode == .TN5250Opcode~INVITE |,
         opcode == .TN5250Opcode~OUTPUT_ONLY |,
         opcode == .TN5250Opcode~PUT_GET |,
         opcode == .TN5250Opcode~READ_IMMEDIATE |,
         opcode == .TN5250Opcode~READ_SCREEN then do
      if record~payload~length = 0 then do
        commandName = "RFC1205_OPCODE_" || opcodeHex
      end
      else do
        parsed = datastream~consumeSequence(record~payload)
        if \parsed~ok then do
          model~setMetadata("lastDataStreamError", parsed~code || ":" || parsed~detail)
          /* IBM WTD processing can leave valid parameters before a bad
           * parameter in effect.  Publish the resulting evidence rather than
           * pretending the presentation space rolled back atomically. */
          self~commitHostState
          return parsed
        end
        ds = parsed~value
        commandName = ds~commandName
        changed = ds~changed
        detail = ds~detail
        if ds~responsePayload~length > 0 then do
          built = .TN5250RecordCodec~encode(.TN5250Opcode~NOP, ds~responsePayload)
          if \built~ok then return built
          outbound~append(built~value)
        end
      end
    end
    otherwise return .TerminalResult~failure("TN5250_OPCODE_UNSUPPORTED", opcodeHex)
  end

  if changed then snapshot = self~commitHostState
  else snapshot = model~snapshot
  driverResult = .TN5250DisplayDriverResult~new(opcodeHex, commandName, changed, snapshot, outbound, detail)
  return .TerminalResult~success(driverResult)

::requires "DataStream5250.cls"
::requires "TN5250Wire.cls"
::requires "TN5250Input.cls"

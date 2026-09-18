/* RFC 1205 / enhanced Telnet wire layer for the 5250 personality v0.7. */

::class TN5250Opcode public
::constant NOP "00"x
::constant INVITE "01"x
::constant OUTPUT_ONLY "02"x
::constant PUT_GET "03"x
::constant SAVE_SCREEN "04"x
::constant RESTORE_SCREEN "05"x
::constant READ_IMMEDIATE "06"x
::constant READ_SCREEN "08"x
::constant CANCEL_INVITE "0A"x
::constant MESSAGE_LIGHT_ON "0B"x
::constant MESSAGE_LIGHT_OFF "0C"x


::class TN5250Flag public
/* RFC 1205 numbers bits from the MSB of the first flag byte. */
::constant ERR "8000"x
::constant ATN "4000"x
::constant SRQ "0400"x
::constant TRQ "0200"x
::constant HLP "0100"x

::method forSignal class
  use arg nameArg
  name = nameArg~string~strip~upper
  select
    when name = "SYSTEM_REQUEST" then return self~SRQ
    when name = "ATTENTION" then return self~ATN
    when name = "TEST_REQUEST" then return self~TRQ
    otherwise return .nil
  end

::class TN5250Record public
::attribute logicalLength get
::attribute recordType get
::attribute reserved get
::attribute variableHeaderLength get
::attribute flags get
::attribute opcode get
::attribute payload get
::attribute rawBytes get

::method init
  expose logicalLength recordType reserved variableHeaderLength flags opcode payload rawBytes
  use arg logicalLengthArg, recordTypeArg, reservedArg, variableHeaderLengthArg, flagsArg, opcodeArg, payloadArg = "", rawArg = ""
  logicalLength = logicalLengthArg
  recordType = recordTypeArg
  reserved = reservedArg
  variableHeaderLength = variableHeaderLengthArg
  flags = flagsArg
  opcode = opcodeArg
  payload = payloadArg
  rawBytes = rawArg

::class TN5250RecordCodec public
::method decode class
  use arg bytes
  if bytes~length < 10 then return .TerminalResult~failure("TN5250_RECORD_SHORT", "record is shorter than ten-byte RFC 1205 header")
  logicalLength = x2d(bytes~substr(1, 2)~c2x)
  if logicalLength \== bytes~length then return .TerminalResult~failure("TN5250_LENGTH_MISMATCH", "declared=" || logicalLength || " actual=" || bytes~length)
  recordType = bytes~substr(3, 2)
  if recordType~c2x \== "12A0" then return .TerminalResult~failure("TN5250_RECORD_TYPE", recordType~c2x)
  reserved = bytes~substr(5, 2)
  variableLength = x2d(bytes~substr(7, 1)~c2x)
  if variableLength < 4 then return .TerminalResult~failure("TN5250_VARIABLE_HEADER", variableLength)
  if 6 + variableLength > bytes~length then return .TerminalResult~failure("TN5250_VARIABLE_HEADER", "variable header exceeds record")
  flags = bytes~substr(8, 2)
  opcode = bytes~substr(10, 1)
  payloadStart = 7 + variableLength
  payload = ""
  if payloadStart <= bytes~length then payload = bytes~substr(payloadStart)
  record = .TN5250Record~new(logicalLength, recordType, reserved, variableLength, flags, opcode, payload, bytes)
  return .TerminalResult~success(record)

::method encode class
  use arg opcode, payload = "", flags = "0000"x
  variableLength = 4
  logicalLength = 10 + payload~length
  if logicalLength > 65535 then return .TerminalResult~failure("TN5250_RECORD_TOO_LARGE", logicalLength)
  lengthBytes = x2c(right(d2x(logicalLength), 4, "0"))
  bytes = lengthBytes || "12A0"x || "0000"x || d2c(variableLength) || flags || opcode || payload
  return .TerminalResult~success(bytes)

::method telnetFrame class
  use arg recordBytes
  return .TelnetCodec~frameRecord(recordBytes)

/* 5250-specific Telnet negotiation profile. */
::class TN5250DeviceCollisionPolicy public
::constant ADVANCE "ADVANCE"
::constant STRICT "STRICT"

::method normalize class
  use arg valueArg = "ADVANCE"
  value = valueArg~string~strip~upper
  if value == self~ADVANCE | value == self~STRICT then return value
  return ""

::class TN5250TelnetProfile public
::attribute terminalType get
::attribute requestedDeviceName get
::attribute deviceName get
::attribute deviceNameCollisionCount get
::attribute collisionPolicy get
::attribute strictDeviceCollisionDetected get

::method init
  expose terminalType requestedDeviceName deviceName deviceNameCollisionCount collisionPolicy strictDeviceCollisionDetected deviceNamePrefix deviceNameSeed localOptions remoteOptions terminalTypeSent environmentSent
  use arg terminalTypeArg = "IBM-3179-2", deviceNameArg = "", collisionPolicyArg = "ADVANCE"
  terminalType = terminalTypeArg~string~strip~upper
  requestedDeviceName = deviceNameArg~string~strip~upper
  deviceName = requestedDeviceName
  deviceNameCollisionCount = 0
  collisionPolicy = .TN5250DeviceCollisionPolicy~normalize(collisionPolicyArg)
  if collisionPolicy == "" then collisionPolicy = .TN5250DeviceCollisionPolicy~ADVANCE
  strictDeviceCollisionDetected = .false
  deviceNamePrefix = requestedDeviceName
  deviceNameSeed = 0

  /* RFC enhanced-Telnet device names are at most ten characters.  For a
   * preferred name ending in four decimal digits, retain that sequence as the
   * collision seed (AIBOT0001 -> AIBOT0002).  Otherwise reserve four digits
   * for deterministic retry names (MYDEVICE -> MYDEVI0001). */
  if requestedDeviceName~length >= 4 then do
    tail = requestedDeviceName~right(4)
    if tail~datatype("W") then do
      deviceNameSeed = tail + 0
      deviceNamePrefix = requestedDeviceName~left(requestedDeviceName~length - 4)
    end
  end
  if deviceNamePrefix~length > 6 then deviceNamePrefix = deviceNamePrefix~left(6)

  localOptions = .table~new
  remoteOptions = .table~new
  terminalTypeSent = .false
  environmentSent = .false

::method supportedLocal private
  use arg option
  return option == .TelnetOption~BINARY | option == .TelnetOption~EOR | option == .TelnetOption~SGA | option == .TelnetOption~TERMINAL_TYPE | option == .TelnetOption~NEW_ENVIRON

::method supportedRemote private
  use arg option
  return option == .TelnetOption~BINARY | option == .TelnetOption~EOR | option == .TelnetOption~SGA

::method negotiate
  expose localOptions remoteOptions
  use arg command, option
  packets = .array~new
  select
    when command == .TelnetByte~DO then do
      if self~supportedLocal(option) then do
        localOptions~put(.true, option~c2x)
        packets~append(.TelnetCodec~command(.TelnetByte~WILL, option))
      end
      else packets~append(.TelnetCodec~command(.TelnetByte~WONT, option))
    end
    when command == .TelnetByte~WILL then do
      if self~supportedRemote(option) then do
        remoteOptions~put(.true, option~c2x)
        packets~append(.TelnetCodec~command(.TelnetByte~DO, option))
      end
      else packets~append(.TelnetCodec~command(.TelnetByte~DONT, option))
    end
    when command == .TelnetByte~DONT then do
      localOptions~remove(option~c2x)
      packets~append(.TelnetCodec~command(.TelnetByte~WONT, option))
    end
    when command == .TelnetByte~WONT then do
      remoteOptions~remove(option~c2x)
      packets~append(.TelnetCodec~command(.TelnetByte~DONT, option))
    end
  end
  return packets

::method subnegotiate
  expose terminalType deviceName terminalTypeSent environmentSent collisionPolicy strictDeviceCollisionDetected deviceNameCollisionCount
  use arg option, data
  packets = .array~new
  if option == .TelnetOption~TERMINAL_TYPE then do
    if data~length >= 1 & data~substr(1,1) == .TelnetTerminalType~SEND then do
      packetData = .TelnetTerminalType~IS || terminalType
      packets~append(.TelnetCodec~subnegotiation(.TelnetOption~TERMINAL_TYPE, packetData))
      terminalTypeSent = .true
    end
  end
  else if option == .TelnetOption~NEW_ENVIRON then do
    if data~length >= 1 & data~substr(1,1) == .TelnetNewEnviron~SEND then do
      /* RFC 2877/4777 collision processing: once DEVNAME has already been
       * supplied, a subsequent SEND USERVAR DEVNAME is a request to try a
       * different name.  Re-sending the same value permits the server to
       * disconnect the client. */
      if environmentSent & self~deviceNameRetryRequested(data) then do
        if collisionPolicy == .TN5250DeviceCollisionPolicy~STRICT then do
          deviceNameCollisionCount += 1
          strictDeviceCollisionDetected = .true
          /* A strict resume request means this exact device or nothing.  Do
           * not send an empty DEVNAME (which could trigger server assignment)
           * and do not resend the same value (which RFC collision processing
           * permits the server to disconnect).  The trusted live-session
           * wrapper observes this flag and closes the connection immediately. */
          return packets
        end
        self~advanceDeviceName
      end
      env = .TelnetNewEnviron~IS
      if deviceName \== "" then do
        env ||= .TelnetNewEnviron~USERVAR || "DEVNAME" || .TelnetNewEnviron~VALUE || deviceName
      end
      packets~append(.TelnetCodec~subnegotiation(.TelnetOption~NEW_ENVIRON, env))
      environmentSent = .true
    end
  end
  return packets

::method deviceNameRetryRequested private
  use arg data
  if data~length < 2 then return .false
  if data~substr(1,1) \== .TelnetNewEnviron~SEND then return .false
  request = data~substr(2)
  return request == (.TelnetNewEnviron~USERVAR || "DEVNAME")

::method advanceDeviceName private
  expose requestedDeviceName deviceName deviceNameCollisionCount deviceNamePrefix deviceNameSeed
  if requestedDeviceName == "" then return
  deviceNameCollisionCount += 1
  nextNumber = deviceNameSeed + deviceNameCollisionCount
  /* Four decimal digits gives 9,999 deterministic retries before wrap.  The
   * wrap is intentionally offset so the original preferred name is never
   * emitted as an immediate collision response. */
  nextNumber = nextNumber // 10000
  if nextNumber = 0 then nextNumber = 1
  suffix = right(nextNumber, 4, "0")
  deviceName = deviceNamePrefix || suffix

::method transparentReady
  expose localOptions remoteOptions terminalTypeSent
  if \terminalTypeSent then return .false
  if localOptions~at(.TelnetOption~BINARY~c2x) == .nil then return .false
  if localOptions~at(.TelnetOption~EOR~c2x) == .nil then return .false
  if remoteOptions~at(.TelnetOption~BINARY~c2x) == .nil then return .false
  if remoteOptions~at(.TelnetOption~EOR~c2x) == .nil then return .false
  return .true

::requires "TerminalCore.cls"
::requires "TelnetProtocol.cls"

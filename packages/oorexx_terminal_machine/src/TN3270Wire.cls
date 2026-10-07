/* TN3270 and basic TN3270E Telnet profile / record bridge.
 *
 * Traditional TN3270 remains available.  When RFC 2355 TN3270E negotiation
 * completes, records carry the mandatory five-byte TN3270E message header.
 * Candidate6 deliberately negotiates the null FUNCTIONS list (basic TN3270E):
 * terminal 3270-DATA/NVT-DATA only, with no RESPONSES/BIND/SYSREQ claims. */

::class TN3270ESubcommand public
::constant ASSOCIATE "00"x
::constant CONNECT "01"x
::constant DEVICE_TYPE "02"x
::constant FUNCTIONS "03"x
::constant IS "04"x
::constant REASON "05"x
::constant REJECT "06"x
::constant REQUEST "07"x
::constant SEND "08"x

::class TN3270EDataType public
::constant DATA_3270 "00"x
::constant SCS_DATA "01"x
::constant RESPONSE "02"x
::constant BIND_IMAGE "03"x
::constant UNBIND "04"x
::constant NVT_DATA "05"x
::constant REQUEST "06"x
::constant SSCP_LU_DATA "07"x
::constant PRINT_EOJ "08"x

::class TN3270EHeader public
::attribute dataType get
::attribute requestFlag get
::attribute responseFlag get
::attribute sequence get
::method init
  expose dataType requestFlag responseFlag sequence
  use arg dataTypeArg=.nil, requestArg="00"x, responseArg="00"x, sequenceArg=0
  if dataTypeArg==.nil then dataTypeArg=.TN3270EDataType~DATA_3270
  dataType=dataTypeArg; requestFlag=requestArg; responseFlag=responseArg; sequence=sequenceArg
::method bytes
  expose dataType requestFlag responseFlag sequence
  seq=sequence//65536
  return dataType||requestFlag||responseFlag||d2c(seq%256)||d2c(seq//256)
::method parse class
  use arg record
  if record~length<5 then return .TerminalResult~failure("TN3270E_TRUNCATED_HEADER",record~length)
  seq=x2d(record~substr(4,2)~c2x)
  h=self~new(record~substr(1,1),record~substr(2,1),record~substr(3,1),seq)
  return .TerminalResult~success(h)

::class TN3270ETelnetProfile public
::attribute terminalType get
::attribute requestedDeviceName get
::attribute deviceName get
::attribute deviceAccepted get
::attribute functionsAccepted get
::attribute tn3270eActive get
::attribute tn3270eOffered get
::method init
  expose terminalType requestedDeviceName deviceName deviceAccepted functionsAccepted tn3270eActive tn3270eOffered
  use arg typeArg="IBM-3278-2-E", deviceArg=""
  terminalType=typeArg~string~upper
  requestedDeviceName=deviceArg~string~upper
  deviceName=""; deviceAccepted=.false; functionsAccepted=.false; tn3270eActive=.false; tn3270eOffered=.false
::method supported private
  use arg option
  return option==.TelnetOption~BINARY | option==.TelnetOption~EOR | option==.TelnetOption~TERMINAL_TYPE | option==.TelnetOption~TN3270E
::method negotiate
  expose tn3270eOffered tn3270eActive deviceAccepted functionsAccepted
  use arg command, option
  out=.array~new
  if command==.TelnetByte~DO then do
    if self~supported(option) then do
      out~append(.TelnetCodec~command(.TelnetByte~WILL,option))
      if option==.TelnetOption~TN3270E then tn3270eOffered=.true
    end
    else out~append(.TelnetCodec~command(.TelnetByte~WONT,option))
  end
  else if command==.TelnetByte~WILL then do
    if self~supported(option) then out~append(.TelnetCodec~command(.TelnetByte~DO,option)); else out~append(.TelnetCodec~command(.TelnetByte~DONT,option))
  end
  else if command==.TelnetByte~DONT then do
    out~append(.TelnetCodec~command(.TelnetByte~WONT,option))
    if option==.TelnetOption~TN3270E then do; tn3270eOffered=.false; tn3270eActive=.false; deviceAccepted=.false; functionsAccepted=.false; end
  end
  else if command==.TelnetByte~WONT then do
    out~append(.TelnetCodec~command(.TelnetByte~DONT,option))
    if option==.TelnetOption~TN3270E then do; tn3270eActive=.false; deviceAccepted=.false; functionsAccepted=.false; end
  end
  return out
::method deviceRequest private
  expose terminalType requestedDeviceName
  payload=.TN3270ESubcommand~DEVICE_TYPE||.TN3270ESubcommand~REQUEST||terminalType
  if requestedDeviceName<>"" then payload||=.TN3270ESubcommand~CONNECT||requestedDeviceName
  return .TelnetCodec~subnegotiation(.TelnetOption~TN3270E,payload)
::method functionsRequest private
  /* Null list is deliberate: RFC 2355 basic TN3270E terminal session. */
  return .TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~REQUEST)
::method functionsIs private
  return .TelnetCodec~subnegotiation(.TelnetOption~TN3270E,.TN3270ESubcommand~FUNCTIONS||.TN3270ESubcommand~IS)
::method subnegotiate
  expose terminalType deviceName deviceAccepted functionsAccepted tn3270eActive tn3270eOffered
  use arg option,data
  out=.array~new
  if option==.TelnetOption~TERMINAL_TYPE then do
    if data~length>=1 & data~substr(1,1)==.TelnetTerminalType~SEND then out~append(.TelnetCodec~subnegotiation(option,.TelnetTerminalType~IS||terminalType))
    return out
  end
  if option<>.TelnetOption~TN3270E then return out
  if \tn3270eOffered then return out
  if data~length<2 then return out
  first=data~substr(1,1); second=data~substr(2,1)
  if first==.TN3270ESubcommand~SEND & second==.TN3270ESubcommand~DEVICE_TYPE then do
    out~append(self~deviceRequest); return out
  end
  if first==.TN3270ESubcommand~DEVICE_TYPE then do
    if second==.TN3270ESubcommand~IS then do
      rest=data~substr(3); marker=.TN3270ESubcommand~CONNECT; at=rest~pos(marker)
      if at>0 then deviceName=rest~substr(at+1); else deviceName=""
      deviceAccepted=.true
      out~append(self~functionsRequest)
    end
    else if second==.TN3270ESubcommand~REJECT then do
      deviceAccepted=.false; functionsAccepted=.false; tn3270eActive=.false
    end
    return out
  end
  if first==.TN3270ESubcommand~FUNCTIONS then do
    functions=data~substr(3)
    if second==.TN3270ESubcommand~REQUEST then do
      if functions~length==0 then do
        out~append(self~functionsIs); functionsAccepted=.true; tn3270eActive=deviceAccepted
      end
      else do
        /* We do not advertise functions we do not implement.  Counter with
         * the null list, which is the RFC-defined basic TN3270E mode. */
        out~append(self~functionsRequest); functionsAccepted=.false; tn3270eActive=.false
      end
    end
    else if second==.TN3270ESubcommand~IS then do
      if functions~length==0 & deviceAccepted then do; functionsAccepted=.true; tn3270eActive=.true; end
      else do; functionsAccepted=.false; tn3270eActive=.false; end
    end
    return out
  end
  return out

/* Compatibility class name retained for existing callers. */
::class TN3270TelnetProfile subclass TN3270ETelnetProfile public

::class TN3270Wire public
::method init
  expose telnet stream pendingRecords profile lastHeader nvtRecords
  use arg streamArg=.nil, profileArg=.nil
  if streamArg==.nil then stream=.DataStream3270~new; else stream=streamArg
  if profileArg==.nil then profileArg=.TN3270TelnetProfile~new
  profile=profileArg
  telnet=.TelnetMachine~new(profileArg)
  pendingRecords=""; lastHeader=.nil; nvtRecords=.array~new
::method tn3270eActive
  expose profile
  return profile~tn3270eActive
::method profile
  expose profile
  return profile
::method headerFor3270 private
  return .TN3270EHeader~new(.TN3270EDataType~DATA_3270,"00"x,"00"x,0)~bytes
::method decodeRecord private
  expose profile lastHeader nvtRecords
  use arg record
  if \profile~tn3270eActive then return .TerminalResult~success(record)
  parsed=.TN3270EHeader~parse(record); if \parsed~ok then return parsed
  h=parsed~value; lastHeader=h; payload=record~substr(6)
  if h~dataType==.TN3270EDataType~DATA_3270 then return .TerminalResult~success(payload)
  if h~dataType==.TN3270EDataType~NVT_DATA then do
    nvtRecords~append(payload)
    return .TerminalResult~success("TN3270E_NVT_DATA")
  end
  return .TerminalResult~failure("TN3270E_UNSUPPORTED_DATA_TYPE",h~dataType~c2x)
::method feed
  expose telnet stream pendingRecords profile
  use arg bytes
  telnet~feed(bytes); results=.array~new
  do ev over telnet~drainEvents
    if ev~eventType<>"RECORD" then iterate
    decoded=self~decodeRecord(ev~data)
    if \decoded~ok then do; results~append(decoded); iterate; end
    if decoded~value=="TN3270E_NVT_DATA" then do; results~append(decoded); iterate; end
    record=decoded~value
    applied=stream~applyHostRecord(record)
    results~append(applied)
    if applied~ok & record~length>0 then do
      cmd=record~substr(1,1)
      if cmd==.Command3270~READ_BUFFER | cmd==.Command3270~READ_MODIFIED | cmd==.Command3270~READ_MODIFIED_ALL then do
        response=stream~buildReadResponse(cmd)
        if response~ok then do
          payload=response~value
          if profile~tn3270eActive then payload=self~headerFor3270||payload
          pendingRecords||=.TelnetCodec~frameRecord(payload)
        end
      end
      else if cmd==.Command3270~WRITE_STRUCTURED_FIELD then do
        payload=stream~drainStructuredReply
        if payload~length>0 then do
          if profile~tn3270eActive then payload=self~headerFor3270||payload
          pendingRecords||=.TelnetCodec~frameRecord(payload)
        end
      end
    end
  end
  return results
::method drainOutbound
  expose telnet pendingRecords
  bytes=telnet~drainOutbound||pendingRecords
  pendingRecords=""
  return bytes
::method frameInput
  expose profile
  use arg bytes
  if profile~tn3270eActive then bytes=self~headerFor3270||bytes
  return .TelnetCodec~frameRecord(bytes)
::method drainNvtRecords
  expose nvtRecords
  out=nvtRecords; nvtRecords=.array~new; return out
::method lastHeader
  expose lastHeader
  return lastHeader
::method model
  expose stream
  return stream~model
::method stream
  expose stream
  return stream
::requires "TelnetProtocol.cls"
::requires "DataStream3270.cls"

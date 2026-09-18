/* Traditional TN3270 Telnet profile and record bridge. */
::class TN3270TelnetProfile public
::attribute terminalType get
::method init
  expose terminalType
  use arg typeArg="IBM-3278-2-E"
  terminalType=typeArg~string~upper
::method supported private
  use arg option
  return option==.TelnetOption~BINARY | option==.TelnetOption~EOR | option==.TelnetOption~TERMINAL_TYPE
::method negotiate
  use arg command, option
  out=.array~new
  if command==.TelnetByte~DO then do
    if self~supported(option) then out~append(.TelnetCodec~command(.TelnetByte~WILL,option)); else out~append(.TelnetCodec~command(.TelnetByte~WONT,option))
  end
  else if command==.TelnetByte~WILL then do
    if self~supported(option) then out~append(.TelnetCodec~command(.TelnetByte~DO,option)); else out~append(.TelnetCodec~command(.TelnetByte~DONT,option))
  end
  else if command==.TelnetByte~DONT then out~append(.TelnetCodec~command(.TelnetByte~WONT,option))
  else if command==.TelnetByte~WONT then out~append(.TelnetCodec~command(.TelnetByte~DONT,option))
  return out
::method subnegotiate
  expose terminalType
  use arg option,data
  out=.array~new
  if option==.TelnetOption~TERMINAL_TYPE & data~length>=1 & data~substr(1,1)==.TelnetTerminalType~SEND then out~append(.TelnetCodec~subnegotiation(option,.TelnetTerminalType~IS||terminalType))
  return out

::class TN3270Wire public
::method init
  expose telnet stream
  use arg streamArg=.nil, profileArg=.nil
  if streamArg==.nil then stream=.DataStream3270~new; else stream=streamArg
  if profileArg==.nil then profileArg=.TN3270TelnetProfile~new
  telnet=.TelnetMachine~new(profileArg)
::method feed
  expose telnet stream
  use arg bytes
  telnet~feed(bytes); results=.array~new
  do ev over telnet~drainEvents
    if ev~eventType=="RECORD" then results~append(stream~applyHostRecord(ev~data))
  end
  return results
::method drainOutbound
  expose telnet
  return telnet~drainOutbound
::method frameInput
  use arg bytes
  return .TelnetCodec~frameRecord(bytes)
::method model
  expose stream
  return stream~model
::method stream
  expose stream
  return stream
::requires "TelnetProtocol.cls"
::requires "DataStream3270.cls"

/* Generic Telnet byte-stream codec v0.1.
 *
 * This class is intentionally terminal-neutral.  A profile supplies which
 * options are accepted and any subnegotiation responses.
 */

::class TelnetByte public
::constant SE "F0"x
::constant NOP "F1"x
::constant DM "F2"x
::constant BRK "F3"x
::constant IP "F4"x
::constant AO "F5"x
::constant AYT "F6"x
::constant EC "F7"x
::constant EL "F8"x
::constant GA "F9"x
::constant SB "FA"x
::constant WILL "FB"x
::constant WONT "FC"x
::constant DO "FD"x
::constant DONT "FE"x
::constant IAC "FF"x
::constant EOR "EF"x

::class TelnetOption public
::constant BINARY "00"x
::constant SGA "03"x
::constant TERMINAL_TYPE "18"x
::constant EOR "19"x
::constant NEW_ENVIRON "27"x

::class TelnetTerminalType public
::constant IS "00"x
::constant SEND "01"x

::class TelnetNewEnviron public
::constant IS "00"x
::constant SEND "01"x
::constant INFO "02"x
::constant VAR "00"x
::constant VALUE "01"x
::constant ESC "02"x
::constant USERVAR "03"x

::class TelnetEvent public
::attribute eventType get
::attribute command get
::attribute option get
::attribute data get

::method init
  expose eventType command option data
  use arg eventTypeArg, commandArg = "", optionArg = "", dataArg = ""
  eventType = eventTypeArg~string~upper
  command = commandArg
  option = optionArg
  data = dataArg

::class TelnetCodec public
::method command class
  use arg commandByte, optionByte
  return .TelnetByte~IAC || commandByte || optionByte

::method subnegotiation class
  use arg optionByte, data = ""
  return .TelnetByte~IAC || .TelnetByte~SB || optionByte || self~escapeIac(data) || .TelnetByte~IAC || .TelnetByte~SE

::method escapeIac class
  use arg bytes
  return bytes~changestr(.TelnetByte~IAC, .TelnetByte~IAC || .TelnetByte~IAC)

::method frameRecord class
  use arg bytes
  return self~escapeIac(bytes) || .TelnetByte~IAC || .TelnetByte~EOR

/*
 * Incremental Telnet parser.  DATA records are emitted only at IAC EOR,
 * which is exactly what block-mode terminal personalities need.
 */
::class TelnetMachine public
::method init
  expose state pendingCommand subOption subBuffer applicationBuffer events outbound profile
  use arg profileArg
  state = "DATA"
  pendingCommand = ""
  subOption = ""
  subBuffer = ""
  applicationBuffer = ""
  events = .array~new
  outbound = .array~new
  profile = profileArg

::method feed
  expose state pendingCommand subOption subBuffer applicationBuffer events outbound profile
  use arg bytes
  do i = 1 to bytes~length
    octet = bytes~substr(i, 1)
    select
      when state == "DATA" then do
        if octet == .TelnetByte~IAC then state = "IAC"
        else applicationBuffer ||= octet
      end
      when state == "IAC" then do
        select
          when octet == .TelnetByte~IAC then do
            applicationBuffer ||= .TelnetByte~IAC
            state = "DATA"
          end
          when octet == .TelnetByte~EOR then do
            events~append(.TelnetEvent~new("RECORD", "", "", applicationBuffer))
            applicationBuffer = ""
            state = "DATA"
          end
          when octet == .TelnetByte~DO | octet == .TelnetByte~DONT | octet == .TelnetByte~WILL | octet == .TelnetByte~WONT then do
            pendingCommand = octet
            state = "NEGOTIATION_OPTION"
          end
          when octet == .TelnetByte~SB then state = "SUBNEGOTIATION_OPTION"
          otherwise do
            events~append(.TelnetEvent~new("COMMAND", octet))
            state = "DATA"
          end
        end
      end
      when state == "NEGOTIATION_OPTION" then do
        events~append(.TelnetEvent~new("NEGOTIATION", pendingCommand, octet))
        responses = profile~negotiate(pendingCommand, octet)
        do response over responses
          outbound~append(response)
        end
        pendingCommand = ""
        state = "DATA"
      end
      when state == "SUBNEGOTIATION_OPTION" then do
        subOption = octet
        subBuffer = ""
        state = "SUBNEGOTIATION_DATA"
      end
      when state == "SUBNEGOTIATION_DATA" then do
        if octet == .TelnetByte~IAC then state = "SUBNEGOTIATION_IAC"
        else subBuffer ||= octet
      end
      when state == "SUBNEGOTIATION_IAC" then do
        if octet == .TelnetByte~SE then do
          events~append(.TelnetEvent~new("SUBNEGOTIATION", "", subOption, subBuffer))
          responses = profile~subnegotiate(subOption, subBuffer)
          do response over responses
            outbound~append(response)
          end
          subOption = ""
          subBuffer = ""
          state = "DATA"
        end
        else if octet == .TelnetByte~IAC then do
          subBuffer ||= .TelnetByte~IAC
          state = "SUBNEGOTIATION_DATA"
        end
        else do
          /* Preserve an unexpected IAC sequence inside SB as evidence. */
          subBuffer ||= .TelnetByte~IAC || octet
          state = "SUBNEGOTIATION_DATA"
        end
      end
      otherwise raise syntax 88.900 array("Unknown Telnet parser state " || state)
    end
  end
  return self

::method drainEvents
  expose events
  eventsOut = events
  events = .array~new
  return eventsOut

::method drainOutbound
  expose outbound
  bytesOut = ""
  do packet over outbound
    bytesOut ||= packet
  end
  outbound = .array~new
  return bytesOut

::method parserState
  expose state
  return state

/*
 * Explicit local-operator TN5250 login acceptance probe.
 *
 * This tool requires a previously persisted known-state catalog and will only
 * stage credentials when the live screen matches IBM_I_SIGNON exactly under
 * that catalog.  Password input is read from /dev/tty with echo disabled; it is
 * never accepted on argv or in an environment variable.
 *
 * It stages credentials and then issues ENTER as two distinct operations.  It
 * does not execute any post-login command.
 *
 * Usage:
 *   rexx pub400_login_once.rex known_states.json [host [port [deviceName [seconds]]]]
 */
signal on halt name UserHalt
parse arg statePath host port deviceName seconds
if statePath = "" then do
  say "usage: rexx pub400_login_once.rex known_states.json [host [port [deviceName [seconds]]]]"
  say "First learn the sign-on state with:"
  say "  rexx pub400_probe.rex pub400.com 992 '' 30 known_states.json"
  exit 2
end
if host = "" then host = "pub400.com"
if port = "" then port = 992
if deviceName = "" then deviceName = ""
if seconds = "" then seconds = 30
if \seconds~datatype("W") | seconds < 1 then do
  say "seconds must be a positive integer"
  exit 2
end

loaded = .KnownStateJsonStore~load(statePath)
if \loaded~ok then do
  say "KNOWN STATE LOAD FAIL" loaded~code loaded~detail
  exit 3
end
catalog = loaded~value
if catalog~state("IBM_I_SIGNON") == .nil then do
  say "KNOWN STATE CATALOG does not contain IBM_I_SIGNON"
  exit 3
end

runtime = .TN5250RuntimeSession~new("LIVE-LOGIN", "IBM-3179-2", deviceName)
client = runtime~automationPort
transport = .SocatTlsTerminalTransport~new(host, port, .true)
opened = transport~open
if \opened~ok then do
  say "TLS OPEN FAIL" opened~code opened~detail
  exit 4
end

say "TN5250 EXPLICIT LOGIN ACCEPTANCE"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
if transport~caFile \= "" then say "TLS trust=" || transport~trustSource "cafile=" || transport~caFile
else if transport~caPath \= "" then say "TLS trust=" || transport~trustSource "capath=" || transport~caPath
say "Known-state catalog=" || statePath
say "No post-login command will be sent."

initialGeneration = 0
signon = .nil
exitCode = 5

do tick = 1 to seconds
  received = transport~receiveBytesWait(16384, 1)
  if \received~ok then do
    if received~code = "TRANSPORT_TIMEOUT" then iterate
    say "RECEIVE FAIL" received~code received~detail
    exitCode = 6
    leave
  end
  if received~value~length = 0 then do
    say "REMOTE CLOSED CONNECTION"
    exitCode = 7
    leave
  end
  fed = runtime~feedNetwork(received~value)
  if \fed~ok then do
    say "TERMINAL FAIL" fed~code fed~detail
    exitCode = 8
    leave
  end
  if fed~value~outboundBytes~length > 0 then do
    sent = transport~sendBytes(fed~value~outboundBytes)
    if \sent~ok then do
      say "SEND FAIL" sent~code sent~detail
      exitCode = 9
      leave
    end
  end
  snap = fed~value~snapshot
  if snap == .nil | snap~generation < 1 then iterate
  m = catalog~match(snap)
  if m~status == .TerminalMatchStatus~MATCH & m~matchedStateId == "IBM_I_SIGNON" then do
    signon = snap
    initialGeneration = snap~generation
    exitCode = 0
    leave
  end
end

if exitCode \= 0 then do
  if exitCode = 5 then say "Timed out without matching known state IBM_I_SIGNON. Credentials were not requested."
  ignore = transport~close
  exit exitCode
end

say ""
say "MATCH IBM_I_SIGNON generation=" || signon~generation
say "NEGOTIATED_DEVICE=" || runtime~negotiatedDeviceName || " collisions=" || runtime~deviceNameCollisionCount
call printScreen signon
identityResult = .TN5250DeviceIdentity~observeSignon(signon, deviceName, runtime~negotiatedDeviceName)
if identityResult~ok then do
  identity = identityResult~value
  say "HOST_DISPLAY_DEVICE=" || identity~assignedDeviceName || " effective=" || identity~effectiveDeviceName || " source=" || identity~source
end

call charout , "IBM i user profile: "
parse pull userName
if userName~strip = "" then do
  say "Empty user profile; aborting without AID."
  ignore = transport~close
  exit 10
end
password = readHiddenPassword()
if password == .nil then do
  say "Could not read password securely from /dev/tty."
  ignore = transport~close
  exit 11
end

provider = .OneShotCredentialProvider~new("LOCAL_INTERACTIVE", userName, password)
password = ""
broker = .TerminalCredentialBroker~new(provider)
staged = .TN5250CredentialLogin~stage(runtime, broker, catalog, "LOCAL_INTERACTIVE", "IBM_I_SIGNON")
if \staged~ok then do
  say "CREDENTIAL STAGE FAIL" staged~code staged~detail
  ignore = transport~close
  exit 12
end
say "Credential staged into fields" staged~value~userFieldId "and" staged~value~passwordFieldId
say "Observer password value=" || staged~value~snapshot~field(staged~value~passwordFieldId)~value

/* Submission remains an explicit, separate operation. */
g = client~snapshot~generation
pressed = client~press(g, "ENTER", "LOCAL_OPERATOR")
if \pressed~ok then do
  say "ENTER FAIL" pressed~code pressed~detail
  ignore = transport~close
  exit 13
end
wire = runtime~drainTerminalOutput
if \wire~ok then do
  say "WIRE BUILD FAIL" wire~code wire~detail
  ignore = transport~close
  exit 14
end
if wire~value~length = 0 then do
  say "ENTER produced no terminal output; aborting."
  ignore = transport~close
  exit 15
end
sent = transport~sendBytes(wire~value)
if \sent~ok then do
  say "SEND FAIL" sent~code sent~detail
  ignore = transport~close
  exit 16
end
say "ENTER sent. Waiting for the first host screen change; no further input will be sent."

lastPrinted = initialGeneration
do tick = 1 to seconds
  received = transport~receiveBytesWait(16384, 1)
  if \received~ok then do
    if received~code = "TRANSPORT_TIMEOUT" then iterate
    say "RECEIVE FAIL" received~code received~detail
    exitCode = 17
    leave
  end
  if received~value~length = 0 then do
    say "REMOTE CLOSED CONNECTION"
    exitCode = 18
    leave
  end
  fed = runtime~feedNetwork(received~value)
  if \fed~ok then do
    say "TERMINAL FAIL" fed~code fed~detail
    exitCode = 19
    leave
  end
  /* Host-driven Query/control replies are allowed; no operator input/AID is. */
  if fed~value~outboundBytes~length > 0 then do
    sent = transport~sendBytes(fed~value~outboundBytes)
    if \sent~ok then do
      say "SEND FAIL" sent~code sent~detail
      exitCode = 20
      leave
    end
  end
  snap = fed~value~snapshot
  if snap \== .nil & snap~generation > lastPrinted then do
    say ""
    say "POST-LOGIN HOST SCREEN generation=" || snap~generation
    call printScreen snap
    postMatch = catalog~match(snap)
    say "KNOWN_STATE=" || postMatch~status || " " || postMatch~matchedStateId
    say "NO POST-LOGIN COMMAND SENT"
    exitCode = 0
    leave
  end
end

if exitCode = 0 & runtime~snapshot~generation <= initialGeneration then do
  say "Timed out waiting for a host screen change after ENTER."
  exitCode = 21
end
ignore = transport~close
exit exitCode

printScreen: procedure
  use arg snap
  say "SCREEN generation=" || snap~generation,
      "keyboard=" || snap~keyboardState,
      "session=" || snap~sessionState,
      "cursor=" || snap~cursorRow || "," || snap~cursorColumn
  say copies("-", snap~columns)
  do r = 1 to snap~rows
    line = snap~rowText(r)
    if line~strip \= "" then say right(r, 2) || " " || line
  end
  say copies("-", snap~columns)
  say "FIELDS=" || snap~fields~items
  do f over snap~fields
    flags = ""
    if f~inputCapable then flags ||= " INPUT"
    if f~protected then flags ||= " PROTECTED"
    if f~nonDisplay then flags ||= " NONDISPLAY"
    say f~fieldId "r" || f~row "c" || f~column "len=" || f~length || flags "value=" || f~displayValue
  end
  return

readHiddenPassword: procedure
  signal on syntax name hiddenFailed
  signal on halt name hiddenHalt
  address system "test -r /dev/tty && test -w /dev/tty"
  if rc \= 0 then return .nil
  call charout , "Password: "
  address system "stty -echo < /dev/tty"
  if rc \= 0 then return .nil
  passwordLine = linein("/dev/tty")
  address system "stty echo < /dev/tty"
  say ""
  return passwordLine
hiddenFailed:
  address system "stty echo < /dev/tty >/dev/null 2>&1"
  return .nil
hiddenHalt:
  address system "stty echo < /dev/tty >/dev/null 2>&1"
  return .nil

UserHalt:
  say "INTERRUPTED - closing TLS transport and helper"
  if symbol("TRANSPORT") == "VAR" then do
    if transport \== .nil then do
      closedOnHalt = transport~close
      if \closedOnHalt~ok then say "TLS CLOSE FAIL" closedOnHalt~code closedOnHalt~detail
    end
  end
  exit 130

::requires "../src/TN5250CredentialLogin.cls"
::requires "../src/TerminalTransport.cls"

::requires "../src/TN5250DeviceIdentity.cls"

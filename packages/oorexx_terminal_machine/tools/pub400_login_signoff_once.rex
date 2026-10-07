/*
 * Local-operator PUB400 login followed by one confirmed orderly signoff.
 *
 * Credentials are requested only after IBM_I_SIGNON matches.  After ENTER the
 * only accepted continuation is IBM_I_MAIN_MENU; only then is menu option 90
 * staged and submitted.  Any other host state receives no further input.
 * Passwords are read only from /dev/tty with echo disabled.
 *
 * Usage:
 *   rexx pub400_login_signoff_once.rex known_states.json [host [port [deviceName [seconds]]]]
 */
signal on halt name UserHalt
parse arg statePath host port deviceName seconds
if statePath = "" then do
  say "usage: rexx pub400_login_signoff_once.rex known_states.json [host [port [deviceName [seconds]]]]"
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
if \loaded~ok then do; say "KNOWN STATE LOAD FAIL" loaded~code loaded~detail; exit 3; end
catalog = loaded~value
do requiredState over .array~of("IBM_I_SIGNON", "IBM_I_MAIN_MENU")
  if catalog~state(requiredState) == .nil then do
    say "KNOWN STATE CATALOG missing" requiredState
    exit 3
  end
end

if deviceName~strip = "" then collisionPolicy = "ADVANCE"
else collisionPolicy = "STRICT"
runtime = .TN5250RuntimeSession~new("LIVE-LOGIN-SIGNOFF", "IBM-3179-2", deviceName, 64, .nil, collisionPolicy)
semanticAttach = runtime~attachKnownStateCatalog(catalog, 16)
if \semanticAttach~ok then do; say "SEMANTIC TRACKER ATTACH FAIL" semanticAttach~code semanticAttach~detail; exit 3; end
client = runtime~automationPort
transport = .SocatTlsTerminalTransport~new(host, port, .true)
opened = transport~open
if \opened~ok then do; say "TLS OPEN FAIL" opened~code opened~detail; exit 4; end

say "TN5250 LOGIN + ORDERLY SIGNOFF"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
if deviceName~strip = "" then say "device=SERVER_ASSIGNED"
else say "requested device=" || deviceName~upper "collision policy=STRICT"
if transport~caFile \= "" then say "TLS trust=" || transport~trustSource "cafile=" || transport~caFile
else if transport~caPath \= "" then say "TLS trust=" || transport~trustSource "capath=" || transport~caPath
say "Only confirmed IBM_I_MAIN_MENU may receive option 90 + ENTER."

signonResult = waitForKnown(runtime, transport, catalog, "IBM_I_SIGNON", seconds)
if \signonResult~ok then do
  say "SIGN-ON WAIT FAIL" signonResult~code signonResult~detail
  ignore = transport~close
  exit 5
end
signon = signonResult~value
say ""
say "MATCH IBM_I_SIGNON generation=" || signon~generation
call printScreen signon
identityResult = .TN5250DeviceIdentity~observeSignon(signon, deviceName, runtime~negotiatedDeviceName)
if identityResult~ok then do
  identity = identityResult~value
  say "HOST_DISPLAY_DEVICE=" || identity~assignedDeviceName || " effective=" || identity~effectiveDeviceName || " source=" || identity~source
end
semanticObserver = runtime~observationPort
say "SEMANTIC_STATE=" || semanticObserver~knownStateStatus || " " || semanticObserver~knownStateId || " generation=" || semanticObserver~knownStateGeneration

call charout , "IBM i user profile: "
parse pull userName
userName = userName~strip
if userName = "" then do; say "Empty user profile; aborting without AID."; ignore = transport~close; exit 10; end
password = readHidden("Password: ")
if password == .nil then do; say "Could not read password securely from /dev/tty."; ignore = transport~close; exit 11; end
provider = .OneShotCredentialProvider~new("LOCAL_INTERACTIVE", userName, password)
password = ""
broker = .TerminalCredentialBroker~new(provider)
staged = .TN5250CredentialLogin~stage(runtime, broker, catalog, "LOCAL_INTERACTIVE", "IBM_I_SIGNON")
if \staged~ok then do; say "CREDENTIAL STAGE FAIL" staged~code staged~detail; ignore = transport~close; exit 12; end
say "Credentials staged; observer password=" || staged~value~snapshot~field(staged~value~passwordFieldId)~value

beforeLogin = runtime~snapshot~generation
sentLogin = sendAid(runtime, client, transport, "ENTER", "LOCAL_OPERATOR")
if \sentLogin~ok then do; say "LOGIN ENTER FAIL" sentLogin~code sentLogin~detail; ignore = transport~close; exit 13; end
say "ENTER #1 sent. Waiting for first changed host screen."
postResult = waitNextGeneration(runtime, transport, beforeLogin, seconds)
if \postResult~ok then do; say "POST-LOGIN WAIT FAIL" postResult~code postResult~detail; ignore = transport~close; exit 14; end
post = postResult~value
say ""
say "POST-LOGIN HOST SCREEN generation=" || post~generation
call printScreen post
postMatch = catalog~match(post)
say "KNOWN_STATE=" || postMatch~status || " " || postMatch~matchedStateId
semanticObserver = runtime~observationPort
say "SEMANTIC_STATE=" || semanticObserver~knownStateStatus || " " || semanticObserver~knownStateId || " generation=" || semanticObserver~knownStateGeneration
if postMatch~status \== .TerminalMatchStatus~MATCH | postMatch~matchedStateId \== "IBM_I_MAIN_MENU" then do
  say "NO POST-LOGIN COMMAND SENT"
  say "Host did not reach confirmed IBM_I_MAIN_MENU; closing connection."
  ignore = transport~close
  exit 0
end

signoff = .TN5250Signoff~stage90(runtime, catalog, "IBM_I_MAIN_MENU")
if \signoff~ok then do; say "SIGNOFF STAGE FAIL" signoff~code signoff~detail; ignore = transport~close; exit 15; end
say "ORDERLY SIGNOFF: staged option 90 into" signoff~value~commandFieldId
beforeSignoff = runtime~snapshot~generation
sentSignoff = sendAid(runtime, client, transport, "ENTER", "LOCAL_SIGNOFF")
if \sentSignoff~ok then do; say "SIGNOFF ENTER FAIL" sentSignoff~code sentSignoff~detail; ignore = transport~close; exit 16; end
say "ENTER #2 sent for option 90. No further input will be sent."

signoffWait = waitForSignoff(runtime, transport, beforeSignoff, 10)
if \signoffWait~ok then do; say "SIGNOFF WAIT FAIL" signoffWait~code signoffWait~detail; ignore = transport~close; exit 17; end
summary = signoffWait~value
if summary["kind"] == "REMOTE_CLOSED" then say "SIGNOFF RESULT: remote closed the TN5250 connection."
else do
  snap = summary["snapshot"]
  say "SIGNOFF RESULT generation=" || snap~generation
  call printScreen snap
end
closed = transport~close
if \closed~ok then do; say "TLS CLOSE FAIL" closed~code closed~detail; exit 18; end
say "ORDERLY SIGNOFF COMPLETE; TLS helper closed."
exit 0

waitForKnown: procedure
  use arg runtime, transport, catalog, stateId, seconds
  do tick = 1 to seconds
    step = receiveFeed(runtime, transport, 1)
    if \step~ok then do
      if step~code == "TRANSPORT_TIMEOUT" then iterate
      return step
    end
    snap = step~value
    if snap == .nil then iterate
    if snap~generation < 1 then iterate
    matched = catalog~match(snap)
    if matched~status == .TerminalMatchStatus~MATCH then do
      if matched~matchedStateId == stateId then return .TerminalResult~success(snap)
    end
  end
  return .TerminalResult~failure("KNOWN_STATE_TIMEOUT", stateId)

waitNextGeneration: procedure
  use arg runtime, transport, generationArg, seconds
  do tick = 1 to seconds
    step = receiveFeed(runtime, transport, 1)
    if \step~ok then do
      if step~code == "TRANSPORT_TIMEOUT" then iterate
      return step
    end
    snap = step~value
    if snap == .nil then iterate
    if snap~generation > generationArg then return .TerminalResult~success(snap)
  end
  return .TerminalResult~failure("SCREEN_CHANGE_TIMEOUT", "generation=" || generationArg)

waitForSignoff: procedure
  use arg runtime, transport, generationArg, seconds
  do tick = 1 to seconds
    step = receiveFeed(runtime, transport, 1)
    if \step~ok then do
      if step~code == "TRANSPORT_TIMEOUT" then iterate
      if step~code == "REMOTE_CLOSED" then do
        d = .directory~new; d["kind"] = "REMOTE_CLOSED"; d["snapshot"] = .nil
        return .TerminalResult~success(d)
      end
      return step
    end
    snap = step~value
    if snap == .nil then iterate
    if snap~generation > generationArg then do
      d = .directory~new; d["kind"] = "SCREEN_CHANGED"; d["snapshot"] = snap
      return .TerminalResult~success(d)
    end
  end
  return .TerminalResult~failure("SIGNOFF_TIMEOUT", "generation=" || generationArg)

receiveFeed: procedure
  use arg runtime, transport, timeoutSeconds
  received = transport~receiveBytesWait(16384, timeoutSeconds)
  if \received~ok then return received
  if received~value~length = 0 then return .TerminalResult~failure("REMOTE_CLOSED", "remote closed connection")
  fed = runtime~feedNetwork(received~value)
  if \fed~ok then return fed
  if runtime~strictDeviceCollisionDetected then return .TerminalResult~failure("TN5250_DEVICE_COLLISION", runtime~negotiatedDeviceName)
  if fed~value~outboundBytes~length > 0 then do
    sent = transport~sendBytes(fed~value~outboundBytes)
    if \sent~ok then return sent
  end
  return .TerminalResult~success(fed~value~snapshot)

sendAid: procedure
  use arg runtime, client, transport, aidName, actor
  generation = client~snapshot~generation
  pressed = client~press(generation, aidName, actor)
  if \pressed~ok then return pressed
  wire = runtime~drainTerminalOutput
  if \wire~ok then return wire
  if wire~value~length = 0 then return .TerminalResult~failure("AID_NO_OUTPUT", aidName)
  sent = transport~sendBytes(wire~value)
  if \sent~ok then return sent
  return .TerminalResult~success(.true)

printScreen: procedure
  use arg snap
  say "SCREEN generation=" || snap~generation "keyboard=" || snap~keyboardState "session=" || snap~sessionState "cursor=" || snap~cursorRow || "," || snap~cursorColumn
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

readHidden: procedure
  use arg promptText
  signal on syntax name hiddenFailed
  signal on halt name hiddenHalt
  address system "test -r /dev/tty && test -w /dev/tty"
  if rc \= 0 then return .nil
  call charout , promptText
  address system "stty -echo < /dev/tty"
  if rc \= 0 then return .nil
  secretLine = linein("/dev/tty")
  address system "stty echo < /dev/tty"
  say ""
  return secretLine
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

::requires "../src/TN5250Signoff.cls"
::requires "../src/TN5250CredentialLogin.cls"
::requires "../src/TerminalTransport.cls"

::requires "../src/TN5250DeviceIdentity.cls"

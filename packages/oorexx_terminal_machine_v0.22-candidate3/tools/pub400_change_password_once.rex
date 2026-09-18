/*
 * Local-operator IBM i expired-password recovery for PUB400.
 *
 * Security/authority properties:
 *   - existing/current and new passwords are read only from /dev/tty with echo off;
 *   - no password is accepted through argv or environment variables;
 *   - login credentials are staged only after exact IBM_I_SIGNON match;
 *   - the confirmed PUB400 state order is mandatory:
 *       IBM_I_SIGNON -> IBM_I_PASSWORD_EXPIRED_NOTICE -> IBM_I_CHANGE_PASSWORD;
 *   - new-password material is requested only after that exact three-state sequence;
 *   - current/new/verify are staged transactionally into host NONDISPLAY fields;
 *   - the password-change ENTER is a separate action;
 *   - after a confirmed IBM_I_MAIN_MENU result, the only permitted post-change action is explicit menu option 90 (Sign off) followed by ENTER;
 *   - any other result is observed and closed with no further terminal input;
 *   - an explicit DEVNAME uses STRICT collision policy: exact device or abort.
 *
 * Usage:
 *   rexx pub400_change_password_once.rex known_states.json [host [port [deviceName [seconds]]]]
 */
signal on halt name UserHalt
parse arg statePath host port deviceName seconds
if statePath = "" then do
  say "usage: rexx pub400_change_password_once.rex known_states.json [host [port [deviceName [seconds]]]]"
  exit 2
end
if host = "" then host = "pub400.com"
if port = "" then port = 992
if deviceName = "" then deviceName = ""
if seconds = "" then seconds = 45
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
do requiredState over .array~of("IBM_I_SIGNON", "IBM_I_PASSWORD_EXPIRED_NOTICE", "IBM_I_CHANGE_PASSWORD", "IBM_I_MAIN_MENU")
  if catalog~state(requiredState) == .nil then do
    say "KNOWN STATE CATALOG missing" requiredState
    exit 3
  end
end

flow = .TN5250PasswordExpiryFlow~new(catalog)

if deviceName~strip = "" then collisionPolicy = "ADVANCE"
else collisionPolicy = "STRICT"
runtime = .TN5250RuntimeSession~new("LIVE-PASSWORD-CHANGE", "IBM-3179-2", deviceName, 64, .nil, collisionPolicy)
semanticAttach = runtime~attachKnownStateCatalog(catalog, 16)
if \semanticAttach~ok then do; say "SEMANTIC TRACKER ATTACH FAIL" semanticAttach~code semanticAttach~detail; exit 3; end
client = runtime~automationPort
transport = .SocatTlsTerminalTransport~new(host, port, .true)
opened = transport~open
if \opened~ok then do
  say "TLS OPEN FAIL" opened~code opened~detail
  exit 4
end

say "TN5250 LOCAL PASSWORD-CHANGE RECOVERY"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
if deviceName~strip = "" then say "device=SERVER_ASSIGNED"
else say "requested device=" || deviceName~upper "collision policy=STRICT"
if transport~caFile \= "" then say "TLS trust=" || transport~trustSource "cafile=" || transport~caFile
else if transport~caPath \= "" then say "TLS trust=" || transport~trustSource "capath=" || transport~caPath
say "Known-state catalog=" || statePath
say "Post-change policy: only confirmed IBM_I_MAIN_MENU may receive option 90 + ENTER for orderly signoff."

signonResult = waitForKnown(runtime, transport, catalog, "IBM_I_SIGNON", seconds)
if \signonResult~ok then do
  say "SIGN-ON WAIT FAIL" signonResult~code signonResult~detail
  ignore = transport~close
  exit 5
end
signon = signonResult~value
say ""
say "MATCH IBM_I_SIGNON generation=" || signon~generation
say "NEGOTIATED_DEVICE=" || runtime~negotiatedDeviceName || " collisions=" || runtime~deviceNameCollisionCount
call printScreen signon
identityResult = .TN5250DeviceIdentity~observeSignon(signon, deviceName, runtime~negotiatedDeviceName)
if identityResult~ok then do
  identity = identityResult~value
  say "HOST_DISPLAY_DEVICE=" || identity~assignedDeviceName || " effective=" || identity~effectiveDeviceName || " source=" || identity~source
end
semanticObserver = runtime~observationPort
say "SEMANTIC_STATE=" || semanticObserver~knownStateStatus || " " || semanticObserver~knownStateId || " generation=" || semanticObserver~knownStateGeneration

flowSignon = flow~observe(signon)
if \flowSignon~ok then do
  say "PASSWORD-EXPIRY FLOW FAIL" flowSignon~code flowSignon~detail
  ignore = transport~close
  exit 6
end
say "FLOW 1/3 IBM_I_SIGNON confirmed; ENTER #1 will submit staged sign-on credentials."

call charout , "IBM i user profile: "
parse pull userName
userName = userName~strip
if userName = "" then do
  say "Empty user profile; aborting without AID."
  ignore = transport~close
  exit 10
end
currentPassword = readHidden("Current password: ")
if currentPassword == .nil then do
  say "Could not read current password securely from /dev/tty."
  ignore = transport~close
  exit 11
end

/* Keep the local currentPassword only because IBM i asks for it again on the
 * Change Password panel.  The one-shot provider independently forgets its copy
 * after sign-on staging. */
provider = .OneShotCredentialProvider~new("LOCAL_INTERACTIVE", userName, currentPassword)
broker = .TerminalCredentialBroker~new(provider)
stagedLogin = .TN5250CredentialLogin~stage(runtime, broker, catalog, "LOCAL_INTERACTIVE", "IBM_I_SIGNON")
if \stagedLogin~ok then do
  currentPassword = ""
  say "CREDENTIAL STAGE FAIL" stagedLogin~code stagedLogin~detail
  ignore = transport~close
  exit 12
end
say "Sign-on credential staged into" stagedLogin~value~userFieldId "and" stagedLogin~value~passwordFieldId
say "Observer password value=" || stagedLogin~value~snapshot~field(stagedLogin~value~passwordFieldId)~value

beforeLogin = runtime~snapshot~generation
sentLogin = sendAid(runtime, client, transport, "ENTER", "LOCAL_OPERATOR")
if \sentLogin~ok then do
  currentPassword = ""
  say "SIGN-ON ENTER FAIL" sentLogin~code sentLogin~detail
  ignore = transport~close
  exit 13
end
postLoginResult = waitNextGeneration(runtime, transport, beforeLogin, seconds)
if \postLoginResult~ok then do
  currentPassword = ""
  say "POST-LOGIN WAIT FAIL" postLoginResult~code postLoginResult~detail
  ignore = transport~close
  exit 14
end
postLogin = postLoginResult~value
say ""
say "POST-LOGIN HOST SCREEN generation=" || postLogin~generation
call printScreen postLogin
postMatch = catalog~match(postLogin)
say "KNOWN_STATE=" || postMatch~status || " " || postMatch~matchedStateId

if postMatch~status \== .TerminalMatchStatus~MATCH then do
  currentPassword = ""
  say "Authentication did not reach a uniquely confirmed host state."
  say "Expected IBM_I_PASSWORD_EXPIRED_NOTICE after ENTER #1; no password-change data was requested or sent."
  ignore = transport~close
  exit 21
end

flowNotice = flow~observe(postLogin)
if \flowNotice~ok then do
  currentPassword = ""
  say "PASSWORD-EXPIRY FLOW FAIL" flowNotice~code flowNotice~detail
  if postMatch~matchedStateId == "IBM_I_SIGNON" then say "Host remained on sign-on; authentication was not accepted or was blocked by session policy."
  else if postMatch~matchedStateId == "IBM_I_CHANGE_PASSWORD" then say "PUB400 skipped the confirmed password-expired notice; refusing to weaken the learned flow."
  say "No password-change data was requested or sent."
  ignore = transport~close
  exit 20
end
say "FLOW 2/3 IBM_I_PASSWORD_EXPIRED_NOTICE confirmed; ENTER #2 will request the changer."

beforeExpiry = postLogin~generation
sentExpiry = sendAid(runtime, client, transport, "ENTER", "LOCAL_OPERATOR")
if \sentExpiry~ok then do
  currentPassword = ""
  say "PASSWORD-EXPIRED ENTER FAIL" sentExpiry~code sentExpiry~detail
  ignore = transport~close
  exit 15
end
changeResult = waitNextGeneration(runtime, transport, beforeExpiry, seconds)
if \changeResult~ok then do
  currentPassword = ""
  say "CHANGE-PASSWORD WAIT FAIL" changeResult~code changeResult~detail
  ignore = transport~close
  exit 16
end
changeSnap = changeResult~value

changeMatch = catalog~match(changeSnap)
say ""
say "PASSWORD-CHANGE CANDIDATE generation=" || changeSnap~generation
call printScreen changeSnap
say "KNOWN_STATE=" || changeMatch~status || " " || changeMatch~matchedStateId
if changeMatch~status \== .TerminalMatchStatus~MATCH then do
  currentPassword = ""
  say "Refusing: change-password state is not uniquely confirmed."
  ignore = transport~close
  exit 22
end
if changeMatch~matchedStateId \== "IBM_I_CHANGE_PASSWORD" then do
  currentPassword = ""
  say "Refusing: expected IBM_I_CHANGE_PASSWORD, got" changeMatch~matchedStateId
  ignore = transport~close
  exit 23
end
flowChange = flow~observe(changeSnap)
if \flowChange~ok then do
  currentPassword = ""
  say "PASSWORD-EXPIRY FLOW FAIL" flowChange~code flowChange~detail
  ignore = transport~close
  exit 23
end
if \flow~readyForPasswordChange then do
  currentPassword = ""
  say "PASSWORD-EXPIRY FLOW FAIL: sequence did not reach password-change readiness"
  ignore = transport~close
  exit 23
end
say "FLOW 3/3 IBM_I_CHANGE_PASSWORD confirmed; new password may now be acquired locally."

/* Only now, after semantic + structured field confirmation and exact live sequence, acquire new secret. */
newPassword = readHidden("New password: ")
if newPassword == .nil then do
  currentPassword = ""
  say "Could not read new password securely from /dev/tty."
  ignore = transport~close
  exit 24
end
verifyPassword = readHidden("New password (verify): ")
if verifyPassword == .nil then do
  currentPassword = ""
  newPassword = ""
  say "Could not read verification password securely from /dev/tty."
  ignore = transport~close
  exit 25
end
if newPassword = "" then do
  currentPassword = ""; newPassword = ""; verifyPassword = ""
  say "New password is empty; nothing sent."
  ignore = transport~close
  exit 26
end
if newPassword \== verifyPassword then do
  currentPassword = ""; newPassword = ""; verifyPassword = ""
  say "New password entries do not match; nothing sent."
  ignore = transport~close
  exit 27
end
verifyPassword = ""

pwLease = .TN5250PasswordChangeLease~new("LOCAL_PASSWORD_CHANGE", currentPassword, newPassword)
currentPassword = ""
newPassword = ""
stagedChange = .TN5250PasswordChange~stage(runtime, catalog, pwLease, "IBM_I_CHANGE_PASSWORD")
if \stagedChange~ok then do
  say "PASSWORD CHANGE STAGE FAIL" stagedChange~code stagedChange~detail
  ignore = transport~close
  exit 28
end
say "Password values staged transactionally into fields" stagedChange~value~currentFieldId || "," stagedChange~value~newFieldId || "," stagedChange~value~verifyFieldId
say "Observer values=" || stagedChange~value~snapshot~field(stagedChange~value~currentFieldId)~value || "," ||,
    stagedChange~value~snapshot~field(stagedChange~value~newFieldId)~value || "," ||,
    stagedChange~value~snapshot~field(stagedChange~value~verifyFieldId)~value

beforeChange = runtime~snapshot~generation
sentChange = sendAid(runtime, client, transport, "ENTER", "LOCAL_OPERATOR")
if \sentChange~ok then do
  say "PASSWORD CHANGE ENTER FAIL" sentChange~code sentChange~detail
  ignore = transport~close
  exit 29
end
say "ENTER #3 sent for password change. Waiting for first host screen change."
resultWait = waitNextGeneration(runtime, transport, beforeChange, seconds)
if \resultWait~ok then do
  say "PASSWORD CHANGE RESULT WAIT FAIL" resultWait~code resultWait~detail
  ignore = transport~close
  exit 30
end
resultSnap = resultWait~value
say ""
say "PASSWORD-CHANGE RESULT generation=" || resultSnap~generation
call printScreen resultSnap
resultMatch = catalog~match(resultSnap)
say "KNOWN_STATE=" || resultMatch~status || " " || resultMatch~matchedStateId

if resultMatch~status == .TerminalMatchStatus~MATCH then do
  if resultMatch~matchedStateId == "IBM_I_CHANGE_PASSWORD" then do
    say "NO POST-PASSWORD-CHANGE COMMAND SENT"
    ignore = transport~close
    say "Host remained on Change Password; password change was not confirmed successful."
    exit 31
  end
end

if resultMatch~status \== .TerminalMatchStatus~MATCH | resultMatch~matchedStateId \== "IBM_I_MAIN_MENU" then do
  say "NO POST-PASSWORD-CHANGE COMMAND SENT"
  say "Result is not the confirmed IBM_I_MAIN_MENU; refusing automatic signoff."
  ignore = transport~close
  exit 0
end

signoffStage = .TN5250Signoff~stage90(runtime, catalog, "IBM_I_MAIN_MENU")
if \signoffStage~ok then do
  say "SIGNOFF STAGE FAIL" signoffStage~code signoffStage~detail
  ignore = transport~close
  exit 32
end
say "ORDERLY SIGNOFF: staged menu option 90 into" signoffStage~value~commandFieldId
say "No other post-password-change command is permitted."

beforeSignoff = runtime~snapshot~generation
sentSignoff = sendAid(runtime, client, transport, "ENTER", "LOCAL_SIGNOFF")
if \sentSignoff~ok then do
  say "SIGNOFF ENTER FAIL" sentSignoff~code sentSignoff~detail
  ignore = transport~close
  exit 33
end
say "ENTER #4 sent for option 90. Waiting for host close or first changed screen; no further input will be sent."
signoffWait = waitForSignoff(runtime, transport, beforeSignoff, 10)
if \signoffWait~ok then do
  say "SIGNOFF WAIT FAIL" signoffWait~code signoffWait~detail
  ignore = transport~close
  exit 34
end
summary = signoffWait~value
if summary["kind"] == "REMOTE_CLOSED" then do
  say "SIGNOFF RESULT: remote closed the TN5250 connection."
end
else do
  signoffSnap = summary["snapshot"]
  say ""
  say "SIGNOFF RESULT generation=" || signoffSnap~generation
  call printScreen signoffSnap
  say "NO FURTHER INPUT SENT"
end
closed = transport~close
if \closed~ok then do
  say "TLS CLOSE FAIL" closed~code closed~detail
  exit 35
end
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
        d = .directory~new
        d["kind"] = "REMOTE_CLOSED"
        d["snapshot"] = .nil
        return .TerminalResult~success(d)
      end
      return step
    end
    snap = step~value
    if snap == .nil then iterate
    if snap~generation > generationArg then do
      d = .directory~new
      d["kind"] = "SCREEN_CHANGED"
      d["snapshot"] = snap
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

::requires "../src/TN5250PasswordExpiryFlow.cls"
::requires "../src/TN5250PasswordChange.cls"
::requires "../src/TN5250Signoff.cls"
::requires "../src/TerminalTransport.cls"

::requires "../src/TN5250DeviceIdentity.cls"

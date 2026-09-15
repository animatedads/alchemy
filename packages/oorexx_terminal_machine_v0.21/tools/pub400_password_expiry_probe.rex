/*
 * Explicit password-expiry continuation probe.
 *
 * This tool authenticates through an already learned IBM_I_SIGNON state, then
 * accepts exactly one post-authentication continuation: a structured IBM i
 * password-expired notice.  Only after that state is confirmed does it issue
 * one ENTER to reach the Change Password panel.  It never asks for or sends a
 * new password.
 *
 * Newly confirmed states are persisted into the supplied catalog:
 *   IBM_I_PASSWORD_EXPIRED_NOTICE
 *   IBM_I_CHANGE_PASSWORD
 * and the observed ENTER transition is recorded as knowledge, not authority.
 *
 * Usage:
 *   rexx pub400_password_expiry_probe.rex known_states.json [host [port [deviceName [seconds]]]]
 */
signal on halt name UserHalt
parse arg statePath host port deviceName seconds
if statePath = "" then do
  say "usage: rexx pub400_password_expiry_probe.rex known_states.json [host [port [deviceName [seconds]]]]"
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

runtime = .TN5250RuntimeSession~new("LIVE-PASSWORD-EXPIRY", "IBM-3179-2", deviceName)
client = runtime~automationPort
transport = .SocatTlsTerminalTransport~new(host, port, .true)
opened = transport~open
if \opened~ok then do
  say "TLS OPEN FAIL" opened~code opened~detail
  exit 4
end

say "TN5250 PASSWORD-EXPIRY STRUCTURE PROBE"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
if transport~caFile \= "" then say "TLS trust=" || transport~trustSource "cafile=" || transport~caFile
else if transport~caPath \= "" then say "TLS trust=" || transport~trustSource "capath=" || transport~caPath
say "Known-state catalog=" || statePath
say "This tool may send login ENTER and one password-expiry continuation ENTER."
say "It will NOT request or send a new password."

/* Wait for the known sign-on panel before asking for the existing credential. */
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
    exitCode = 0
    leave
  end
end
if exitCode \= 0 then do
  if exitCode = 5 then say "Timed out without matching IBM_I_SIGNON. Credentials were not requested."
  ignore = transport~close
  exit exitCode
end

say ""
say "MATCH IBM_I_SIGNON generation=" || signon~generation
if runtime~negotiatedDeviceName = "" then say "NEGOTIATED_DEVICE=(server-assigned / not requested) collisions=" || runtime~deviceNameCollisionCount
else say "NEGOTIATED_DEVICE=" || runtime~negotiatedDeviceName || " collisions=" || runtime~deviceNameCollisionCount
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
say "Credential staged; observer password value=" || staged~value~snapshot~field(staged~value~passwordFieldId)~value

/* Explicit login ENTER. */
pressed = client~press(client~snapshot~generation, "ENTER", "LOCAL_OPERATOR")
if \pressed~ok then do
  say "LOGIN ENTER FAIL" pressed~code pressed~detail
  ignore = transport~close
  exit 13
end
wire = runtime~drainTerminalOutput
if \wire~ok | wire~value~length = 0 then do
  if \wire~ok then say "WIRE BUILD FAIL" wire~code wire~detail
  else say "LOGIN ENTER produced no terminal output"
  ignore = transport~close
  exit 14
end
sent = transport~sendBytes(wire~value)
if \sent~ok then do
  say "SEND FAIL" sent~code sent~detail
  ignore = transport~close
  exit 15
end
say "Login ENTER sent. Waiting for host authentication result."

/* First changed host screen must either remain sign-on (authentication failure)
 * or be the confirmed password-expired notice. */
authGeneration = signon~generation
authSnap = .nil
exitCode = 16
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
  if fed~value~outboundBytes~length > 0 then do
    sent = transport~sendBytes(fed~value~outboundBytes)
    if \sent~ok then do
      say "SEND FAIL" sent~code sent~detail
      exitCode = 20
      leave
    end
  end
  snap = fed~value~snapshot
  if snap \== .nil & snap~generation > authGeneration then do
    authSnap = snap
    exitCode = 0
    leave
  end
end
if exitCode \= 0 then do
  if exitCode = 16 then say "Timed out waiting for authentication result."
  ignore = transport~close
  exit exitCode
end

say ""
say "AUTHENTICATION RESULT generation=" || authSnap~generation
call printScreen authSnap
authMatch = catalog~match(authSnap)
if authMatch~status == .TerminalMatchStatus~MATCH & authMatch~matchedStateId == "IBM_I_SIGNON" then do
  say "AUTHENTICATION DID NOT ADVANCE; still IBM_I_SIGNON. No continuation ENTER sent."
  ignore = transport~close
  exit 21
end

noticeState = catalog~state("IBM_I_PASSWORD_EXPIRED_NOTICE")
if noticeState == .nil then do
  learnedNotice = .KnownState5250Factory~ibmIPasswordExpiredNotice(authSnap, "IBM_I_PASSWORD_EXPIRED_NOTICE", "HUMAN_CONFIRMED_LIVE_2026-08-22")
  if \learnedNotice~ok then do
    say "UNRECOGNIZED POST-AUTH STATE" learnedNotice~code learnedNotice~detail
    say "No continuation ENTER sent."
    ignore = transport~close
    exit 22
  end
  noticeState = learnedNotice~value
  registered = catalog~register(noticeState)
  if \registered~ok then do
    say "KNOWN STATE REGISTER FAIL" registered~code registered~detail
    ignore = transport~close
    exit 23
  end
  saved = .KnownStateJsonStore~save(catalog, statePath)
  if \saved~ok then do
    say "KNOWN STATE SAVE FAIL" saved~code saved~detail
    ignore = transport~close
    exit 24
  end
  say "KNOWN STATE SAVED IBM_I_PASSWORD_EXPIRED_NOTICE ->" statePath
end
else do
  m = catalog~match(authSnap)
  if m~status \== .TerminalMatchStatus~MATCH | m~matchedStateId \== "IBM_I_PASSWORD_EXPIRED_NOTICE" then do
    say "POST-AUTH SCREEN does not match persisted IBM_I_PASSWORD_EXPIRED_NOTICE."
    say "No continuation ENTER sent."
    ignore = transport~close
    exit 25
  end
  say "MATCH IBM_I_PASSWORD_EXPIRED_NOTICE"
end

/* This tool's one post-auth action: ENTER from the confirmed expiry notice. */
continued = client~press(client~snapshot~generation, "ENTER", "LOCAL_OPERATOR_PASSWORD_EXPIRY_CONTINUE")
if \continued~ok then do
  say "CONTINUATION ENTER FAIL" continued~code continued~detail
  ignore = transport~close
  exit 26
end
wire = runtime~drainTerminalOutput
if \wire~ok | wire~value~length = 0 then do
  if \wire~ok then say "WIRE BUILD FAIL" wire~code wire~detail
  else say "Continuation ENTER produced no terminal output"
  ignore = transport~close
  exit 27
end
sent = transport~sendBytes(wire~value)
if \sent~ok then do
  say "SEND FAIL" sent~code sent~detail
  ignore = transport~close
  exit 28
end
say "Password-expiry ENTER sent. Waiting for Change Password panel; no further input will be sent."

changeBaseGeneration = authSnap~generation
changeSnap = .nil
exitCode = 29
do tick = 1 to seconds
  received = transport~receiveBytesWait(16384, 1)
  if \received~ok then do
    if received~code = "TRANSPORT_TIMEOUT" then iterate
    say "RECEIVE FAIL" received~code received~detail
    exitCode = 30
    leave
  end
  if received~value~length = 0 then do
    say "REMOTE CLOSED CONNECTION"
    exitCode = 31
    leave
  end
  fed = runtime~feedNetwork(received~value)
  if \fed~ok then do
    say "TERMINAL FAIL" fed~code fed~detail
    exitCode = 32
    leave
  end
  if fed~value~outboundBytes~length > 0 then do
    sent = transport~sendBytes(fed~value~outboundBytes)
    if \sent~ok then do
      say "SEND FAIL" sent~code sent~detail
      exitCode = 33
      leave
    end
  end
  snap = fed~value~snapshot
  if snap \== .nil & snap~generation > changeBaseGeneration then do
    changeSnap = snap
    exitCode = 0
    leave
  end
end
if exitCode \= 0 then do
  if exitCode = 29 then say "Timed out waiting for Change Password panel."
  ignore = transport~close
  exit exitCode
end

say ""
say "CHANGE-PASSWORD HOST SCREEN generation=" || changeSnap~generation
call printScreen changeSnap

changeState = catalog~state("IBM_I_CHANGE_PASSWORD")
if changeState == .nil then do
  learnedChange = .KnownState5250Factory~ibmIChangePassword(changeSnap, "IBM_I_CHANGE_PASSWORD", "HUMAN_CONFIRMED_LIVE_2026-08-22")
  if \learnedChange~ok then do
    say "CHANGE PASSWORD STATE NOT LEARNED" learnedChange~code learnedChange~detail
    say "NO PASSWORD-CHANGE DATA SENT"
    ignore = transport~close
    exit 34
  end
  changeState = learnedChange~value
  registered = catalog~register(changeState)
  if \registered~ok then do
    say "KNOWN STATE REGISTER FAIL" registered~code registered~detail
    ignore = transport~close
    exit 35
  end
  say "KNOWN STATE LEARNED IBM_I_CHANGE_PASSWORD"
end
else do
  m = catalog~match(changeSnap)
  if m~status \== .TerminalMatchStatus~MATCH | m~matchedStateId \== "IBM_I_CHANGE_PASSWORD" then do
    say "CHANGE PASSWORD SCREEN does not match persisted IBM_I_CHANGE_PASSWORD."
    say "NO PASSWORD-CHANGE DATA SENT"
    ignore = transport~close
    exit 36
  end
  say "MATCH IBM_I_CHANGE_PASSWORD"
end

/* Record observed transition if not already present. */
hasTransition = .false
do tr over noticeState~transitions
  if tr~actionKind == "AID" & tr~actionName == "ENTER" & tr~toStateId == "IBM_I_CHANGE_PASSWORD" then hasTransition = .true
end
if \hasTransition then noticeState~addTransition(.KnownStateTransition~new("IBM_I_PASSWORD_EXPIRED_NOTICE", "AID", "ENTER", "IBM_I_CHANGE_PASSWORD", 1, "Confirmed live on IBM i after expired-password sign-on."))

saved = .KnownStateJsonStore~save(catalog, statePath)
if \saved~ok then do
  say "KNOWN STATE SAVE FAIL" saved~code saved~detail
  ignore = transport~close
  exit 37
end
say "KNOWN STATES SAVED ->" statePath
say "TRANSITION OBSERVED IBM_I_PASSWORD_EXPIRED_NOTICE --ENTER--> IBM_I_CHANGE_PASSWORD"
say "NO PASSWORD-CHANGE DATA SENT"
ignore = transport~close
exit 0

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

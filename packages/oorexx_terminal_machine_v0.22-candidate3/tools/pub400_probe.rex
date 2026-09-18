/*
 * Credential-free TN5250/TLS probe.
 *
 * This program intentionally has no field-input or AID code.  Its only job is
 * to prove the transport/negotiation/datastream path far enough to observe the
 * first host screen safely.
 *
 * Usage:
 *   rexx pub400_probe.rex [host [port [deviceName [seconds [knownStatePath]]]]]
 */
signal on halt name UserHalt
parse arg host port deviceName seconds knownStatePath
if host = "" then host = "pub400.com"
if port = "" then port = 992
if deviceName = "" then deviceName = ""
if seconds = "" then seconds = 30
if \seconds~datatype("W") | seconds < 1 then do
  say "seconds must be a positive integer"
  exit 2
end

runtime = .TN5250RuntimeSession~new("LIVE-PROBE", "IBM-3179-2", deviceName)
transport = .SocatTlsTerminalTransport~new(host, port, .true)
opened = transport~open
if \opened~ok then do
  say "TLS OPEN FAIL" opened~code opened~detail
  exit 3
end

say "TN5250 CREDENTIAL-FREE PROBE"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
if transport~caFile \= "" then say "TLS trust=" || transport~trustSource "cafile=" || transport~caFile
else if transport~caPath \= "" then say "TLS trust=" || transport~trustSource "capath=" || transport~caPath
if deviceName \= "" then say "requested device=" || deviceName
say "No user profile, password, field input or AID will be sent."

sawBytes = .false
sawScreen = .false
exitCode = 4

do tick = 1 to seconds
  received = transport~receiveBytesWait(16384, 1)
  if \received~ok then do
    if received~code = "TRANSPORT_TIMEOUT" then iterate
    say "RECEIVE FAIL" received~code received~detail
    exitCode = 5
    leave
  end
  bytes = received~value
  if bytes~length = 0 then do
    say "REMOTE CLOSED CONNECTION"
    exitCode = 6
    leave
  end
  sawBytes = .true
  fed = runtime~feedNetwork(bytes)
  if \fed~ok then do
    say "TERMINAL FAIL" fed~code fed~detail
    exitCode = 7
    leave
  end
  wire = fed~value~outboundBytes
  if wire~length > 0 then do
    sent = transport~sendBytes(wire)
    if \sent~ok then do
      say "SEND FAIL" sent~code sent~detail
      exitCode = 8
      leave
    end
  end

  snap = fed~value~snapshot
  if snap \== .nil & snap~generation > 0 then do
    nonblank = .false
    do row over snap~textRows
      if row~strip \= "" then nonblank = .true
    end
    if nonblank | snap~fields~items > 0 then do
      sawScreen = .true
      say ""
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
      say "TRANSPARENT_READY=" || runtime~transparentReady
      say "NEGOTIATED_DEVICE=" || runtime~negotiatedDeviceName || " collisions=" || runtime~deviceNameCollisionCount
      identityResult = .TN5250DeviceIdentity~observeSignon(snap, deviceName, runtime~negotiatedDeviceName)
      if identityResult~ok then do
        identity = identityResult~value
        say "HOST_DISPLAY_DEVICE=" || identity~assignedDeviceName || " effective=" || identity~effectiveDeviceName || " source=" || identity~source
      end
      if knownStatePath \= "" then do
        learned = .KnownState5250Factory~ibmISignon(snap, "IBM_I_SIGNON", "LOCAL_OPERATOR_PROBE")
        if \learned~ok then do
          say "KNOWN STATE NOT SAVED" learned~code learned~detail
          exitCode = 9
          leave
        end
        catalog = .KnownStateCatalog~new
        added = catalog~register(learned~value)
        if \added~ok then do
          say "KNOWN STATE NOT SAVED" added~code added~detail
          exitCode = 9
          leave
        end
        saved = .KnownStateJsonStore~save(catalog, knownStatePath)
        if \saved~ok then do
          say "KNOWN STATE NOT SAVED" saved~code saved~detail
          exitCode = 9
          leave
        end
        say "KNOWN STATE SAVED IBM_I_SIGNON ->" knownStatePath
      end
      say "LOGIN NOT ATTEMPTED"
      exitCode = 0
      leave
    end
  end
end

ignore = transport~close
if exitCode = 4 then do
  if sawBytes then say "Timed out after protocol activity without a renderable screen."
  else say "Timed out without receiving network data."
end
exit exitCode

UserHalt:
  say "INTERRUPTED - closing TLS transport and helper"
  if symbol("TRANSPORT") == "VAR" then do
    if transport \== .nil then do
      closedOnHalt = transport~close
      if \closedOnHalt~ok then say "TLS CLOSE FAIL" closedOnHalt~code closedOnHalt~detail
    end
  end
  exit 130

::requires "../src/TN5250Automation.cls"
::requires "../src/TerminalTransport.cls"
::requires "../src/TN5250CredentialLogin.cls"

::requires "../src/TN5250DeviceIdentity.cls"

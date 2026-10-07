/*
 * Strict, credential-free attempt to reattach to one exact IBM i display.
 *
 * Usage:
 *   rexx pub400_resume_device.rex QPADEV0037 [host [port [seconds]]]
 *
 * seconds defaults to 60.  Use 0 to stay attached until Ctrl-C/remote close.
 * This tool never sends credentials, field input or AIDs and never substitutes
 * a different DEVNAME after a collision.
 */
signal on halt name UserHalt

parse arg deviceName host port seconds
if deviceName = "" then do
  say "usage: rexx pub400_resume_device.rex DEVICE [host [port [seconds]]]"
  exit 2
end
deviceName = deviceName~strip~upper
if host = "" then host = "pub400.com"
if port = "" then port = 992
if seconds = "" then seconds = 60
if \seconds~datatype("W") then do
  say "seconds must be a non-negative integer (0 means until interrupted)"
  exit 2
end

live = .TN5250LiveSession~new("STRICT-RESUME", host, port, "IBM-3179-2", deviceName, "STRICT")
opened = live~open
if \opened~ok then do
  say "TLS OPEN FAIL" opened~code opened~detail
  exit 3
end

say "TN5250 STRICT DEVICE REATTACH"
say "host=" || host "port=" || port "terminal=IBM-3179-2"
say "requested device=" || deviceName "collision policy=STRICT"
if live~caFile \= "" then say "TLS trust=" || live~trustSource "cafile=" || live~caFile
else if live~caPath \= "" then say "TLS trust=" || live~trustSource "capath=" || live~caPath
say "No credentials, field input, AID or substitute device name will be sent."
if seconds = 0 then say "Watch duration=until interrupted/remote close"
else say "Watch duration=" || seconds || " seconds"
say ""

lastGeneration = -1
tick = 0
exitCode = 0

do forever
  if seconds > 0 & tick >= seconds then leave
  tick += 1
  pumped = live~pumpOnce(1)
  if \pumped~ok then do
    if pumped~code == "TN5250_DEVICE_COLLISION" then do
      say "DEVICE STILL ACTIVE / IN USE:" deviceName
      say "STRICT RESUME REFUSED TO SUBSTITUTE ANOTHER DEVNAME"
      say "collisions=" || live~deviceNameCollisionCount
      exitCode = 10
      leave
    end
    say "SESSION FAIL" pumped~code pumped~detail
    exitCode = 5
    leave
  end

  if live~state == .TN5250LiveState~REMOTE_CLOSED then do
    say "REMOTE CLOSED CONNECTION"
    exitCode = 6
    leave
  end

  snap = pumped~value~snapshot
  if snap == .nil then iterate
  if snap~generation <= 0 | snap~generation == lastGeneration then iterate

  nonblank = .false
  do row over snap~textRows
    if row~strip \= "" then nonblank = .true
  end
  if \nonblank & snap~fields~items = 0 then iterate

  lastGeneration = snap~generation
  call showSnapshot snap
  say "NEGOTIATED_DEVICE=" || live~negotiatedDeviceName || " collisions=" || live~deviceNameCollisionCount
  if live~effectiveDeviceName \= "" then say "EFFECTIVE_DEVICE=" || live~effectiveDeviceName || " source=" || live~deviceIdentitySource
  say "STRICT_DEVICE=" || deviceName
  say "CONNECTION REMAINS OPEN; OBSERVATION ONLY"
  say ""
end

ignore = live~close
if exitCode = 0 then do
  say "WATCH WINDOW COMPLETE"
  say "NETWORK CONNECTION CLOSED; NO TERMINAL INPUT WAS SENT"
end
exit exitCode

UserHalt:
  say ""
  say "INTERRUPTED - closing strict reattach transport"
  if live \== .nil then do
    closedOnHalt = live~close
    if \closedOnHalt~ok then say "LIVE CLOSE FAIL" closedOnHalt~code closedOnHalt~detail
  end
  exit 130

showSnapshot: procedure
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

::requires "../src/TN5250LiveSession.cls"

/* Native Terminal Machine read-only TSO discovery for MVS Intention.
 *
 * Terminal Machine is the terminal/session authority.  This adapter uses
 * TN3270LiveSession and the native 3270 presentation-space model; it does not
 * shell out to s3270 and it does not parse x3270 status text.
 *
 * Usage:
 *   rexx tools/terminal_machine_tso_discovery.rex TARGET HOST [PORT] [LU] [TIMEOUT]
 *
 * Environment:
 *   TSO_USER       defaults to HERC03
 *   TSO_PASSWORD   if absent, discovery is observation-only and sends no
 *                  credential or AID beyond an optional CLEAR needed to expose
 *                  a TSO Logon panel.
 *
 * Output is the canonical MVS Intention TSV feed only.
 */

parse arg target host port lu timeout
target = target~strip
host = host~strip
if target == "" | host == "" then do
  call probe "TERMINAL_MACHINE_ARGUMENTS", "target/host required"
  exit 2
end
if port~strip == "" then port = 3270
if lu~strip == "" then lu = "00C0"
if timeout~strip == "" then timeout = 15

user = value("TSO_USER",, "ENVIRONMENT")~strip
if user == "" then user = "HERC03"
password = value("TSO_PASSWORD",, "ENVIRONMENT")

transport = .TcpTerminalTransport~new(host, port)
profile = .TN3270TelnetProfile~new("IBM-3278-2-E", lu)
wire = .TN3270Wire~new(.nil, profile)
session = .TN3270LiveSession~new(transport, wire)

r = session~open
if \r~ok then do
  call probe "TERMINAL_MACHINE_OPEN_FAILED", r~code || ":" || r~detail
  exit 3
end
call probe "TERMINAL_MACHINE_OPEN", target || "@" || host || ":" || port || " lu=" || lu

r = session~pumpUntilGeneration(0, timeout)
if \r~ok then do
  call probe "TERMINAL_MACHINE_FIRST_SCREEN_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 4
end

model = wire~model
screen = model~text(wire~stream~codepage)
class = classify(screen)
call emitBase target, host, lu, profile, wire, class

/* A fresh TK5 LU may initially show the Hercules/TK5 welcome presentation.
 * CLEAR is an actual 3270 AID here.  Completion is a new Terminal Machine
 * presentation-space generation, not an x3270 action return convention. */
if class \== "TSO_LOGON" then do
  r = session~sendAidAndAwait(.Aid3270~CLEAR, timeout)
  if \r~ok then do
    call probe "TERMINAL_MACHINE_CLEAR_FAILED", r~code || ":" || r~detail
    ignore = session~close
    exit 5
  end
  screen = model~text(wire~stream~codepage)
  class = classify(screen)
end

if class \== "TSO_LOGON" then do
  call probe "TERMINAL_MACHINE_NO_TSO_LOGON", "class=" || class || " generation=" || model~generation
  ignore = session~close
  exit 6
end

call fact "SESSION", "STATE", "TSO_LOGON", 100, "terminal-machine:generation=" || model~generation
call fact "SCREEN", "CLASS", "TSO_LOGON", 100, "terminal-machine:presentation-space"

if password == "" then do
  call probe "TERMINAL_MACHINE_OBSERVATION_ONLY", "TSO_PASSWORD not supplied; no credential sent"
  ignore = session~close
  exit 0
end

/* Enter userid only into a native unprotected field. */
r = setCurrentInput(session, model, user)
if \r~ok then do
  call probe "TERMINAL_MACHINE_USER_FIELD_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 7
end
r = session~enterAndAwait(timeout)
if \r~ok then do
  call probe "TERMINAL_MACHINE_USER_SUBMIT_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 8
end

screen = model~text(wire~stream~codepage)
class = classify(screen)
if class \== "TSO_PASSWORD" then do
  call probe "TERMINAL_MACHINE_PASSWORD_PROMPT_MISSING", "class=" || class || " generation=" || model~generation
  ignore = session~close
  exit 9
end

/* The password is never written to feed/probe output. */
r = setCurrentInput(session, model, password)
if \r~ok then do
  call probe "TERMINAL_MACHINE_PASSWORD_FIELD_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 10
end
r = session~enterAndAwait(timeout)
if \r~ok then do
  call probe "TERMINAL_MACHINE_PASSWORD_SUBMIT_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 11
end

authenticated = .false
postEnters = 0
do step = 1 to 8
  screen = model~text(wire~stream~codepage)
  class = classify(screen)
  if class == "TSO_READY" then do
    authenticated = .true
    leave
  end

  if class == "TSO_LOGON" | class == "TSO_PASSWORD" | class == "AUTH_REJECTED" then do
    call probe "TERMINAL_MACHINE_AUTH_REJECTED", "class=" || class || " generation=" || model~generation
    ignore = session~close
    exit 12
  end

  if class == "ISPF_PRIMARY" then do
    r = session~pfAndAwait(3, timeout)
    if \r~ok then do
      call probe "TERMINAL_MACHINE_PF3_FAILED", r~code || ":" || r~detail
      ignore = session~close
      exit 13
    end
    iterate
  end

  if postEnters < 2 then do
    r = session~enterAndAwait(timeout)
    if \r~ok then do
      call probe "TERMINAL_MACHINE_POSTLOGON_ENTER_FAILED", r~code || ":" || r~detail
      ignore = session~close
      exit 14
    end
    postEnters += 1
    iterate
  end

  call probe "TERMINAL_MACHINE_POSTLOGON_UNKNOWN", "class=" || class || " generation=" || model~generation
  ignore = session~close
  exit 15
end

if \authenticated then do
  call probe "TERMINAL_MACHINE_READY_NOT_OBSERVED", "generation=" || model~generation
  ignore = session~close
  exit 16
end

call fact "SESSION", "STATE", "TSO_READY", 100, "terminal-machine:generation=" || model~generation
call fact "SESSION", "AUTHENTICATED", "TRUE", 100, "terminal-machine:positive-ready"
call fact "TSO", "USER", translate(user), 100, "terminal-machine:authenticated-session"
call fact "SCREEN", "CLASS", "TSO_READY", 100, "terminal-machine:presentation-space"
call fact "SCREEN", "GENERATION", model~generation, 100, "terminal-machine:presentation-space"
if model~keyboardLocked then ks = "LOCKED"; else ks = "UNLOCKED"
call fact "KEYBOARD", "STATE", ks, 100, "terminal-machine:presentation-space"

/* Leave the development guest clean.  LOGOFF is the only command sent by the
 * Terminal Machine adapter after READY.  Dataset/JES discovery belongs to MVS
 * Alchemy, not to the terminal authority. */
r = setCurrentInput(session, model, "LOGOFF")
if \r~ok then do
  call probe "TERMINAL_MACHINE_LOGOFF_FIELD_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 17
end
r = session~enterAndAwait(timeout)
if \r~ok then do
  call probe "TERMINAL_MACHINE_LOGOFF_SUBMIT_FAILED", r~code || ":" || r~detail
  ignore = session~close
  exit 18
end

screen = model~text(wire~stream~codepage)
class = classify(screen)
if class \== "TSO_LOGON" then do
  /* One additional host generation is allowed; no further input is sent. */
  r = session~pumpUntilGeneration(model~generation, 2)
  if r~ok then do
    screen = model~text(wire~stream~codepage)
    class = classify(screen)
  end
end
if class \== "TSO_LOGON" then do
  call probe "TERMINAL_MACHINE_LOGOFF_NOT_VERIFIED", "class=" || class || " generation=" || model~generation
  ignore = session~close
  exit 19
end
call probe "TERMINAL_MACHINE_LOGOFF_VERIFIED", "generation=" || model~generation

ignore = session~close
exit 0

emitBase: procedure
  use arg target, host, lu, profile, wire, class
  model = wire~model
  if profile~tn3270eActive then mode = "TN3270E_BASIC"; else mode = "TN3270"
  call fact "SESSION", "TARGET", target, 100, "terminal-machine:controller-binding"
  call fact "SESSION", "HOST", host, 100, "terminal-machine:transport"
  call fact "SESSION", "REQUESTED_LU", lu, 100, "terminal-machine:tn3270-profile"
  call fact "SESSION", "MODE", mode, 100, "terminal-machine:tn3270-profile"
  if profile~deviceName \== "" then call fact "SESSION", "DEVICE_NAME", profile~deviceName, 100, "terminal-machine:tn3270-profile"
  call fact "SCREEN", "ROWS", model~rows, 100, "terminal-machine:presentation-space"
  call fact "SCREEN", "COLUMNS", model~columns, 100, "terminal-machine:presentation-space"
  call fact "SCREEN", "GENERATION", model~generation, 100, "terminal-machine:presentation-space"
  call fact "SCREEN", "CLASS", class, 95, "terminal-machine:screen-classifier"
  call fact "CURSOR", "ROW", model~rowForAddress(model~cursor), 100, "terminal-machine:presentation-space"
  call fact "CURSOR", "COLUMN", model~columnForAddress(model~cursor), 100, "terminal-machine:presentation-space"
  if model~keyboardLocked then ks = "LOCKED"; else ks = "UNLOCKED"
  call fact "KEYBOARD", "STATE", ks, 100, "terminal-machine:presentation-space"
  return

setCurrentInput: procedure
  use arg session, model, value
  field = model~fieldAt(model~cursor)
  if field \== .nil then do
    if \field~protected then do
      a = model~cursor
      if model~fieldStartingAt(a) == .nil then do
        row = model~rowForAddress(a)
        col = model~columnForAddress(a)
        r = session~setInputTextAt(row, col, value)
        if r~ok then return r
      end
    end
  end

  fields = model~inputFields
  if fields~items == 0 then return .TerminalResult~failure("3270_NO_INPUT_FIELD")
  field = fields[1]
  a = (field~address + 1) // model~size
  row = model~rowForAddress(a)
  col = model~columnForAddress(a)
  return session~setInputTextAt(row, col, value)

classify: procedure
  use arg screen
  u = translate(screen)
  if pos("LOGON ===>", u) > 0 then return "TSO_LOGON"
  if pos("ENTER CURRENT PASSWORD FOR", u) > 0 | pos("ENTER PASSWORD", u) > 0 | pos("PASSWORD ===>", u) > 0 then return "TSO_PASSWORD"
  if pos("INVALID PASSWORD", u) > 0 | pos("LOGON REJECTED", u) > 0 | pos("NOT AUTHORIZED", u) > 0 then return "AUTH_REJECTED"
  if exactReady(screen) then return "TSO_READY"
  if pos("PRIMARY OPTION MENU", u) > 0 | pos("OPTION ===>", u) > 0 then return "ISPF_PRIMARY"
  if pos("WELCOME TO TSO", u) > 0 then return "TSO_WELCOME"
  if pos("FORTUNE", u) > 0 then return "TSO_FORTUNE"
  return "OTHER"

exactReady: procedure
  use arg screen
  rest = screen || "0A"x
  do while rest \== ""
    parse var rest line "0A"x rest
    if strip(translate(line)) == "READY" then return .true
  end
  return .false

probe: procedure
  use arg name, detail
  say "PROBE" || "09"x || name || "09"x || detail
  return

fact: procedure
  use arg subject, predicate, value, quality=100, evidence=""
  say "FACT" || "09"x || subject || "09"x || predicate || "09"x || value || "09"x || quality || "09"x || evidence
  return

::requires "TN3270LiveSession.cls"

failures = 0

/* Same session/watch classes with a 5250 field model. */
m5250 = .PresentationSpace5250~new
s5250 = .TerminalSession~new("5250", m5250)
w5250 = .TerminalWatchAlong~new
s5250~addWatcher(w5250)
m5250~writeText(1,1,"IBM I")
m5250~hostCommit
s5250~commit
call assertTrue w5250~current~capabilities~has("INPUT_FIELDS"), "5250 field capability"
call assertTrue pos("cursor:", w5250~look) > 0, "grid watch presentation"

/* Same session/watch classes with a DEC-ish stream terminal. */
ttyCaps = .TerminalCapabilities~new
ttyCaps~add("BREAK")
mtty = .StreamTerminalModel~new("DEC-PDP10-TTY", 20, ttyCaps)
stty = .TerminalSession~new("TTY", mtty)
wtty = .TerminalWatchAlong~new
stty~addWatcher(wtty)
mtty~appendText(".LOGIN FRED" || "0a"x || "Password:")
mtty~advanceGeneration
stty~commit
call assertTrue wtty~current~capabilities~has("CHARACTER_STREAM"), "stream capability"
call assertTrue pos(".LOGIN FRED", wtty~look) > 0, "stream watch transcript"
call assertTrue pos("mode: STREAM", wtty~look) > 0, "stream watch does not pretend grid"

if failures > 0 then do
  say "FAIL test_terminal_swap" failures
  exit 1
end
say "PASS test_terminal_swap"
exit 0

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "Terminal5250.cls"
::requires "StreamTerminal.cls"

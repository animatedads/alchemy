call directory rxqueue
here = filespec("location", sourceLine(1))
root = filespec("drive", here) || filespec("path", here) || ".."
tmp = value("TMPDIR",, "ENVIRONMENT")
if tmp == "" then tmp = "/tmp"
dir = tmp || "/mvs-intention-dev9-terminal-machine"
call SysFileTree dir, "gone.", "FO"
address system "rm -rf" dir
address system "mkdir -p" dir

call lineout dir || "/terminal_machine.tsv", "PROBE"||"09"x||"TM_NATIVE"||"09"x||"candidate8"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"STATE"||"09"x||"TSO_READY"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"AUTHENTICATED"||"09"x||"TRUE"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"TARGET"||"09"x||"ED209Z"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"HOST"||"09"x||"52.146.17.8"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"REQUESTED_LU"||"09"x||"00C0"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SESSION"||"09"x||"MODE"||"09"x||"TN3270E_BASIC"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SCREEN"||"09"x||"ROWS"||"09"x||"24"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SCREEN"||"09"x||"COLUMNS"||"09"x||"80"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"SCREEN"||"09"x||"GENERATION"||"09"x||"9"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"KEYBOARD"||"09"x||"STATE"||"09"x||"UNLOCKED"||"09"x||"100"||"09"x||"tm"
call lineout dir || "/terminal_machine.tsv", "FACT"||"09"x||"TSO"||"09"x||"USER"||"09"x||"HERC03"||"09"x||"100"||"09"x||"tm"
call stream dir || "/terminal_machine.tsv", "c", "close"
call lineout dir || "/mvs_alchemy.tsv", "PROBE"||"09"x||"ABSENT"||"09"x||"fixture"
call stream dir || "/mvs_alchemy.tsv", "c", "close"
call lineout dir || "/hercules_services.tsv", "PROBE"||"09"x||"ABSENT"||"09"x||"fixture"
call stream dir || "/hercules_services.tsv", "c", "close"

backend = .MvsDiscoveryDirectoryBackend~new(dir)
s = backend~discover("ED209Z")
call assert s~terminalState == "TSO_READY", "terminal state"
call assert s~tsoUser == "HERC03", "TSO user"
call assert s~capability("TERMINAL_MACHINE_AUTHENTICATED") == "TRUE", "authenticated"
call assert s~capability("TERMINAL_MACHINE_TARGET") == "ED209Z", "target"
call assert s~capability("TERMINAL_MACHINE_HOST") == "52.146.17.8", "host"
call assert s~capability("TERMINAL_MACHINE_LU") == "00C0", "LU"
call assert s~capability("TERMINAL_MACHINE_MODE") == "TN3270E_BASIC", "mode"
call assert s~capability("TERMINAL_MACHINE_ROWS") == "24", "rows"
call assert s~capability("TERMINAL_MACHINE_COLUMNS") == "80", "columns"
call assert s~capability("TERMINAL_MACHINE_GENERATION") == "9", "generation"
call assert s~capability("TERMINAL_MACHINE_KEYBOARD") == "UNLOCKED", "keyboard"
say "PASS native Terminal Machine evidence projection"
exit 0

assert: procedure
  use arg condition, message
  if \condition then do
    say "FAIL" message
    exit 1
  end
  return

::requires "MvsIntention.cls"

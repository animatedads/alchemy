failures = 0

machine = .TerminalEmulatorStateMachine~new("TESTBED")
initial = .directory~new
initial["PC"] = 100
created = machine~createComponent("CPU", initial, "BOUNDARY-CPU")
call assertTrue created~ok, "CPU create"
cpu = created~value
boundary = .TerminalEmulatorExecutionBoundary~new(machine)

b1 = boundary~begin("OPCODE-1", "before opcode 1")
call assertTrue b1~ok, "begin first attempt"
t1 = b1~value
call assertTrue boundary~active, "boundary active"
call assertEq t1~checkpointId, machine~latestCheckpoint~checkpointId, "ticket checkpoint identity"
cpu~put("PC", 104, "SPECULATIVE")

busy = boundary~begin("OPCODE-2")
call assertTrue \busy~ok, "second begin refused while active"
call assertEq busy~code, "TERMINAL_EMULATOR_ATTEMPT_ACTIVE", "active refusal code"

/* A forged lookalike ticket with the same values is not the exact issued token. */
forged = .TerminalEmulatorExecutionTicket~new(t1~sequence, t1~checkpointId, t1~label, t1~eventName)
stale = boundary~rollback(forged, "FORGED")
call assertTrue \stale~ok, "forged ticket refused"
call assertEq stale~code, "TERMINAL_EMULATOR_ATTEMPT_STALE", "forged ticket code"
call assertEq cpu~at("PC"), 104, "forged rollback leaves speculative state"

rolled = boundary~rollback(t1, "FAULT")
call assertTrue rolled~ok, "exact rollback succeeds"
call assertEq cpu~at("PC"), 100, "rollback restores exact pre-event state"
call assertTrue \boundary~active, "boundary idle after rollback"
call assertEq boundary~rolledBackCount, 1, "rollback count"
call assertEq boundary~lastOutcome, "ROLLED_BACK", "rollback outcome"

b2 = boundary~begin("OPCODE-2")
call assertTrue b2~ok, "begin second attempt"
t2 = b2~value
cpu~put("PC", 104, "SUCCESS")
committed = boundary~commit(t2, "PC=104")
call assertTrue committed~ok, "commit exact attempt"
call assertEq cpu~at("PC"), 104, "commit keeps forward state"
call assertEq boundary~committedCount, 1, "commit count"
call assertEq boundary~lastOutcome, "COMMITTED", "commit outcome"
progress = machine~progress("OPCODE-2")
call assertTrue progress \== .nil, "commit progress recorded"
call assertEq progress["marker"], "PC=104", "progress marker"

b3 = boundary~begin("OPCODE-3")
call assertTrue b3~ok, "begin third attempt"
t3 = b3~value
cpu~put("PC", 108, "SPECULATIVE-3")
old = boundary~commit(t2)
call assertTrue \old~ok, "previous ticket stale during new active attempt"
call assertEq old~code, "TERMINAL_EMULATOR_ATTEMPT_STALE", "previous ticket stale code"
call assertEq cpu~at("PC"), 108, "stale commit leaves active state"
call assertTrue boundary~rollback(t3, "TEST")~ok, "third attempt cleanup rollback"
call assertEq cpu~at("PC"), 104, "third rollback restores prior committed state"

none = boundary~commit(t3)
call assertTrue \none~ok, "ticket cannot be reused after completion"
call assertEq none~code, "TERMINAL_EMULATOR_ATTEMPT_NONE", "reused ticket code"

if failures > 0 then do
  say "FAIL test_terminal_emulator_execution_boundary" failures
  exit 1
end
say "PASS test_terminal_emulator_execution_boundary"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return

assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "TerminalEmulatorJournal.cls"

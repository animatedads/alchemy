/* Bounded APR I/O reset semantics: exactly CONO APR,200000 and nothing else. */
numeric digits 30
pc = octToDec("000100")
resetWord = octToDec("700200200000")

/* Guard memory contains only the instruction.  Any attempt to treat E=200000
 * as a memory operand will raise, proving CONO uses the instruction condition
 * bits directly rather than fetching M[E] or an accumulator alias. */
mem = .GuardMemory~new(pc, resetWord)
cpu = .KL10CPU~new~~loadImage(mem, pc)
apr = cpu~apr
call assertEq apr~ioResetCount, 0, "initial reset count"
call assertEq apr~ioResetDone, 0, "initial reset marker"
call assertEq cpu~pag~status, .nil, "initial PAG status unknown"
call assertEq apr~hasMethod("pi"), 0, "no invented APR PI field"
call assertEq apr~hasMethod("error"), 0, "no invented APR error field"

trace = cpu~step
call assertEq trace["format"], "IO", "reset format"
call assertEq trace["mnemonic"], "CONO", "reset mnemonic"
call assertEq trace["device"], 0, "APR device"
call assertEq trace["ioCondition"], octToDec("200000"), "reset condition"
call assertEq trace["ioAction"], "APR_IO_RESET", "bounded reset action"
call assertEq trace["aprResetCountBefore"], 0, "trace count before"
call assertEq trace["aprResetCountAfter"], 1, "trace count after"
call assertEq cpu~pc, octToDec("000101"), "reset advances one PC"
call assertEq cpu~halted, 1, "reset halts after one debugger step"
call assertEq apr~ioResetCount, 1, "APR reset count"
call assertEq apr~ioResetDone, 1, "APR reset marker"
call assertEq cpu~pag~status, 0, "reset establishes bounded PAG zero status"

/* Ordinary APR control conditions are device state, not reset aliases.
 * CONO APR,1 selects PIA 1 and must not invoke reset_all. */
control = .KL10CPU~new~~loadImage(.GuardMemory~new(pc, octToDec("700200000001")), pc)
controlTrace = control~step
call assertEq controlTrace["ioAction"], "APR_CONO", "APR control action"
call assertEq control~apr~aprIrq, 1, "APR PIA"
call assertEq control~apr~ioResetCount, 0, "APR control does not reset"
call assertEq control~pc, pc + 1, "APR control advances PC"

/* Correct condition on PI device remains unsupported. */
wrongDevice = .KL10CPU~new~~loadImage(.GuardMemory~new(pc, octToDec("700600200000")), pc)
signal on syntax name expectedBadDevice
ignored = wrongDevice~step
signal off syntax
say "FAIL: CONO PI,200000 should be unsupported"
exit 1

expectedBadDevice:
signal off syntax
call assertEq wrongDevice~pc, pc, "wrong device leaves PC unchanged"
call assertEq wrongDevice~apr~ioResetCount, 0, "wrong device does not reset APR marker"

say "KL10 APR reset acceptance: PASS"
say "  CONO APR,200000 -> APR_IO_RESET; PC + 1; HALTED"
say "  E field was not fetched as memory"
say "  ordinary APR PIA/interrupt controls are device state; unknown devices remain unsupported"
exit 0

octToDec: procedure
  use arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL:" label
    say "  expected:" expected
    say "  actual:  " actual
    exit 1
  end
  return

::class GuardMemory public
::method init
  expose instructionAddress instructionWord
  use arg at, word
  instructionAddress = at
  instructionWord = word
::method word
  expose instructionAddress instructionWord
  use arg at
  if at = instructionAddress then return instructionWord
  raise syntax 40.900 array("unexpected memory fetch at" at)

::requires "../KL10IPL.cls"

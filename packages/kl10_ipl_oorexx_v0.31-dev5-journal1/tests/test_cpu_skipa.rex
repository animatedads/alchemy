/* SKIPA semantics and PDP-10 AC/fast-memory aliasing. */
numeric digits 30

/* Nonzero AC field: load from ordinary memory and skip. */
mem = .KL10DepositMemory~new
pc = octToDec("000100")
ea = octToDec("000020")
mem~deposit(pc, octToDec("334200000020"))   /* SKIPA 4,20 */
mem~deposit(ea, octToDec("765432100123"))
cpu = .KL10CPU~new~~loadImage(mem, pc)
trace = cpu~step
call assertEq trace["mnemonic"], "SKIPA", "SKIPA mnemonic"
call assertEq trace["effectiveAddress"], ea, "ordinary EA"
call assertEq trace["operand"], octToDec("765432100123"), "ordinary operand"
call assertEq cpu~accumulator(4), octToDec("765432100123"), "SKIPA loads nonzero AC"
call assertEq cpu~pc, octToDec("000102"), "SKIPA skips one instruction"
call assertEq cpu~halted, 1, "single step returns halted"

/* Historical form: SKIPA 0,0.  Address 0 is AC0 architecturally.  Deposit a
 * contradictory sparse memory[0] so a direct memory~word(0) implementation
 * cannot accidentally pass this test. */
mem2 = .KL10DepositMemory~new
pc2 = octToDec("000200")
mem2~deposit(pc2, octToDec("334000000000"))
mem2~deposit(0, octToDec("000000777777"))
cpu2 = .KL10CPU~new~~loadImage(mem2, pc2)
cpu2~setAccumulator(0, octToDec("123456000077"))
trace2 = cpu2~step
call assertEq trace2["operand"], octToDec("123456000077"), "SKIPA 0,0 reads AC0 through fast-memory alias"
call assertEq cpu2~accumulator(0), octToDec("123456000077"), "AC0 unchanged when AC field is zero"
call assertEq cpu2~pc, octToDec("000202"), "SKIPA 0,0 skips unconditionally"

say "KL10 SKIPA semantic acceptance: PASS"
say "  SKIPA 4,20 loads AC4 and skips"
say "  SKIPA 0,0 reads AC0, discards load, and skips"
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
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
::requires "../KL10TapeRaw.cls"

/* TDZ semantic regressions for the bounded CPU.
 *
 * v0.3's first synthetic mask used address 5 as if that were ordinary core.
 * On a PDP-10, addresses 0..17 octal are the accumulator/fast-memory window.
 * v0.4 makes that alias explicit and tests both ordinary memory and AC-as-memory.
 */
numeric digits 30

/* Ordinary-memory operand: use 20 octal, just above the AC window. */
mem = .KL10DepositMemory~new
pc = octToDec("000100")
maskAddr = octToDec("000020")
instruction = octToDec("630140000020")   /* TDZ 3,20 */
mem~deposit(pc, instruction)
mem~deposit(maskAddr, octToDec("000000000077"))

cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("123456000077"))
trace = cpu~step
call assertEq trace["mnemonic"], "TDZ", "mnemonic"
call assertEq trace["effectiveAddress"], maskAddr, "effective address"
call assertEq trace["operand"], octToDec("000000000077"), "mask operand"
call assertEq trace["acBefore"], octToDec("123456000077"), "AC before"
call assertEq trace["acAfter"], octToDec("123456000000"), "TDZ clears selected bits"
call assertEq cpu~accumulator(3), octToDec("123456000000"), "stored AC result"
call assertEq cpu~pc, octToDec("000101"), "no-skip PC increment"
call assertEq cpu~halted, 1, "single step returns halted"

/* Fast-memory alias operand: address 5 means AC5, not sparse core word 5. */
mem2 = .KL10DepositMemory~new
pc2 = octToDec("000200")
mem2~deposit(pc2, octToDec("630140000005"))   /* TDZ 3,5 */
mem2~deposit(octToDec("000005"), octToDec("000000777777")) /* must be ignored */
cpu2 = .KL10CPU~new~~loadImage(mem2, pc2)
cpu2~setAccumulator(3, octToDec("123456000077"))
cpu2~setAccumulator(5, octToDec("000000000077"))
trace2 = cpu2~step
call assertEq trace2["operand"], octToDec("000000000077"), "EA 5 reads AC5, not sparse memory[5]"
call assertEq cpu2~accumulator(3), octToDec("123456000000"), "TDZ with AC-window operand"

say "KL10 TDZ semantic acceptance: PASS"
say "  TDZ 3,20 uses ordinary memory above the AC window"
say "  TDZ 3,5 reads AC5 through PDP-10 fast-memory aliasing"
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

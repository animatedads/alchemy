/* ANDI semantic guard.  The historical MTBOOT path has AC15=0, so this
 * non-zero fixture proves the ALU operation rather than merely PC++.
 * The instruction's immediate field is not fetched through memory. */
numeric digits 30
pc = octToDec("000100")
instruction = octToDec("405640600000")   /* ANDI 15,600000 */
before = octToDec("123456765432")
expected = octToDec("000000600000")
ac15 = octToDec("15")

mem = .FetchOnlyMemory~new(pc, instruction)
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(ac15, before)

trace = cpu~step
call assertEq trace["mnemonic"], "ANDI", "mnemonic"
call assertEq trace["operand"], octToDec("600000"), "immediate operand"
call assertEq trace["effectiveAddress"], octToDec("600000"), "direct E"
call assertEq trace["acBefore"], before, "AC before"
call assertEq trace["acAfter"], expected, "trace AC after"
call assertEq cpu~accumulator(ac15), expected, "AC15 after"
call assertEq cpu~pc, pc + 1, "PC after"
call assertEq cpu~halted, 1, "halt after one step"
call assertEq mem~reads, 1, "ANDI performs instruction fetch only"

say "KL10 ANDI acceptance: PASS"
say "  AC15: 123456765432 AND 000000600000 = 000000600000"
say "  immediate E is not fetched from memory"
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

::class FetchOnlyMemory public
::method init
  expose base instruction readCount
  use arg at, word
  base = at
  instruction = word
  readCount = 0
::method word
  expose base instruction readCount
  use arg at
  readCount = readCount + 1
  if at = base then return instruction
  raise syntax 40.900 array("unexpected memory fetch at" at)
::method reads
  expose readCount
  return readCount

::requires "../KL10IPL.cls"

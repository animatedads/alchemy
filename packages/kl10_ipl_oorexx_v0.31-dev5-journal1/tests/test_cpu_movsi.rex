/* MOVSI semantic guard.  Pre-poison the destination AC with all ones so a
 * fake PC increment, MOVEI-style placement, or failure to clear RH cannot
 * pass.  MOVSI immediate data is not fetched through memory. */
numeric digits 30
pc = octToDec("000100")
instruction = octToDec("205740123456")   /* MOVSI 17,123456 */
before = octToDec("777777777777")
expected = octToDec("123456000000")
ac17 = octToDec("17")

mem = .FetchOnlyMemory~new(pc, instruction)
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(ac17, before)

trace = cpu~step
call assertEq trace["mnemonic"], "MOVSI", "mnemonic"
call assertEq trace["effectiveAddress"], octToDec("123456"), "immediate E"
call assertEq trace["operand"], expected, "swapped immediate word"
call assertEq trace["acBefore"], before, "AC17 before"
call assertEq trace["acAfter"], expected, "trace AC17 after"
call assertEq cpu~accumulator(ac17), expected, "AC17 after"
call assertEq cpu~pc, pc + 1, "PC after"
call assertEq cpu~halted, 1, "halt after one step"
call assertEq mem~reads, 1, "MOVSI performs instruction fetch only"

/* Pin the corrected string conversions so hand-written hex cannot silently
 * become a fixture oracle. */
call assertEq Oct2Hex("205740123456"), "42F80A72E", "MOVSI fixture hex"
call assertEq Oct2Hex("777777777777"), "FFFFFFFFF", "36-bit all-ones hex"
call assertEq Oct2Hex("123456000000"), "29CB80000", "MOVSI expected hex"

say "KL10 MOVSI acceptance: PASS"
say "  AC17: 777777777777 -> 123456000000"
say "  right half actively cleared; immediate E placed in left half"
say "  MOVSI performs instruction fetch only"
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
::requires "../lib/OctalBits.cls"

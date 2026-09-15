/* Plain JRST indexed effective-address guard.
 *
 * Proves the bounded JRST implementation:
 *   - accepts only JRST function AC=0,
 *   - adds the RIGHT half of AC[X] to Y modulo 2**18,
 *   - ignores the left half of AC[X],
 *   - performs no operand memory read,
 *   - preserves FLAGS.
 */
numeric digits 30
pc = octToDec("000100")
word = Oct("254003,,000100")~decimal   /* JRST 100(3) */
mem = .FetchOnlyMemory~new(pc, word)
cpu = .KL10CPU~new~~loadImage(mem, pc)

/* Poison the left half so a whole-36-bit index bug cannot pass. */
ac3 = octToDec("3")
cpu~setAccumulator(ac3, Oct("765432,,000005")~decimal)

beforeFlags = cpu~flags
trace = cpu~step

call assertEq trace["mnemonic"], "JRST", "JRST mnemonic"
call assertEq trace["fetchSource"], "MEMORY", "JRST fetch source"
call assertEq trace["effectiveAddress"], octToDec("000105"), "JRST indexed E"
call assertNil trace["operand"], "JRST has no operand word"
call assertEq trace["pcAfter"], octToDec("000105"), "JRST target PC"
call assertEq cpu~pc, octToDec("000105"), "CPU target PC"
call assertEq cpu~flags, beforeFlags, "JRST preserves FLAGS"
call assertEq mem~reads, 1, "JRST performs instruction fetch only"

say "KL10 indexed JRST acceptance: PASS"
say "  254003,,000100  JRST 100(3)"
say "  AC3=765432,,000005 -> E=000105 (RH only)"
say "  one memory read: instruction fetch only"
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

assertNil: procedure
  use arg actual, label
  if actual \== .nil then do
    say "FAIL:" label
    say "  expected: .nil"
    say "  actual:  " actual
    exit 1
  end
  return

::class FetchOnlyMemory public
::method init
  expose base instruction readCount
  use arg at, value
  base = at
  instruction = value
  readCount = 0
::method word
  expose base instruction readCount
  use arg at
  readCount = readCount + 1
  if at = base then return instruction
  raise syntax 40.900 array("unexpected JRST operand/core read at" at)
::method reads
  expose readCount
  return readCount

::requires "../KL10IPL.cls"
::requires "../lib/OctalBits.cls"

/* PDP-10 KL10 EXCH acceptance: opcode 250 octal.
 *
 * Verifies indexed section-zero effective-address calculation, ordinary
 * memory exchange, AC-window exchange, and the self-alias case.  EXCH must
 * capture both old values before either destination is changed.
 */
numeric digits 30
pc = octToDec("000100")

/* Ordinary indexed memory exchange. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("250"), 3, 0, 4, octToDec("000200")))
mem~put(octToDec("000205"), octToDec("707070252525"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("123456765432"))
cpu~setAccumulator(4, 5)
tr = cpu~step
call assertEq tr["mnemonic"], "EXCH", "EXCH decode"
call assertEq tr["effectiveAddress"], octToDec("000205"), "indexed effective address"
call assertEq tr["operand"], octToDec("707070252525"), "old memory captured"
call assertEq tr["memoryResult"], octToDec("123456765432"), "old AC deposited"
call assertEq cpu~accumulator(3), octToDec("707070252525"), "memory moves to AC"
readsBeforeVerify = mem~reads
writesBeforeVerify = mem~writes
call assertEq mem~word(octToDec("000205")), octToDec("123456765432"), "AC moves to memory"
call assertEq readsBeforeVerify, 2, "fetch plus operand read"
call assertEq writesBeforeVerify, 1, "one exchange memory write"
call assertEq cpu~flags, 0, "FLAGS unchanged"
call assertEq cpu~pc, pc + 1, "sequential PC"

/* Exchange with another live accumulator via the AC-window alias. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("250"), 3, 0, 0, 5))
mem~put(5, octToDec("111111111111"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("333333333333"))
cpu~setAccumulator(5, octToDec("555555555555"))
tr = cpu~step
call assertEq tr["effectiveAddress"], 5, "AC-window E"
call assertEq cpu~accumulator(3), octToDec("555555555555"), "AC5 old value moves to AC3"
call assertEq cpu~accumulator(5), octToDec("333333333333"), "AC3 old value moves to AC5"
call assertEq mem~word(5), octToDec("111111111111"), "hidden backing core under AC5 untouched"
call assertEq mem~writes, 0, "AC-window write never touches backing memory"

/* Self exchange is stable.  This also catches implementations that perform
 * the first write before capturing the second old value. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("250"), 6, 0, 0, 6))
mem~put(6, octToDec("222222222222"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(6, octToDec("606060606060"))
tr = cpu~step
call assertEq cpu~accumulator(6), octToDec("606060606060"), "self EXCH unchanged"
call assertEq tr["operand"], octToDec("606060606060"), "self EXCH operand is live AC"
call assertEq tr["memoryResult"], octToDec("606060606060"), "self EXCH deposited value"
call assertEq mem~word(6), octToDec("222222222222"), "self EXCH hidden core untouched"

say "KL10 EXCH acceptance: PASS"
say "  indexed ordinary memory swaps C(AC) and C(E)"
say "  AC-window E exchanges two live accumulators"
say "  self-alias exchange is stable and backing core remains hidden"
exit 0

makeInstruction: procedure
  use arg opcode, ac, indirect, x, address
  numeric digits 30
  return opcode * (2 ** 27) + ac * (2 ** 23) + indirect * (2 ** 22) + x * (2 ** 18) + address

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

::class CountingMemory public
::method init
  expose words readCount writeCount
  words = .directory~new
  readCount = 0
  writeCount = 0
::method put
  expose words writeCount
  use arg address, value
  numeric digits 30
  words[address] = value // (2 ** 36)
  writeCount = writeCount + 1
  return self
::method word
  expose words readCount
  use arg address
  readCount = readCount + 1
  if words~hasIndex(address) then return words[address]
  return 0
::method reads
  expose readCount
  return readCount
::method writes
  expose writeCount
  return writeCount
::method resetCounts
  expose readCount writeCount
  readCount = 0
  writeCount = 0
  return self

::requires "../KL10IPL.cls"

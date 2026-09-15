/* KL10 AOBJP/AOBJN acceptance: opcodes 252/253 octal. */
numeric digits 30
pc = octToDec("000100")
y = octToDec("000200")

/* AOBJN: negative left half remains negative, so branch. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("253"), 3, 0, 4, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("777776000010"))
cpu~setAccumulator(4, 5)
tr = cpu~step
call assertEq tr["mnemonic"], "AOBJN", "AOBJN decode"
call assertEq tr["effectiveAddress"], y + 5, "AOBJN indexed E"
call assertEq cpu~accumulator(3), octToDec("777777000011"), "AOBJN increments both halves"
call assertEq tr["branchTaken"], 1, "AOBJN negative branches"
call assertEq cpu~pc, y + 5, "AOBJN branch target"
call assertEq mem~reads, 1, "AOBJN instruction fetch only"
call assertEq cpu~flags, 0, "AOBJN FLAGS unchanged"

/* AOBJN falls through when the left half reaches zero. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("253"), 3, 0, 0, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("777777000010"))
tr = cpu~step
call assertEq cpu~accumulator(3), octToDec("000000000011"), "AOBJN count reaches zero"
call assertEq tr["branchTaken"], 0, "AOBJN zero-left falls through"
call assertEq cpu~pc, pc + 1, "AOBJN fallthrough PC"

/* AOBJP is the complementary nonnegative test. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("252"), 2, 0, 0, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(2, octToDec("777777000777"))
tr = cpu~step
call assertEq cpu~accumulator(2), octToDec("000000001000"), "AOBJP increment"
call assertEq tr["branchTaken"], 1, "AOBJP nonnegative branches"
call assertEq cpu~pc, y, "AOBJP branch target"

/* KL10-specific rollover: halves increment independently.  RH 777777 wraps
 * to zero without carrying an additional one into LH. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("253"), 6, 0, 0, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(6, octToDec("777776777777"))
tr = cpu~step
call assertEq cpu~accumulator(6), octToDec("777777000000"), "KL10 independent-half rollover"
call assertEq tr["branchTaken"], 1, "KL10 rollover remains negative"

say "KL10 AOBJ acceptance: PASS"
say "  252 AOBJP / 253 AOBJN increment both 18-bit halves independently"
say "  branch sign test, indexed E and KL10 RH-rollover behavior verified"
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
  numeric digits 30
  use arg address, value
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

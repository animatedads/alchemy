/* PDP-10 shift/rotate family acceptance: opcodes 240..246 octal. */
numeric digits 30
pc = octToDec("000100")

/* ASH left, non-overflow. */
call runSingle "240", 3, "000003", "000001234567", "000012345670", 0, "ASH left 3"
/* ASH right with sign extension. */
call runSingle "240", 3, "777775", "400000000001", "740000000000", 0, "ASH right 3"
/* ASH left overflow raises OVR+TRP1 without inventing carry flags. */
call runSingle "240", 3, "000003", "123456765432", "234567654320", octToDec("010004"), "ASH overflow"

/* ROT left and the negative-count low-8-zero corner (right 256). */
call runSingle "241", 3, "000005", "123456765432", "162737261505", 0, "ROT left 5"
call runSingle "241", 3, "400000", "123456765432", "505162737261", 0, "ROT right 256"

/* LSH left plus the exact MTBOOT right-nine count. */
call runSingle "242", 3, "000005", "123456765432", "162737261500", 0, "LSH left 5"
call runSingle "242", 3, "777767", "000000047000", "000000000047", 0, "LSH MTBOOT right 9"

/* JFFO stores the leading-zero count in AC+1 and branches only if AC != 0. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("243"), 3, 0, 0, octToDec("000240")))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("000001000000"))
cpu~setAccumulator(4, octToDec("777777777777"))
tr = cpu~step
call assertEq tr["mnemonic"], "JFFO", "JFFO decode"
call assertEq cpu~pc, octToDec("000240"), "JFFO branch target"
call assertEq cpu~accumulator(4), 17, "JFFO leading-zero count"
call assertEq tr["branchTaken"], 1, "JFFO branch evidence"
call assertEq mem~reads, 1, "JFFO instruction fetch only"

mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("243"), 3, 0, 0, octToDec("000240")))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, 0)
cpu~setAccumulator(4, 77)
tr = cpu~step
call assertEq cpu~pc, pc + 1, "JFFO zero falls through"
call assertEq cpu~accumulator(4), 0, "JFFO zero stores zero count"
call assertEq tr["branchTaken"], 0, "JFFO zero branch evidence"

/* ASHC links AC and AC+1 while preserving the arithmetic sign convention. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("244"), 3, 0, 0, octToDec("000004")))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("000001234567"))
cpu~setAccumulator(4, octToDec("012345670123"))
tr = cpu~step
call assertEq cpu~accumulator(3), octToDec("000024713560"), "ASHC high"
call assertEq cpu~accumulator(4), octToDec("247135602460"), "ASHC low"
call assertEq cpu~flags, 0, "ASHC no overflow flags"
call assertEq mem~reads, 1, "ASHC instruction fetch only"

/* ROTC is a 72-bit rotate across the AC pair. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("245"), 3, 0, 0, octToDec("000007")))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("123456765432"))
cpu~setAccumulator(4, octToDec("012345670123"))
tr = cpu~step
call assertEq cpu~accumulator(3), octToDec("713575306402"), "ROTC high"
call assertEq cpu~accumulator(4), octToDec("471356024624"), "ROTC low"
call assertEq cpu~flags, 0, "ROTC flags unchanged"

/* LSHC is a logical 72-bit shift. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("246"), 3, 0, 0, octToDec("777771"))) /* right 7 */
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, octToDec("123456765432"))
cpu~setAccumulator(4, octToDec("012345670123"))
tr = cpu~step
call assertEq cpu~accumulator(3), octToDec("000516273726"), "LSHC high"
call assertEq cpu~accumulator(4), octToDec("150051627340"), "LSHC low"
call assertEq cpu~flags, 0, "LSHC flags unchanged"

/* AC17 pair instructions wrap AC+1 to AC0 just as the 4-bit AC selector does. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("246"), octToDec("17"), 0, 0, 1))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(octToDec("17"), octToDec("000000000001"))
cpu~setAccumulator(0, octToDec("400000000000"))
tr = cpu~step
call assertEq cpu~accumulator(octToDec("17")), octToDec("000000000003"), "LSHC AC17 high"
call assertEq cpu~accumulator(0), 0, "LSHC AC17 pair wraps to AC0"

say "KL10 shift/rotate family acceptance: PASS"
say "  240 ASH, 241 ROT, 242 LSH, 243 JFFO"
say "  244 ASHC, 245 ROTC, 246 LSHC"
say "  signed counts, overflow flags, AC-pair flow and AC17->AC0 wrap verified"
exit 0

runSingle: procedure
  use arg opcodeText, acNo, yText, inputText, expectedText, expectedFlags, label
  pc = octToDec("000100")
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(octToDec(opcodeText), acNo, 0, 0, octToDec(yText)))
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(acNo, octToDec(inputText))
  tr = cpu~step
  call assertEq tr["mnemonic"], word("ASH ROT LSH JFFO ASHC ROTC LSHC", octToDec(opcodeText) - octToDec("240") + 1), label "decode"
  call assertEq cpu~accumulator(acNo), octToDec(expectedText), label "result"
  call assertEq cpu~flags, expectedFlags, label "FLAGS"
  call assertEq mem~reads, 1, label "instruction fetch only"
  return

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

/* PDP-10 SOJ family acceptance: opcodes 360..367 octal. */
numeric digits 30
pc = octToDec("000100")
y = octToDec("000200")
names = "SOJ SOJL SOJE SOJLE SOJA SOJGE SOJN SOJG"

/* Values are tested after decrement. */
before = .array~of(8, 0, 1, 1, 8, 8, 8, 8)
expectedJump = .array~of(0, 1, 1, 1, 1, 1, 1, 1)
do opcode = octToDec("360") to octToDec("367")
  kind = opcode - octToDec("360")
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 3, 0, 4, y))
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(3, before[kind + 1])
  cpu~setAccumulator(4, 5)
  tr = cpu~step
  expected = before[kind + 1] - 1
  if expected < 0 then expected = expected + (2 ** 36)
  call assertEq tr["mnemonic"], word(names, kind + 1), word(names, kind + 1) "decode"
  call assertEq tr["effectiveAddress"], y + 5, word(names, kind + 1) "indexed E"
  call assertEq cpu~accumulator(3), expected, word(names, kind + 1) "decremented AC"
  call assertEq tr["branchTaken"], expectedJump[kind + 1], word(names, kind + 1) "branch"
  if expectedJump[kind + 1] then expectedPc = y + 5
  else expectedPc = pc + 1
  call assertEq cpu~pc, expectedPc, word(names, kind + 1) "PC"
  call assertEq mem~reads, 1, word(names, kind + 1) "instruction fetch only"
  call assertEq mem~writes, 0, word(names, kind + 1) "no memory write"
end

/* False SOJG: 1 decrements to zero and falls through. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("367"), 5, 0, 0, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(5, 1)
tr = cpu~step
call assertEq cpu~accumulator(5), 0, "SOJG zero result"
call assertEq tr["branchTaken"], 0, "SOJG zero does not jump"
call assertEq cpu~pc, pc + 1, "SOJG zero fallthrough"

/* Signed overflow edge: most-negative - 1 -> largest-positive. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("360"), 2, 0, 0, y))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(2, octToDec("400000000000"))
ov = cpu~step
call assertEq cpu~accumulator(2), octToDec("377777777777"), "SOJ overflow result"
call assertEq ov["overflow"], 1, "SOJ overflow evidence"
call assertEq cpu~flags, octToDec("014004"), "SOJ overflow flags"

say "KL10 SOJ family acceptance: PASS"
say "  360..367 decrement-before-test, indexed branch target and no operand read"
say "  SOJG fallthrough and signed-overflow edge verified"
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

/* PDP-10 AOS family acceptance: opcodes 350..357 octal. */
numeric digits 30
pc = octToDec("000100")
y = octToDec("000200")
names = "AOS AOSL AOSE AOSLE AOSA AOSGE AOSN AOSG"

/* All eight condition forms: memory is incremented first, then tested. */
before = .array~of(7, octToDec("377777777777"), octToDec("777777777777"), octToDec("777777777777"), 7, 7, 7, 7)
expectedSkip = .array~of(0, 1, 1, 1, 1, 1, 1, 1)
do opcode = octToDec("350") to octToDec("357")
  kind = opcode - octToDec("350")
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 3, 0, 4, y))
  mem~put(y + 5, before[kind + 1])
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(3, octToDec("123456654321"))
  cpu~setAccumulator(4, 5)
  tr = cpu~step
  expected = (before[kind + 1] + 1) // (2 ** 36)
  call assertEq tr["mnemonic"], word(names, kind + 1), word(names, kind + 1) "decode"
  call assertEq tr["effectiveAddress"], y + 5, word(names, kind + 1) "indexed E"
  call assertEq tr["operand"], before[kind + 1], word(names, kind + 1) "operand before"
  call assertEq mem~word(y + 5), expected, word(names, kind + 1) "memory increment"
  call assertEq cpu~accumulator(3), expected, word(names, kind + 1) "nonzero AC load"
  call assertEq tr["skipTaken"], expectedSkip[kind + 1], word(names, kind + 1) "skip"
  call assertEq cpu~pc, pc + 1 + expectedSkip[kind + 1], word(names, kind + 1) "PC"
end

/* AC0 suppresses the result copy but not the storage modification. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("350"), 0, 0, 0, y))
mem~put(y, 41)
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(0, octToDec("765432123456"))
tr = cpu~step
call assertEq mem~word(y), 42, "AOS AC0 memory result"
call assertEq cpu~accumulator(0), octToDec("765432123456"), "AOS AC0 suppresses AC load"
call assertEq tr["skipTaken"], 0, "plain AOS does not skip"

/* Critical MTBOOT fast-memory form: E=11(octal) is AC11 itself. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("350"), 0, 0, 0, octToDec("11")))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(octToDec("11"), octToDec("000000011000"))
tr = cpu~step
call assertEq tr["effectiveAddress"], octToDec("11"), "MTBOOT AOS E=AC11"
call assertEq cpu~accumulator(octToDec("11")), octToDec("000000011001"), "MTBOOT AOS increments live AC11"
call assertEq mem~writes, 0, "AC-window AOS does not write backing memory"

/* Carry/overflow boundary: 377777777777 + 1 -> 400000000000. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("350"), 0, 0, 0, y))
mem~put(y, octToDec("377777777777"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
ov = cpu~step
call assertEq mem~word(y), octToDec("400000000000"), "AOS signed overflow result"
call assertEq ov["carry1"], 1, "AOS overflow carry1"
call assertEq ov["carry0"], 0, "AOS overflow carry0"
call assertEq ov["overflow"], 1, "AOS overflow evidence"
call assertEq cpu~flags, octToDec("012004"), "AOS overflow flags"

say "KL10 AOS family acceptance: PASS"
say "  350..357 increment-before-test, AC copy/suppression and skip conditions"
say "  live AC-window storage and arithmetic flags verified"
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

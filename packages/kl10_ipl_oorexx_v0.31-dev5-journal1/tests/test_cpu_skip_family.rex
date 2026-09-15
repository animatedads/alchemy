/* PDP-10 SKIP family acceptance: opcodes 330..337 octal. */
numeric digits 30
pc = octToDec("000100")
y = octToDec("000200")
indexAdd = 5
ea = y + indexAdd
names = "SKIP SKIPL SKIPE SKIPLE SKIPA SKIPGE SKIPN SKIPG"

/* Exercise each condition with a value chosen to make its truth value visible. */
values = .array~of(1, octToDec("400000000001"), 0, 0, 1, 1, 1, 1)
expectedSkip = .array~of(0, 1, 1, 1, 1, 1, 1, 1)
do opcode = octToDec("330") to octToDec("337")
  kind = opcode - octToDec("330")
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 3, 0, 4, y))
  mem~put(ea, values[kind + 1])
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(3, octToDec("777777777777"))
  cpu~setAccumulator(4, indexAdd)
  tr = cpu~step
  call assertEq tr["mnemonic"], word(names, kind + 1), word(names, kind + 1) "decode"
  call assertEq tr["effectiveAddress"], ea, word(names, kind + 1) "indexed E"
  call assertEq tr["skipTaken"], expectedSkip[kind + 1], word(names, kind + 1) "skip"
  call assertEq cpu~pc, pc + 1 + expectedSkip[kind + 1], word(names, kind + 1) "PC"
  call assertEq cpu~accumulator(3), values[kind + 1], word(names, kind + 1) "loads AC"
  call assertEq mem~reads, 2, word(names, kind + 1) "instruction+operand reads"
  call assertEq mem~writes, 0, word(names, kind + 1) "no memory write"
  call assertEq cpu~flags, 0, word(names, kind + 1) "FLAGS unchanged"
end

/* False cases for the conditional forms. */
call runFalse "331", 1, "SKIPL positive"
call runFalse "332", 1, "SKIPE nonzero"
call runFalse "333", 1, "SKIPLE positive"
call runFalse "335", "400000000001", "SKIPGE negative"
call runFalse "336", 0, "SKIPN zero"
call runFalse "337", 0, "SKIPG zero"

/* AC0 suppresses the accumulator load but still performs the memory read. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("334"), 0, 0, 0, y))
mem~put(y, octToDec("123456765432"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(0, octToDec("777777777777"))
tr = cpu~step
call assertEq cpu~accumulator(0), octToDec("777777777777"), "SKIPA AC0 suppression"
call assertEq cpu~pc, pc + 2, "SKIPA still skips"
call assertEq mem~reads, 2, "SKIPA AC0 still reads memory"

say "KL10 SKIP family acceptance: PASS"
say "  all eight opcodes 330..337 exercised"
say "  signed/zero conditions, indexed E, AC load and AC0 suppression verified"
exit 0

runFalse: procedure
  use arg opcodeText, valueText, label
  pc = octToDec("000100")
  ea = octToDec("000200")
  if datatype(valueText, "W") then value = valueText
  else value = octToDec(valueText)
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(octToDec(opcodeText), 3, 0, 0, ea))
  mem~put(ea, value)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  tr = cpu~step
  call assertEq tr["skipTaken"], 0, label
  call assertEq cpu~pc, pc + 1, label "PC"
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

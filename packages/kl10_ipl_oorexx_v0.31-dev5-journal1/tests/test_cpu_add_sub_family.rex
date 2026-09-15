/* ADD/SUB family acceptance for opcodes 270..277. */
numeric digits 30

/* Basic destination semantics for all eight family members. */
call runCase "ADD",  "270", 5, 7, 12, 7, 12, 0
call runCase "ADDI", "271", 5, 7, 12, 99, 12, 0
call runCase "ADDM", "272", 5, 7, 5, 12, 12, 1
call runCase "ADDB", "273", 5, 7, 12, 12, 12, 1
call runCase "SUB",  "274", 12, 5, 7, 5, 7, 0
call runCase "SUBI", "275", 12, 5, 7, 99, 7, 0
call runCase "SUBM", "276", 12, 5, 12, 7, 7, 1
call runCase "SUBB", "277", 12, 5, 7, 7, 7, 1

/* Exact MTBOOT SUBI state: AC16 000000,,040011 - 11 = 000000,,040000.
 * Cornwell's arithmetic path sets both carry flags and no overflow. */
pc = octToDec("000100")
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("275"), octToDec("16"), 0, 0, octToDec("11")))
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(octToDec("16"), octToDec("000000040011"))
tr = cpu~step
call assertEq tr["mnemonic"], "SUBI", "MTBOOT SUBI mnemonic"
call assertEq tr["operand"], octToDec("11"), "MTBOOT SUBI operand"
call assertEq cpu~accumulator(octToDec("16")), octToDec("000000040000"), "MTBOOT SUBI result"
call assertEq cpu~flags, octToDec("006000"), "MTBOOT SUBI carry flags"
call assertEq tr["carry1"], 1, "MTBOOT SUBI carry1"
call assertEq tr["carry0"], 1, "MTBOOT SUBI carry0"
call assertEq tr["overflow"], 0, "MTBOOT SUBI overflow"
call assertEq mem~reads, 1, "SUBI instruction fetch only"

/* Signed overflow: largest positive 36-bit value + 1 -> most negative. */
pc = octToDec("000120")
mem2 = .CountingMemory~new
mem2~put(pc, makeInstruction(octToDec("271"), 1, 0, 0, 1))
cpu2 = .KL10CPU~new~~loadImage(mem2, pc)
cpu2~setAccumulator(1, octToDec("377777777777"))
ov = cpu2~step
call assertEq cpu2~accumulator(1), octToDec("400000000000"), "ADD overflow result"
call assertEq ov["carry1"], 1, "ADD overflow carry1"
call assertEq ov["carry0"], 0, "ADD overflow carry0"
call assertEq ov["overflow"], 1, "ADD overflow evidence"
call assertEq cpu2~flags, octToDec("012004"), "ADD overflow flags CRY1+OVR+TRP1"

/* Indexed immediate: E is resolved before becoming the immediate operand. */
pc = octToDec("000140")
mem3 = .CountingMemory~new
mem3~put(pc, makeInstruction(octToDec("271"), 2, 0, 3, octToDec("20")))
cpu3 = .KL10CPU~new~~loadImage(mem3, pc)
cpu3~setAccumulator(2, 1)
cpu3~setAccumulator(3, octToDec("765432000005"))
ix = cpu3~step
call assertEq ix["effectiveAddress"], octToDec("25"), "indexed ADDI E"
call assertEq ix["operand"], octToDec("25"), "indexed ADDI immediate"
call assertEq cpu3~accumulator(2), octToDec("26"), "indexed ADDI result"
call assertEq mem3~reads, 1, "indexed ADDI no operand read"

say "KL10 ADD/SUB family acceptance: PASS"
say "  270..273 ADD/ADDI/ADDM/ADDB destination forms"
say "  274..277 SUB/SUBI/SUBM/SUBB destination forms"
say "  MTBOOT SUBI carry flags = 006000"
say "  signed overflow produces CRY1+OVR+TRP1"
exit 0

runCase: procedure expose makeInstruction octToDec assertEq
  use arg name, opText, acStart, operand, expectedAc, expectedMem, expectedResult, expectWrite
  numeric digits 30
  pc = octToDec("000100")
  ea = octToDec("000200")
  opcode = octToDec(opText)
  form = opcode // 4
  mem = .CountingMemory~new
  instructionAddress = ea
  if form = 1 then instructionAddress = operand
  mem~put(pc, makeInstruction(opcode, 1, 0, 0, instructionAddress))
  if form = 1 then mem~put(ea, expectedMem)
  else mem~put(ea, operand)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(1, acStart)
  tr = cpu~step
  call assertEq tr["mnemonic"], name, name "mnemonic"
  call assertEq tr["result"], expectedResult, name "result evidence"
  call assertEq cpu~accumulator(1), expectedAc, name "AC destination"
  if form = 1 then do
    call assertEq mem~word(ea), expectedMem, name "immediate leaves memory"
  end
  else call assertEq mem~word(ea), expectedMem, name "memory destination/state"
  if expectWrite then call assertEq mem~writes, 1, name "memory write count"
  else call assertEq mem~writes, 0, name "no memory write"
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

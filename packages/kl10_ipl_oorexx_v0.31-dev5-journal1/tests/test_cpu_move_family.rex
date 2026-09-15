/* PDP-10 MOVE family acceptance: opcodes 200..207 octal.
 *
 * Exercises all eight forms against live memory, including the genuine
 * modify-cycle writes of MOVES/MOVSS and a write into the AC-window alias.
 */
numeric digits 30
pc = octToDec("000100")
y = octToDec("000200")
indexAdd = octToDec("000005")
ea = octToDec("000205")
aValue = octToDec("123456765432")
mValue = octToDec("707070252525")

names = "MOVE MOVEI MOVEM MOVES MOVS MOVSI MOVSM MOVSS"
do opcode = octToDec("200") to octToDec("207")
  kind = opcode - octToDec("200")
  name = word(names, kind + 1)

  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 3, 0, 4, y))
  mem~put(ea, mValue)
  mem~resetCounts

  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(3, aValue)
  cpu~setAccumulator(4, indexAdd)

  tr = cpu~step
  call assertEq tr["mnemonic"], name, name "decode"
  call assertEq tr["effectiveAddress"], ea, name "indexed E"

  select
    when kind = 0 then do /* MOVE */
      expectedAc = mValue
      expectedMem = mValue
      expectedReads = 2
      expectedWrites = 0
      expectedResult = mValue
    end
    when kind = 1 then do /* MOVEI */
      expectedAc = ea
      expectedMem = mValue
      expectedReads = 1
      expectedWrites = 0
      expectedResult = ea
    end
    when kind = 2 then do /* MOVEM */
      expectedAc = aValue
      expectedMem = aValue
      expectedReads = 1
      expectedWrites = 1
      expectedResult = aValue
    end
    when kind = 3 then do /* MOVES */
      expectedAc = mValue
      expectedMem = mValue
      expectedReads = 2
      expectedWrites = 1
      expectedResult = mValue
    end
    when kind = 4 then do /* MOVS */
      expectedResult = swapOracle(mValue)
      expectedAc = expectedResult
      expectedMem = mValue
      expectedReads = 2
      expectedWrites = 0
    end
    when kind = 5 then do /* MOVSI */
      expectedResult = swapOracle(ea)
      expectedAc = expectedResult
      expectedMem = mValue
      expectedReads = 1
      expectedWrites = 0
    end
    when kind = 6 then do /* MOVSM */
      expectedResult = swapOracle(aValue)
      expectedAc = aValue
      expectedMem = expectedResult
      expectedReads = 1
      expectedWrites = 1
    end
    when kind = 7 then do /* MOVSS */
      expectedResult = swapOracle(mValue)
      expectedAc = expectedResult
      expectedMem = expectedResult
      expectedReads = 2
      expectedWrites = 1
    end
  end

  call assertEq tr["result"], expectedResult, name "result"
  call assertEq cpu~accumulator(3), expectedAc, name "AC destination"
  readsBeforeVerify = mem~reads
  writesBeforeVerify = mem~writes
  call assertEq mem~word(ea), expectedMem, name "memory state"
  call assertEq readsBeforeVerify, expectedReads, name "read count"
  call assertEq writesBeforeVerify, expectedWrites, name "write count"
  call assertEq cpu~flags, 0, name "FLAGS unchanged"
end

/* MOVES/MOVSS with AC=0 still perform the modify-cycle memory write, but do
 * not load AC0. */
do opcode = octToDec("203") to octToDec("207") by 4
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 0, 0, 0, ea))
  mem~put(ea, mValue)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(0, aValue)
  tr = cpu~step
  call assertEq cpu~accumulator(0), aValue, tr["mnemonic"] "AC0 suppression"
  call assertEq mem~writes, 1, tr["mnemonic"] "modify-cycle write retained"
end

/* Memory destination 17 octal is the live AC17 alias, not hidden backing
 * core.  MOVEM therefore deposits through the address-space object. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("202"), 3, 0, 0, octToDec("17")))
mem~put(octToDec("17"), octToDec("111111222222"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, aValue)
cpu~setAccumulator(octToDec("17"), octToDec("000000000001"))
tr = cpu~step
call assertEq cpu~accumulator(octToDec("17")), aValue, "MOVEM to address 17 updates AC17"
call assertEq mem~word(octToDec("17")), octToDec("111111222222"), "hidden backing core under AC17 untouched"

say "KL10 MOVE family acceptance: PASS"
say "  all eight opcodes 200..207 exercised with indexed E"
say "  MOVES/MOVSS preserve real modify-cycle writes and AC0 suppression"
say "  MOVEM through address 000017 updates live AC17 alias"
exit 0

swapOracle: procedure
  use arg value
  return .LROct~new(.LROct~fromDecimal(value)~right || .LROct~fromDecimal(value)~left)~decimal

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

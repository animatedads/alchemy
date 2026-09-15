/* Exhaustive PDP-10 Boolean family acceptance: opcodes 400..477 octal. */
numeric digits 30
pc = octToDec("000100")
ea = octToDec("000200")
aValue = octToDec("123456765432")
mValue = octToDec("707070252525")
allCount = 0

bases = "SETZ AND ANDCA SETM ANDCM SETA XOR IOR ANDCB EQV SETCA ORCA SETCM ORCM ORCB SETO"
do opcode = octToDec("400") to octToDec("477")
  group = (opcode - octToDec("400")) % 4
  form = opcode // 4
  base = word(bases, group + 1)
  select
    when form = 0 then expectedName = base
    when form = 1 then expectedName = base || "I"
    when form = 2 then expectedName = base || "M"
    when form = 3 then expectedName = base || "B"
  end

  mem = .CountingMemory~new
  instructionAddress = ea
  if form = 1 then instructionAddress = octToDec("123456")
  mem~put(pc, makeInstruction(opcode, 3, 0, 0, instructionAddress))
  mem~put(ea, mValue)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(3, aValue)

  tr = cpu~step
  call assertEq tr["mnemonic"], expectedName, expectedName "decode"
  call assertEq tr["effectiveAddress"], instructionAddress, expectedName "E"

  if form = 1 then operand = instructionAddress
  else operand = mValue
  expected = boolOracle(group, aValue, operand)
  call assertEq tr["result"], expected, expectedName "result"

  if form = 0 | form = 1 | form = 3 then expectedAc = expected
  else expectedAc = aValue
  call assertEq cpu~accumulator(3), expectedAc, expectedName "AC destination"

  readsBeforeVerify = mem~reads
  writesBeforeVerify = mem~writes
  currentMem = mem~word(ea)

  if form = 2 | form = 3 then expectedMem = expected
  else expectedMem = mValue
  /* SETMB's nominal B destination is already M; Cornwell avoids a redundant write. */
  call assertEq currentMem, expectedMem, expectedName "memory state"

  needsOperand = 1
  if group = 0 | group = 5 | group = 10 | group = 15 then needsOperand = 0
  expectedReads = 1
  if form \= 1 & needsOperand then expectedReads = 2
  call assertEq readsBeforeVerify, expectedReads, expectedName "read count"

  expectedWrites = 0
  if form = 2 then expectedWrites = 1
  if form = 3 & group \= 3 then expectedWrites = 1
  call assertEq writesBeforeVerify, expectedWrites, expectedName "write count"
  call assertEq cpu~flags, 0, expectedName "FLAGS unchanged"
  allCount = allCount + 1
end

call assertEq allCount, 64, "Boolean opcode count"
say "KL10 Boolean family acceptance: PASS"
say "  all 64 opcodes 400..477 exercised"
say "  memory/immediate/M/B destinations and live writes verified"
say "  Boolean operations leave FLAGS unchanged"
exit 0

boolOracle: procedure
  use arg group, a, m
  aBits = .LROct~fromDecimal(a)~bits
  mBits = .LROct~fromDecimal(m)~bits
  out = ""
  do i = 1 to 36
    av = aBits~substr(i, 1)
    mv = mBits~substr(i, 1)
    select
      when group = 0 then bit = 0
      when group = 1 then bit = (av = 1 & mv = 1)
      when group = 2 then bit = (mv = 1 & av = 0)
      when group = 3 then bit = mv
      when group = 4 then bit = (av = 1 & mv = 0)
      when group = 5 then bit = av
      when group = 6 then bit = (av \= mv)
      when group = 7 then bit = (av = 1 | mv = 1)
      when group = 8 then bit = (av = 0 & mv = 0)
      when group = 9 then bit = (av = mv)
      when group = 10 then bit = (av = 0)
      when group = 11 then bit = (mv = 1 | av = 0)
      when group = 12 then bit = (mv = 0)
      when group = 13 then bit = (av = 1 | mv = 0)
      when group = 14 then bit = \(av = 1 & mv = 1)
      when group = 15 then bit = 1
    end
    if bit then out = out || "1"
    else out = out || "0"
  end
  return .LROct~fromBits(out)~decimal

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

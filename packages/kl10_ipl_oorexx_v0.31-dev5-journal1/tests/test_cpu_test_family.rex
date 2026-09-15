/* Exhaustive PDP-10 logical-test family acceptance: 600..677 octal. */
numeric digits 30
pc = octToDec("000100")
ea = octToDec("000200")
aValue = octToDec("123456654321")
mValue = octToDec("707070070707")
count = 0

do opcode = octToDec("600") to octToDec("677")
  mem = .CountingMemory~new
  mem~put(pc, makeInstruction(opcode, 4, 0, 0, ea))
  mem~put(ea, mValue)
  mem~resetCounts
  cpu = .KL10CPU~new~~loadImage(mem, pc)
  cpu~setAccumulator(4, aValue)

  tr = cpu~step
  expectedName = expectedMnemonic(opcode)
  call assertEq tr["mnemonic"], expectedName, expectedName "decode"

  offset = opcode - octToDec("600")
  operation = offset % 16
  within = offset // 16
  leftTest = within // 2
  if within >= 8 then memoryTest = 1
  else memoryTest = 0
  condition = (within // 8) - leftTest

  if memoryTest then operand = mValue
  else operand = ea
  if leftTest then operand = swapHalves(operand)

  tested = bitAnd(aValue, operand)
  select
    when condition = 0 then skip = 0
    when condition = 2 then skip = tested = 0
    when condition = 4 then skip = 1
    when condition = 6 then skip = tested \= 0
  end

  select
    when operation = 0 then expectedAc = aValue
    when operation = 1 then expectedAc = bitAnd(aValue, bitNot(operand))
    when operation = 2 then expectedAc = bitXor(aValue, operand)
    when operation = 3 then expectedAc = bitOr(aValue, operand)
  end

  call assertEq tr["operand"], operand, expectedName "operand"
  call assertEq tr["testValue"], tested, expectedName "tested value"
  call assertEq tr["testSkip"], skip, expectedName "skip evidence"
  call assertEq cpu~accumulator(4), expectedAc, expectedName "AC result"
  call assertEq cpu~pc, pc + 1 + skip, expectedName "PC/skip"
  call assertEq cpu~flags, 0, expectedName "FLAGS unchanged"
  if memoryTest then expectedReads = 2
  else expectedReads = 1
  call assertEq mem~reads, expectedReads, expectedName "read count"
  call assertEq mem~writes, 0, expectedName "no memory writes"
  count = count + 1
end

call assertEq count, 64, "test opcode count"
/* Explicit mnemonic anchors across the matrix. */
call assertEq expectedMnemonic(octToDec("600")), "TRN", "600 mnemonic"
call assertEq expectedMnemonic(octToDec("603")), "TLNE", "603 mnemonic"
call assertEq expectedMnemonic(octToDec("614")), "TDNA", "614 mnemonic"
call assertEq expectedMnemonic(octToDec("637")), "TSZN", "637 mnemonic"
call assertEq expectedMnemonic(octToDec("642")), "TRCE", "642 mnemonic"
call assertEq expectedMnemonic(octToDec("665")), "TLOA", "665 mnemonic"
call assertEq expectedMnemonic(octToDec("677")), "TSON", "677 mnemonic"

say "KL10 logical-test family acceptance: PASS"
say "  all 64 opcodes 600..677 exercised"
say "  right/left, direct/swapped-memory, N/Z/C/O and E/A/N skip forms verified"
say "  test instructions never write memory and leave FLAGS unchanged"
exit 0

expectedMnemonic: procedure
  use arg opcode
  base = octToDec("600")
  offset = opcode - base
  operation = offset % 16
  within = offset // 16
  leftTest = within // 2
  if within >= 8 then memoryTest = 1
  else memoryTest = 0
  condition = (within // 8) - leftTest
  if memoryTest then do
    if leftTest then addr = "S"
    else addr = "D"
  end
  else do
    if leftTest then addr = "L"
    else addr = "R"
  end
  opchar = word("N Z C O", operation + 1)
  select
    when condition = 0 then suffix = ""
    when condition = 2 then suffix = "E"
    when condition = 4 then suffix = "A"
    when condition = 6 then suffix = "N"
  end
  return "T" || addr || opchar || suffix

swapHalves: procedure
  use arg value
  w = .LROct~fromDecimal(value)
  return .LROct~new(w~right || w~left)~decimal

bitAnd: procedure
  use arg a, b
  ab = .LROct~fromDecimal(a)~bits
  bb = .LROct~fromDecimal(b)~bits
  out = ""
  do i = 1 to 36
    if ab~substr(i,1) = "1" & bb~substr(i,1) = "1" then out = out || "1"
    else out = out || "0"
  end
  return .LROct~fromBits(out)~decimal

bitOr: procedure
  use arg a, b
  ab = .LROct~fromDecimal(a)~bits
  bb = .LROct~fromDecimal(b)~bits
  out = ""
  do i = 1 to 36
    if ab~substr(i,1) = "1" | bb~substr(i,1) = "1" then out = out || "1"
    else out = out || "0"
  end
  return .LROct~fromBits(out)~decimal

bitXor: procedure
  use arg a, b
  ab = .LROct~fromDecimal(a)~bits
  bb = .LROct~fromDecimal(b)~bits
  out = ""
  do i = 1 to 36
    if ab~substr(i,1) \= bb~substr(i,1) then out = out || "1"
    else out = out || "0"
  end
  return .LROct~fromBits(out)~decimal

bitNot: procedure
  use arg a
  ab = .LROct~fromDecimal(a)~bits
  out = ""
  do i = 1 to 36
    if ab~substr(i,1) = "1" then out = out || "0"
    else out = out || "1"
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

/* PDP-10 KL10 BLT acceptance: opcode 251 octal.
 *
 * Verifies inclusive forward word copying, architectural final AC state,
 * AC-window destinations, overlap semantics, and the reference ordering where
 * the final BLT pointer is placed in AC before memory cycles begin.
 */
numeric digits 30
pc = octToDec("000100")

/* Ordinary three-word forward copy. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("251"), 3, 0, 0, octToDec("000202")))
mem~put(octToDec("000400"), octToDec("111111222222"))
mem~put(octToDec("000401"), octToDec("333333444444"))
mem~put(octToDec("000402"), octToDec("555555666666"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(3, pair(octToDec("000400"), octToDec("000200")))
tr = cpu~step
call assertEq tr["mnemonic"], "BLT", "BLT decode"
call assertEq tr["bltTransferCount"], 3, "three inclusive transfers"
call assertEq mem~word(octToDec("000200")), octToDec("111111222222"), "destination word 0"
call assertEq mem~word(octToDec("000201")), octToDec("333333444444"), "destination word 1"
call assertEq mem~word(octToDec("000202")), octToDec("555555666666"), "destination word 2"
call assertEq cpu~accumulator(3), pair(octToDec("000403"), octToDec("000203")), "BLT final AC one past end"
call assertEq cpu~pc, pc + 1, "BLT sequential PC"

/* Destination 1..3 is live fast memory, not hidden backing core. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("251"), octToDec("14"), 0, 0, octToDec("3")))
mem~put(octToDec("000500"), octToDec("200612000000"))
mem~put(octToDec("000501"), octToDec("250611000000"))
mem~put(octToDec("000502"), octToDec("202612000000"))
mem~put(1, octToDec("111111111111"))
mem~put(2, octToDec("222222222222"))
mem~put(3, octToDec("333333333333"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(octToDec("14"), pair(octToDec("000500"), 1))
tr = cpu~step
call assertEq cpu~accumulator(1), octToDec("200612000000"), "BLT writes live AC1"
call assertEq cpu~accumulator(2), octToDec("250611000000"), "BLT writes live AC2"
call assertEq cpu~accumulator(3), octToDec("202612000000"), "BLT writes live AC3"
call assertEq mem~word(1), octToDec("111111111111"), "hidden core 1 untouched"
call assertEq mem~word(2), octToDec("222222222222"), "hidden core 2 untouched"
call assertEq mem~word(3), octToDec("333333333333"), "hidden core 3 untouched"
call assertEq cpu~accumulator(octToDec("14")), pair(octToDec("000503"), 4), "BLT final pointer with AC destinations"

/* Forward overlapping copies must observe earlier writes, not snapshot source. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("251"), 4, 0, 0, octToDec("001003")))
mem~put(octToDec("001000"), octToDec("010101010101"))
mem~put(octToDec("001001"), octToDec("020202020202"))
mem~put(octToDec("001002"), octToDec("030303030303"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(4, pair(octToDec("001000"), octToDec("001001")))
tr = cpu~step
call assertEq tr["bltTransferCount"], 3, "overlap transfer count"
call assertEq mem~word(octToDec("001001")), octToDec("010101010101"), "overlap destination 101"
call assertEq mem~word(octToDec("001002")), octToDec("010101010101"), "overlap reads live rewritten 101"
call assertEq mem~word(octToDec("001003")), octToDec("010101010101"), "overlap reads live rewritten 102"

/* Cornwell precomputes the final BLT AC before memory cycles.  If the transfer
 * itself targets that AC address, the memory write therefore wins afterward. */
mem = .CountingMemory~new
mem~put(pc, makeInstruction(octToDec("251"), octToDec("14"), 0, 0, octToDec("14")))
mem~put(octToDec("000600"), octToDec("765432123456"))
mem~resetCounts
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(octToDec("14"), pair(octToDec("000600"), octToDec("14")))
tr = cpu~step
call assertEq tr["bltFinalPointer"], pair(octToDec("000601"), octToDec("15")), "precomputed final BLT pointer"
call assertEq cpu~accumulator(octToDec("14")), octToDec("765432123456"), "write to BLT AC occurs after precompute"

say "KL10 BLT acceptance: PASS"
say "  inclusive forward copy updates architectural BLT pointer"
say "  destinations 1..3 write live ACs, not hidden backing core"
say "  overlap observes prior writes through authoritative address space"
say "  transfer targeting its own BLT AC preserves hardware ordering"
exit 0

pair: procedure
  use arg leftHalf, rightHalf
  numeric digits 30
  return (leftHalf // (2 ** 18)) * (2 ** 18) + (rightHalf // (2 ** 18))

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

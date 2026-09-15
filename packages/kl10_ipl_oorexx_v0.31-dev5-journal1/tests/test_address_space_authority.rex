/* Authoritative KL10 address-space acceptance.
 *
 * Proves that:
 *   1. CPU fetch/decode observes live memory, not a cached instruction image.
 *   2. addresses 0..17 octal alias the currently visible AC bank at the
 *      address-space layer, including writes;
 *   3. a partial write spanning two 36-bit words preserves every untouched
 *      bit on both sides of the overlap.
 */
numeric digits 30

mem = .KL10DepositMemory~new
codeAddr = octToDec("004002")
oldInstruction = Oct("630000,,000000")~decimal       /* TDZ 0,0 */
newInstruction = Oct("205740,,123456")~decimal       /* MOVSI 17,123456 */
mem~deposit(codeAddr, oldInstruction)

/* Contradictory backing storage beneath AC17.  The address-space alias must
 * hide this value while AC17 is visible. */
ac17Address = octToDec("17")
backingPoison = Oct("111111,,222222")~decimal
mem~deposit(ac17Address, backingPoison)

/* Two ordinary words for a deliberately cross-word 6-bit write. */
fieldAddr = octToDec("004100")
mem~deposit(fieldAddr,     Oct("777777,,777777")~decimal)
mem~deposit(fieldAddr + 1, Oct("000000,,000000")~decimal)

cpu = .KL10CPU~new~~loadImage(mem, codeAddr)
space = cpu~memory

/* Live instruction overwrite: no decoded-program cache may survive this. */
before = cpu~nextInstruction
call assertEq before["mnemonic"], "TDZ", "initial decode comes from current memory word"
call assertEq cpu~fetch, oldInstruction, "initial fetch word"
space~put(codeAddr, newInstruction)
call assertEq space~word(codeAddr), newInstruction, "address space sees overwrite"
call assertEq mem~word(codeAddr), newInstruction, "official backing memory receives overwrite"
after = cpu~nextInstruction
call assertEq after["mnemonic"], "MOVSI", "next decode observes overwritten instruction"
call assertEq after["ac"], octToDec("17"), "overwritten instruction AC field"
call assertEq after["address"], octToDec("123456"), "overwritten instruction immediate"

/* AC aliases belong to the address space, not to sparse core. */
acValue = Oct("254016,,000000")~decimal
cpu~setAccumulator(octToDec("17"), acValue)
call assertEq space~word(ac17Address), acValue, "address 17 reads AC17"
call assertEq mem~word(ac17Address), backingPoison, "backing core remains distinct beneath AC17 alias"
newAcValue = Oct("000000,,040011")~decimal
space~put(ac17Address, newAcValue)
call assertEq cpu~accumulator(octToDec("17")), newAcValue, "write address 17 updates AC17"
call assertEq mem~word(ac17Address), backingPoison, "AC write does not corrupt hidden backing core"
state = cpu~string
call assertContains state, "PC=004002", "CPU STRING exposes PC in octal"
call assertContains state, "AC17=000000,,040011", "CPU STRING exposes live AC17 state"

/* PDP-10 bit numbering here is left-to-right within each 36-bit word:
 * bitOffset 0 is the most significant bit, bitOffset 35 the least.
 * Writing six bits at offset 33 therefore changes the final octal digit of
 * word N and the first octal digit of word N+1, preserving everything else. */
call assertEq space~readBits(fieldAddr, 33, 6), "111000", "cross-word bits before write"
space~writeBits(fieldAddr, 33, "010101")
call assertEq .LROct~fromDecimal(space~word(fieldAddr))~string, "777777,,777772", "tail bits merged into first word"
call assertEq .LROct~fromDecimal(space~word(fieldAddr + 1))~string, "500000,,000000", "head bits merged into second word"
call assertEq space~readBits(fieldAddr, 33, 6), "010101", "cross-word bits after write"

/* The paged-image memory used by Tops20ExeImage is writable too: writes are
 * authoritative copy-on-write overrides of the tape/zero page source. */
mapped = .KL10Memory~new
mapPage = codeAddr % 512
mapped~mapZeroPage(mapPage, 0)
mapped~put(codeAddr, oldInstruction)
call assertEq mapped~word(codeAddr), oldInstruction, "mapped image memory write persists"
mapped~put(codeAddr, newInstruction)
call assertEq mapped~word(codeAddr), newInstruction, "mapped image memory overwrite persists"

say "KL10 authoritative address-space acceptance: PASS"
say "  live overwrite at 004002 changes the next decoded instruction"
say "  address 000017 reads/writes AC17 while backing core remains distinct"
say "  6-bit write at bit 33 spans two words and preserves untouched bits"
exit 0

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

assertContains: procedure
  use arg actual, expectedPart, label
  if pos(expectedPart, actual) = 0 then do
    say "FAIL:" label
    say "  expected part:" expectedPart
    say "  actual:       " actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
::requires "../KL10TapeRaw.cls"
::requires "../lib/OctalBits.cls"

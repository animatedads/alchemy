/* KL10 PAG DATAO AC-block field acceptance from the real MTBOOT handoff. */
numeric digits 30
pc = octToDec("000100")
mem = .TestMemory~new
mem~deposit(pc + 0, octToDec("700200200000"))  /* CONO APR,200000 reset */
mem~deposit(pc + 1, octToDec("701140000001"))  /* DATAO PAG,1 */

cpu = .KL10CPU~new~~loadImage(mem, pc)
sourceWord = octToDec("500600000765")
cpu~setAccumulator(1, sourceWord)
ignored = cpu~step
tr = cpu~step
call assertEq tr["ioData"], sourceWord, "real MTBOOT PAG DATAO word"
call assertEq cpu~pag~currentAcBlock, 0, "current AC block"
call assertEq cpu~pag~previousAcBlock, 6, "previous AC block"
call assertEq cpu~pag~previousContextSection, 0, "previous context section unchanged"
call assertEq cpu~pag~ubPtr, octToDec("765000"), "UBR loaded from RH"
call assertEq cpu~pag~dataoCount, 1, "DATAO count"

/* The bounded CPU has only one live AC block.  Loading a nonzero current
 * block must remain an explicit boundary rather than silently aliasing it. */
badMem = .TestMemory~new
badMem~deposit(pc + 0, octToDec("700200200000"))
badMem~deposit(pc + 1, octToDec("701140000001"))
bad = .KL10CPU~new~~loadImage(badMem, pc)
bad~setAccumulator(1, octToDec("401000000000"))
ignored = bad~step
signal on syntax name expectedReject
ignored = bad~step
signal off syntax
say "FAIL: PAG DATAO selecting current AC block 1 should reject"
exit 1
expectedReject:
signal off syntax
call assertEq bad~pc, pc + 1, "rejected DATAO leaves PC"
call assertEq bad~pag~dataoCount, 0, "rejected DATAO leaves count"

say "KL10 PAG AC-block DATAO acceptance: PASS"
say "  500600,,000765 -> current block 0, previous block 6, UBR 765000"
say "  nonzero current block remains outside the bounded AC model"
exit 0

octToDec: procedure
  use arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
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

::class TestMemory public
::method init
  expose words
  words=.directory~new
::method deposit
  expose words
  use strict arg address, value
  numeric digits 30
  words[address]=value // (2 ** 36)
  return self
::method word
  expose words
  use strict arg address
  if words~hasIndex(address) then return words[address]
  return 0
::method put
  expose words
  use strict arg address, value
  numeric digits 30
  words[address]=value // (2 ** 36)
  return self

::requires "../KL10IPL.cls"

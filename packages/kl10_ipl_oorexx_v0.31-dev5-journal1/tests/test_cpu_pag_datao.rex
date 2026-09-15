/* KL10 PAG device-state acceptance: EBR/UBR transitions are real device state
 * while the bounded address space still refuses actual paging enablement. */
numeric digits 30
pc = octToDec("000100")

/* Real-form instructions:
 *   CONO APR,200000      establish modeled machine reset
 *   CONO PAG,47          EBR <- 047000, pager remains disabled
 *   DATAO PAG,1          source comes from live AC1; BIT2 loads UBR
 */
mem = .TestMemory~new
mem~deposit(pc + 0, octToDec("700200200000"))
mem~deposit(pc + 1, octToDec("701200000047"))
mem~deposit(pc + 2, octToDec("701140000001"))

cpu = .KL10CPU~new~~loadImage(mem, pc)
sourceWord = octToDec("100000400047")
cpu~setAccumulator(1, sourceWord)

resetTrace = cpu~step
call assertEq resetTrace["ioAction"], "APR_IO_RESET", "reset action"
call assertEq cpu~pag~ebPtr, 0, "reset EBR"
call assertEq cpu~pag~ubPtr, 0, "reset UBR"
call assertEq cpu~pag~tlbFlushCount, 1, "reset invalidates translations"

conoTrace = cpu~step
call assertEq conoTrace["mnemonic"], "CONO", "PAG CONO mnemonic"
call assertEq conoTrace["deviceName"], "PAG", "PAG CONO device"
call assertEq conoTrace["ioCondition"], octToDec("000047"), "PAG CONO condition"
call assertEq cpu~pag~status, octToDec("000047"), "PAG status exposes EBR base"
call assertEq cpu~pag~ebPtr, octToDec("047000"), "PAG EBR"
call assertEq cpu~pag~ubPtr, 0, "PAG UBR unchanged by CONO"
call assertEq cpu~pag~pageEnabled, 0, "pager remains disabled"
call assertEq cpu~pag~tops20Page, 0, "TOPS-20 pager remains disabled"
call assertEq cpu~pag~tlbFlushCount, 2, "CONO invalidates translations"

dataoTrace = cpu~step
call assertEq dataoTrace["mnemonic"], "DATAO", "PAG DATAO mnemonic"
call assertEq dataoTrace["deviceName"], "PAG", "PAG DATAO device"
call assertEq dataoTrace["ioSource"], 1, "DATAO source address is AC1"
call assertEq dataoTrace["ioData"], sourceWord, "DATAO reads live AC1"
call assertEq cpu~pag~ubPtr, octToDec("047000"), "PAG DATAO loads UBR"
call assertEq cpu~pag~ebPtr, octToDec("047000"), "PAG DATAO preserves EBR"
call assertEq cpu~pag~dataoCount, 1, "PAG DATAO count"
call assertEq cpu~pag~lastDatao, sourceWord, "PAG last DATAO word"
call assertEq cpu~pag~tlbFlushCount, 3, "DATAO UBR load invalidates translations"
call assertEq cpu~pag~pageEnabled, 0, "DATAO does not invent paging"
call assertEq cpu~pag~tops20Page, 0, "DATAO does not invent TOPS-20 paging"

/* A DATAO requesting the unmodeled KL10B fast-memory/previous-context path
 * must be refused rather than silently dropping those state bits. */
badMem = .TestMemory~new
badMem~deposit(pc + 0, octToDec("700200200000"))
badMem~deposit(pc + 1, octToDec("701140000001"))
bad = .KL10CPU~new~~loadImage(badMem, pc)
bad~setAccumulator(1, octToDec("401000000001"))  /* LLACBL, current block 1 */
ignored = bad~step
signal on syntax name expectedContextReject
ignored = bad~step
signal off syntax
say "FAIL: PAG DATAO with unmodeled context bit should be rejected"
exit 1

expectedContextReject:
signal off syntax
call assertEq bad~pc, pc + 1, "rejected DATAO leaves PC"
call assertEq bad~pag~dataoCount, 0, "rejected DATAO leaves device state"

say "KL10 PAG DATAO/state acceptance: PASS"
say "  CONO PAG,47 -> EBR=047000, pager remains off"
say "  DATAO PAG from live AC1 -> UBR=047000 through the I/O bus"
say "  translation invalidation is observable; unmodeled current-AC switch rejects"
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

::class TestMemory public
::method init
  expose words
  words = .directory~new
::method deposit
  expose words
  use strict arg address, value
  numeric digits 30
  words[address] = value // (2 ** 36)
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
  words[address] = value // (2 ** 36)
  return self

::requires "../KL10IPL.cls"

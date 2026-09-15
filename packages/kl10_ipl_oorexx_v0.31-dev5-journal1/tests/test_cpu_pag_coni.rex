/* Bounded PAG observation: after modeled APR I/O reset, CONI PAG,15 octal
 * returns exactly zero into the accumulator-window destination AC15 octal.
 * No page-table or pager machinery is invented. */
numeric digits 30
pc = octToDec("000100")
resetWord = octToDec("700200200000")
coniWord = octToDec("701240000015")
canary = octToDec("765432123456")

mem = .SequenceGuardMemory~new(pc, resetWord, coniWord)
cpu = .KL10CPU~new~~loadImage(mem, pc)

/* AC number 15 octal is numeric 13.  Plant a canary so the CONI must visibly
 * write the fast-memory/AC window rather than an unrelated sparse M[15]. */
ac15 = octToDec("15")
cpu~setAccumulator(ac15, canary)
call assertEq cpu~pag~status, .nil, "PAG status unknown before reset"
call assertEq cpu~pag~hasMethod("base"), 0, "no invented PAG base"
call assertEq cpu~pag~hasMethod("process"), 0, "no invented PAG process"
call assertEq cpu~pag~hasMethod("trap"), 0, "no invented PAG trap"
call assertEq cpu~pag~hasMethod("cache"), 0, "no invented PAG cache"

resetTrace = cpu~step
call assertEq resetTrace["ioAction"], "APR_IO_RESET", "first action reset"
call assertEq cpu~pag~status, 0, "PAG status established as zero by reset"
call assertEq cpu~pc, pc + 1, "PC after reset"
call assertEq cpu~accumulator(ac15), canary, "reset does not invent AC15 change"

coniTrace = cpu~step
call assertEq coniTrace["mnemonic"], "CONI", "CONI mnemonic"
call assertEq coniTrace["deviceName"], "PAG", "PAG device"
call assertEq coniTrace["ioAction"], "PAG_CONI_STATUS", "bounded PAG action"
call assertEq coniTrace["ioDestination"], ac15, "destination is AC15 octal"
call assertEq coniTrace["ioStatus"], 0, "returned status zero"
call assertEq coniTrace["destinationBefore"], canary, "destination canary observed"
call assertEq coniTrace["destinationAfter"], 0, "destination cleared to zero"
call assertEq cpu~accumulator(ac15), 0, "AC15 octal receives status"
call assertEq cpu~pc, pc + 2, "CONI advances PC"
call assertEq cpu~halted, 1, "CONI halts after bounded step"
call assertEq mem~reads, 2, "only instruction fetches touched memory"

/* CONI PAG before reset must remain unsupported: status is unknown, not
 * guessed zero merely because a fresh object was allocated. */
preMem = .SingleGuardMemory~new(pc, coniWord)
pre = .KL10CPU~new~~loadImage(preMem, pc)
pre~setAccumulator(ac15, canary)
signal on syntax name expectedBeforeReset
ignored = pre~step
signal off syntax
say "FAIL: CONI PAG before reset should be unsupported"
exit 1

expectedBeforeReset:
signal off syntax
call assertEq pre~pc, pc, "pre-reset rejection leaves PC"
call assertEq pre~accumulator(ac15), canary, "pre-reset rejection leaves AC15"

/* EBR-only PAG controls are now modeled exactly while translation remains off. */
conoPagOne = octToDec("701200000001")
postMem = .SequenceGuardMemory~new(pc, resetWord, conoPagOne)
post = .KL10CPU~new~~loadImage(postMem, pc)
ignoredReset = post~step
trOne = post~step
call assertEq trOne["ioAction"], "PAG_CONO", "CONO PAG,1 action"
call assertEq post~pc, pc + 2, "CONO PAG,1 advances PC"
call assertEq post~pag~status, 1, "CONO PAG,1 status"
call assertEq post~pag~ebPtr, octToDec("001000"), "CONO PAG,1 EBR"
call assertEq post~pag~pageEnabled, 0, "CONO PAG,1 leaves pager off"
call assertEq post~pag~tops20Page, 0, "CONO PAG,1 leaves TOPS-20 pager off"
call assertEq post~pag~conoZeroCount, 0, "nonzero control not counted as zero"

/* Actually enabling translation remains outside the memory model. */
conoEnable = octToDec("701200020000")
blockedMem = .SequenceGuardMemory~new(pc, resetWord, conoEnable)
blocked = .KL10CPU~new~~loadImage(blockedMem, pc)
ignoredReset = blocked~step
signal on syntax name expectedPagingEnable
ignored = blocked~step
signal off syntax
say "FAIL: CONO PAG,020000 should remain unsupported until translation exists"
exit 1

expectedPagingEnable:
signal off syntax
call assertEq blocked~pc, pc + 1, "paging-enable rejection leaves PC"
call assertEq blocked~pag~status, 0, "paging-enable rejection leaves PAG state"

say "KL10 PAG CONI acceptance: PASS"
say "  APR I/O reset establishes bounded PAG status = 0"
say "  CONI PAG,15 octal writes AC15 octal, not sparse memory"
say "  EBR-only CONO controls are modeled; pager-enable controls remain bounded out"
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

::class SequenceGuardMemory public
::method init
  expose base first second readCount
  use arg at, word1, word2
  base = at
  first = word1
  second = word2
  readCount = 0
::method word
  expose base first second readCount
  use arg at
  readCount = readCount + 1
  if at = base then return first
  if at = base + 1 then return second
  raise syntax 40.900 array("unexpected memory fetch at" at)
::method reads
  expose readCount
  return readCount

::class SingleGuardMemory public
::method init
  expose base instruction
  use arg at, word
  base = at
  instruction = word
::method word
  expose base instruction
  use arg at
  if at = base then return instruction
  raise syntax 40.900 array("unexpected memory fetch at" at)

::requires "../KL10IPL.cls"

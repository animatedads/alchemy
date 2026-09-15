/* v0.17 I/O bus acceptance: decoded PDP-10 I/O operations route through an
 * attachable device object and use the same live KL10AddressSpace as CPU
 * fetch/operands.  BLKI/BLKO remain deliberately outside the channel model. */
numeric digits 30

pc = octToDec("000100")
probeCode = octToDec("020")
normalSource = octToDec("004000")
normalDest = octToDec("004001")
sourceWord = octToDec("123456765432")
dataInWord = octToDec("654321012345")
statusWord = octToDec("000000000003")

mem = .KL10DepositMemory~new
mem~deposit(normalSource, sourceWord)

/* DATAO DEV,004000 ; DATAI DEV,17 ; CONI DEV,004001 ;
 * CONSO DEV,3 ; skipped word ; SETZ 0,0 (merely a landing word). */
mem~deposit(pc + 0, makeIO(probeCode, 3, normalSource, 0))
mem~deposit(pc + 1, makeIO(probeCode, 1, octToDec("000017"), 0))
mem~deposit(pc + 2, makeIO(probeCode, 5, normalDest, 0))
mem~deposit(pc + 3, makeIO(probeCode, 7, 3, 0))
mem~deposit(pc + 4, octToDec("777777777777"))
mem~deposit(pc + 5, makeIO(probeCode, 6, 4, 0))
mem~deposit(pc + 6, octToDec("777777777777"))
mem~deposit(pc + 7, octToDec("400000000000"))

cpu = .KL10CPU~new~~loadImage(mem, pc)
probe = .ProbeIODevice~new(probeCode, dataInWord, statusWord)
cpu~ioBus~attach(probe)

call assertEq cpu~ioBus~attached, 4, "APR+PI+PAG+probe attached"
call assertEq cpu~ioBus~deviceName(0), "APR", "APR name from bus"
call assertEq cpu~ioBus~deviceName(octToDec("010")), "PAG", "PAG name from bus"
call assertEq cpu~ioBus~deviceName(probeCode), "PROBE", "probe name from bus"
call assertEq cpu~apr, cpu~ioBus~device(0), "cpu APR is bus APR object"
call assertEq cpu~pag, cpu~ioBus~device(octToDec("010")), "cpu PAG is bus PAG object"

/* DATAO reads the live memory word and delivers that exact 36-bit word. */
t = cpu~step
call assertEq t["mnemonic"], "DATAO", "DATAO decode"
call assertEq t["deviceName"], "PROBE", "DATAO routed device"
call assertEq t["ioSource"], normalSource, "DATAO source address"
call assertEq t["ioData"], sourceWord, "DATAO bus data"
call assertEq probe~lastDataOut, sourceWord, "device received memory word"
call assertEq cpu~pc, pc + 1, "PC after DATAO"

/* DATAI writes through the live address space.  E=17 octal aliases AC17. */
canary = octToDec("111111222222")
cpu~setAccumulator(octToDec("17"), canary)
t = cpu~step
call assertEq t["mnemonic"], "DATAI", "DATAI decode"
call assertEq t["ioDestination"], octToDec("17"), "DATAI destination"
call assertEq t["destinationBefore"], canary, "DATAI observes AC-window canary"
call assertEq t["destinationAfter"], dataInWord, "DATAI written value"
call assertEq cpu~accumulator(octToDec("17")), dataInWord, "DATAI writes AC17 via memory"
call assertEq cpu~pc, pc + 2, "PC after DATAI"

/* CONI deposits status into ordinary live memory, not a CPU-local pseudo slot. */
t = cpu~step
call assertEq t["mnemonic"], "CONI", "CONI decode"
call assertEq t["ioStatus"], statusWord, "CONI status"
call assertEq t["ioDestination"], normalDest, "CONI destination"
call assertEq mem~word(normalDest), statusWord, "CONI writes backing memory"
call assertEq cpu~pc, pc + 3, "PC after CONI"

/* CONSO tests status & E and skips when nonzero. */
t = cpu~step
call assertEq t["mnemonic"], "CONSO", "CONSO decode"
call assertEq t["ioCondition"], 3, "CONSO condition"
call assertEq t["ioTested"], 3, "CONSO tested bits"
call assertEq t["ioSkip"], 1, "CONSO skip"
call assertEq cpu~pc, pc + 5, "CONSO skips one word"

/* CONSZ skips when the tested bits are zero.  status=3, mask=4 -> zero. */
t = cpu~step
call assertEq t["mnemonic"], "CONSZ", "CONSZ decode"
call assertEq t["ioCondition"], 4, "CONSZ condition"
call assertEq t["ioTested"], 0, "CONSZ tested bits"
call assertEq t["ioSkip"], 1, "CONSZ skip"
call assertEq cpu~pc, pc + 7, "CONSZ skips one word"

/* BLKI/BLKO are decoded but refused rather than faked. */
blockMem = .KL10DepositMemory~new
blockMem~deposit(pc, makeIO(probeCode, 0, normalSource, 0))
blockCpu = .KL10CPU~new~~loadImage(blockMem, pc)
blockCpu~ioBus~attach(.ProbeIODevice~new(probeCode, dataInWord, statusWord))
signal on syntax name expectedBlockReject
ignoredBlock = blockCpu~step
signal off syntax
say "FAIL: BLKI should remain outside bounded channel model"
exit 1

expectedBlockReject:
signal off syntax
call assertEq blockCpu~pc, pc, "BLKI rejection leaves PC"

say "KL10 I/O bus routing acceptance: PASS"
say "  decoded DATAO reads live memory and reaches attached device"
say "  DATAI to 000017 writes AC17 through authoritative address space"
say "  CONI writes ordinary live memory; CONSO/CONSZ perform status-mask skips"
say "  BLKI/BLKO remain explicit channel boundary"
say "  " cpu~ioBus
exit 0

makeIO: procedure
  use arg devCode, functionCode, e, index
  numeric digits 30
  deviceField = devCode % 4
  return 7 * (2 ** 33) + deviceField * (2 ** 26) + functionCode * (2 ** 23) + index * (2 ** 18) + e

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

::class ProbeIODevice public
::method init
  expose code inputWord statusWord outWord
  use strict arg deviceCode, dataInput, statusInput
  code = deviceCode
  inputWord = dataInput
  statusWord = statusInput
  outWord = .nil
::method deviceCode
  expose code
  return code
::method deviceName
  return "PROBE"
::method ioAction
  use strict arg fn
  return "PROBE_IO_" || fn
::method datao
  expose outWord
  use strict arg value, bus
  outWord = value
  return self
::method datai
  expose inputWord
  use strict arg bus
  return inputWord
::method coni
  expose statusWord
  use strict arg bus
  return statusWord
::method lastDataOut
  expose outWord
  return outWord

::requires "../KL10IPL.cls"
::requires "../KL10TapeRaw.cls"

/* Real MTBOOT.EXB: execute through the shift/PAG/APR path and the first two
 * halfword instructions, then stop on untouched BLT at 040036. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_twentyfour_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

names = .array~of(-
  "TDZ", "SKIPA", "CONO", "CONI", "ANDI", "CONO", "MOVSI", "JSP", -
  "JRST", "SUBI", "AND", "MOVEI", "MOVEM", "MOVEI", "LSH", "IOR", -
  "CONO", "TDO", "DATAO", "CONO", "MOVEI", "SKIP", "CONSO", "JRST", -
  "HRRI", "HRLI")

do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
end

call assertEq cpu~pc, octToDec("040036"), "PC after twenty-six instructions"
call assertEq cpu~flags, octToDec("006000"), "FLAGS after path"
call assertEq cpu~accumulator(1), octToDec("100000400047"), "AC1 carries PAG DATAO word"
call assertEq cpu~accumulator(octToDec("10")), octToDec("000000777000"), "AC10 base"
call assertEq cpu~accumulator(octToDec("15")), octToDec("000000000047"), "AC15 PAG base"
call assertEq cpu~accumulator(octToDec("16")), octToDec("000000040000"), "AC16 trampoline base"
call assertEq cpu~accumulator(octToDec("14")), octToDec("047000000001"), "AC14 BLT source/destination pair"
call assertEq cpu~accumulator(octToDec("17")), octToDec("254016000000"), "AC17 trampoline instruction"

call assertEq cpu~memory~word(octToDec("047503")), octToDec("000000047007"), "MOVEM state retained"
call assertEq cpu~memory~word(octToDec("777020")), 0, "SKIP examined zero word"

call assertEq cpu~pag~status, octToDec("000047"), "PAG status"
call assertEq cpu~pag~ebPtr, octToDec("047000"), "PAG EBR"
call assertEq cpu~pag~ubPtr, octToDec("047000"), "PAG UBR"
call assertEq cpu~pag~pageEnabled, 0, "pager remains disabled"
call assertEq cpu~pag~tops20Page, 0, "TOPS-20 pager remains disabled"
call assertEq cpu~pag~conoCount, 2, "PAG CONO count"
call assertEq cpu~pag~conoZeroCount, 1, "PAG zero CONO count"
call assertEq cpu~pag~dataoCount, 1, "PAG DATAO count"
call assertEq cpu~pag~tlbFlushCount, 4, "PAG translation invalidation generation"

call assertEq cpu~apr~ioResetCount, 1, "APR reset count"
call assertEq cpu~apr~aprIrq, 0, "APR PIA"
call assertEq cpu~apr~irqEnable, 0, "APR interrupt enable"
call assertEq cpu~apr~irqFlags, 0, "APR interrupt flags"

nextWord = cpu~fetch
next = cpu~decode(nextWord)
call assertEq nextWord, octToDec("251600000007"), "word at 040036"
call assertEq next["opcode"], octToDec("251"), "next opcode 251"
call assertEq next["mnemonic"], "BLT", "next mnemonic"
call assertEq next["ac"], octToDec("14"), "next AC14"
call assertEq next["index"], 0, "next X0"
call assertEq next["address"], octToDec("7"), "next Y7"

tape~close
say "KL10 MTBOOT twenty-six-step acceptance: PASS"
say "  LSH -> IOR -> CONO PAG,47 -> TDO -> DATAO PAG"
say "  PAG live state: EBR=047000 UBR=047000, pager still disabled"
say "  APR control, MOVEI, SKIP, CONSO and JRST execute from live state"
say "  HRRI/HRLI build AC14=047000,,000001 from live indexed state"
say "  next, not executed: 040036 251600,,000007 BLT 14,7"
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

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"

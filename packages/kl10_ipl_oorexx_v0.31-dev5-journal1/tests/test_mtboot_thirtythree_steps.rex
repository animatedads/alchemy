/* Real MTBOOT.EXB: execute through BLT's live AC-window load, then follow the
 * newly installed fast-memory instructions until untouched EXCH in AC2. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_thirtythree_steps.rex /path/to/bb-h137f-bm.tap"
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
  "HRRI", "HRLI", "BLT", "HRRZI", "MOVEM", "HRRZI", "HRRZI", "JRST", "MOVE")

do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
  if i = 27 then bltTrace = tr
  if i = 33 then moveTrace = tr
end

call assertEq bltTrace["bltSourceStart"], octToDec("047000"), "BLT source start"
call assertEq bltTrace["bltDestinationStart"], 1, "BLT destination start"
call assertEq bltTrace["bltEndDestination"], 7, "BLT inclusive destination end"
call assertEq bltTrace["bltTransferCount"], 7, "BLT transfer count"
call assertEq bltTrace["bltFinalPointer"], octToDec("047007000010"), "BLT final pointer"
call assertEq bltTrace["bltFirstWord"], octToDec("200612000000"), "BLT first source word"
call assertEq bltTrace["bltLastWord"], octToDec("254010772044"), "BLT last source word"

/* BLT loads the seven source words directly into the live AC window. */
call assertEq cpu~accumulator(1), octToDec("200612000000"), "AC1 loaded by BLT"
call assertEq cpu~accumulator(2), octToDec("250611000000"), "AC2 loaded by BLT"
call assertEq cpu~accumulator(3), octToDec("202612000000"), "AC3 loaded by BLT"
call assertEq cpu~accumulator(4), octToDec("350000000011"), "AC4 loaded by BLT"
call assertEq cpu~accumulator(5), octToDec("350000000012"), "AC5 loaded by BLT"
call assertEq cpu~accumulator(6), octToDec("367540000001"), "AC6 loaded by BLT"
call assertEq cpu~accumulator(7), octToDec("254010772044"), "AC7 loaded by BLT"

/* Subsequent core code changes more live AC state, jumps to AC1, and executes
 * the MOVE now physically resident there. */
call assertEq moveTrace["pcBefore"], 1, "step 33 fetch address is AC1"
call assertEq moveTrace["fetchSource"], "AC", "step 33 instruction fetched from AC window"
call assertEq cpu~pc, 2, "PC stops at AC2"
call assertEq cpu~memory~sourceKind(cpu~pc), "AC", "next instruction source is AC2"
call assertEq cpu~accumulator(octToDec("11")), octToDec("000000011000"), "AC11 setup retained"
call assertEq cpu~accumulator(octToDec("12")), octToDec("000000742000"), "AC12 setup retained"
call assertEq cpu~accumulator(octToDec("13")), octToDec("000000036000"), "AC13 setup retained"
call assertEq cpu~accumulator(octToDec("14")), 0, "MOVE from AC1 updates AC14"
call assertEq cpu~accumulator(octToDec("17")), octToDec("000000011000"), "MOVEM updates live AC17"
call assertEq cpu~flags, octToDec("006000"), "FLAGS after thirty-three instructions"

call assertEq cpu~memory~word(octToDec("047000")), octToDec("200612000000"), "BLT source remains intact"
call assertEq cpu~memory~word(octToDec("047006")), octToDec("254010772044"), "BLT final source remains intact"
call assertEq cpu~memory~word(octToDec("047503")), octToDec("000000047007"), "earlier MOVEM state retained"

nextWord = cpu~fetch
next = cpu~decode(nextWord)
call assertEq nextWord, octToDec("250611000000"), "word in AC2"
call assertEq next["opcode"], octToDec("250"), "next opcode 250"
call assertEq next["mnemonic"], "EXCH", "next mnemonic"
call assertEq next["ac"], octToDec("14"), "EXCH AC14"
call assertEq next["index"], octToDec("11"), "EXCH index AC11"
call assertEq next["address"], 0, "EXCH Y0"

tape~close
say "KL10 MTBOOT thirty-three-step acceptance: PASS"
say "  BLT 14,7 copies 047000..047006 into the live AC1..AC7 window"
say "  later JRST 1 fetches and executes MOVE directly from AC1"
say "  next, not executed: 000002 [AC2] 250611,,000000 EXCH 14,0(11)"
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

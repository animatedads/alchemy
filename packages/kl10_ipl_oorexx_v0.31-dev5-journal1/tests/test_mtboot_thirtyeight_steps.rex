/* Real MTBOOT.EXB: execute through first EXCH/MOVEM/AOS/AOS/SOJG loop turn. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_thirtyeight_steps.rex /path/to/bb-h137f-bm.tap"
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
  "HRRI", "HRLI", "BLT", "HRRZI", "MOVEM", "HRRZI", "HRRZI", "JRST", -
  "MOVE", "EXCH", "MOVEM", "AOS", "AOS", "SOJG")

do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
  if i = 34 then exchTrace = tr
  if i = 36 then aos11Trace = tr
  if i = 37 then aos12Trace = tr
  if i = 38 then sojgTrace = tr
end

call assertEq exchTrace["pcBefore"], 2, "EXCH fetched from AC2"
call assertEq exchTrace["fetchSource"], "AC", "EXCH fetch source"
call assertEq exchTrace["effectiveAddress"], octToDec("011000"), "EXCH E"
call assertEq exchTrace["operand"], 0, "EXCH source word at 011000"

call assertEq aos11Trace["effectiveAddress"], octToDec("11"), "AOS 0,11 E"
call assertEq aos11Trace["result"], octToDec("011001"), "AOS AC11 result"
call assertEq aos12Trace["effectiveAddress"], octToDec("12"), "AOS 0,12 E"
call assertEq aos12Trace["result"], octToDec("742001"), "AOS AC12 result"

call assertEq sojgTrace["effectiveAddress"], 1, "SOJG branch target"
call assertEq sojgTrace["branchTaken"], 1, "SOJG first loop branch"
call assertEq sojgTrace["result"], octToDec("035777"), "SOJG decremented AC13"
call assertEq cpu~pc, 1, "loop returns to AC1"
call assertEq cpu~accumulator(octToDec("11")), octToDec("000000011001"), "AC11 after first loop turn"
call assertEq cpu~accumulator(octToDec("12")), octToDec("000000742001"), "AC12 after first loop turn"
call assertEq cpu~accumulator(octToDec("13")), octToDec("000000035777"), "AC13 after first loop turn"
call assertEq cpu~flags, octToDec("006000"), "FLAGS after first loop turn"

nextWord = cpu~fetch
call assertEq nextWord, octToDec("200612000000"), "loop next word is AC1 MOVE"

tape~close
say "KL10 MTBOOT thirty-eight-step acceptance: PASS"
say "  real tape executes EXCH/MOVEM/AOS/AOS/SOJG in live fast memory"
say "  first loop turn: AC11=011001 AC12=742001 AC13=035777, PC=000001"
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

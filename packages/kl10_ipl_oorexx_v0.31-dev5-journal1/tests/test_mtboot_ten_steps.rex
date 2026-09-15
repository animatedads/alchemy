/* Real MTBOOT.EXB: execute through SUBI 16,11 at 040011. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_ten_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

names = .array~of("TDZ", "SKIPA", "CONO", "CONI", "ANDI", "CONO", "MOVSI", "JSP", "JRST", "SUBI")
do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
end

call assertEq cpu~pc, octToDec("040012"), "PC after SUBI"
call assertEq cpu~accumulator(octToDec("16")), octToDec("000000040000"), "AC16 after SUBI"
call assertEq cpu~flags, octToDec("006000"), "FLAGS after SUBI"
call assertEq tr["carry1"], 1, "SUBI carry1"
call assertEq tr["carry0"], 1, "SUBI carry0"
call assertEq tr["overflow"], 0, "SUBI overflow"

nextWord = cpu~fetch
next = cpu~decode(nextWord)
call assertEq nextWord, octToDec("404016000124"), "word at 040012"
call assertEq next["opcode"], octToDec("404"), "next opcode 404"
call assertEq next["ac"], 0, "next AC0"
call assertEq next["index"], octToDec("16"), "next X=16"
call assertEq next["address"], octToDec("124"), "next Y=124"

tape~close
say "KL10 MTBOOT ten-step acceptance: PASS"
say "  040011  SUBI 16,11        -> 040012  AC16=000000,,040000 FLAGS=006000"
say "  next, not executed: 040012 404016,,000124 opcode 404 (AND family)"
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

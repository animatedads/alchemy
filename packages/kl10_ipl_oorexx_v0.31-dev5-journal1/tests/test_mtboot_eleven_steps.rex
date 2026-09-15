/* Real MTBOOT.EXB: execute SUBI and the following indexed AND family member. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_eleven_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

names = .array~of("TDZ", "SKIPA", "CONO", "CONI", "ANDI", "CONO", "MOVSI", "JSP", "JRST", "SUBI", "AND")
do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
end

call assertEq cpu~pc, octToDec("040013"), "PC after AND"
call assertEq cpu~accumulator(octToDec("16")), octToDec("000000040000"), "AC16 retained"
call assertEq cpu~accumulator(0), 0, "AC0 after AND"
call assertEq cpu~flags, octToDec("006000"), "Boolean AND preserves SUBI flags"
call assertEq tr["effectiveAddress"], octToDec("040124"), "AND indexed E"
call assertEq tr["operand"], octToDec("600000000000"), "AND memory operand"
call assertEq tr["result"], 0, "AND result"

nextWord = cpu~fetch
next = cpu~decode(nextWord)
call assertEq nextWord, octToDec("201056007007"), "word at 040013"
call assertEq next["opcode"], octToDec("201"), "next opcode 201"
call assertEq next["ac"], 1, "next AC1"
call assertEq next["index"], octToDec("16"), "next X16"
call assertEq next["address"], octToDec("7007"), "next Y7007"

tape~close
say "KL10 MTBOOT eleven-step acceptance: PASS"
say "  040012  AND 0,124(16)     -> 040013  E=040124 M=600000,,000000 AC0=0"
say "  FLAGS remains 006000 from SUBI"
say "  next, not executed: 040013 201056,,007007 opcode 201 (MOVEI family)"
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

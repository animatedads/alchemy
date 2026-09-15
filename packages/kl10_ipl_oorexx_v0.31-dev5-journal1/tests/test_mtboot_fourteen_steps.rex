/* Real MTBOOT.EXB: execute through the recovered MOVE-family sequence. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_fourteen_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

names = .array~of("TDZ", "SKIPA", "CONO", "CONI", "ANDI", "CONO", "MOVSI", "JSP", "JRST", "SUBI", "AND", "MOVEI", "MOVEM", "MOVEI")
do i = 1 to names~items
  tr = cpu~step
  call assertEq tr["mnemonic"], names[i], "step" i "mnemonic"
end

call assertEq cpu~pc, octToDec("040016"), "PC after second MOVEI"
call assertEq cpu~accumulator(1), octToDec("000000047000"), "AC1 after MOVEI 1,7000(16)"
call assertEq cpu~accumulator(octToDec("16")), octToDec("000000040000"), "AC16 retained"
call assertEq cpu~flags, octToDec("006000"), "MOVE family preserves SUBI flags"
call assertEq cpu~memory~word(octToDec("047503")), octToDec("000000047007"), "MOVEM deposited first MOVEI result"

nextWord = cpu~fetch
next = cpu~decode(nextWord)
call assertEq nextWord, octToDec("242040777767"), "word at 040016"
call assertEq next["opcode"], octToDec("242"), "next opcode 242"
call assertEq next["mnemonic"], "LSH", "next mnemonic"
call assertEq next["ac"], 1, "next AC1"
call assertEq next["index"], 0, "next X0"
call assertEq next["address"], octToDec("777767"), "next Y777767"

tape~close
say "KL10 MTBOOT fourteen-step acceptance: PASS"
say "  040013  MOVEI 1,7007(16)  -> AC1=000000,,047007"
say "  040014  MOVEM 1,7503(16)  -> M[047503]=000000,,047007"
say "  040015  MOVEI 1,7000(16)  -> AC1=000000,,047000"
say "  FLAGS remains 006000"
say "  next, not executed: 040016 242040,,777767 opcode 242 (LSH)"
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

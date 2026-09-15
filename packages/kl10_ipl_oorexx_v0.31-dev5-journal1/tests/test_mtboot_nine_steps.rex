/* Real MTBOOT.EXB: execute exactly nine admitted instructions.  The eighth
 * is JSP 16,17 at 040010.  The ninth is the JRST 0(16) trampoline fetched
 * from AC17; it uses RH(AC16)=040011 as its indexed effective address and
 * returns execution to core at 040011.  Fetch/decode the resulting SUBI but
 * do not execute it.
 * Usage: rexx test_mtboot_nine_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_nine_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

first = cpu~step
call assertEq first["mnemonic"], "TDZ", "first mnemonic"
call assertEq first["pcAfter"], octToDec("040001"), "TDZ next PC"

second = cpu~step
call assertEq second["mnemonic"], "SKIPA", "second mnemonic"
call assertEq second["pcAfter"], octToDec("040003"), "SKIPA next PC"

third = cpu~step
call assertEq third["ioAction"], "APR_IO_RESET", "third action"
call assertEq third["pcAfter"], octToDec("040004"), "APR reset next PC"

fourth = cpu~step
call assertEq fourth["ioAction"], "PAG_CONI_STATUS", "fourth action"
call assertEq fourth["pcAfter"], octToDec("040005"), "CONI next PC"
ac15 = octToDec("15")
call assertEq cpu~accumulator(ac15), 0, "AC15 after CONI"

fifth = cpu~step
call assertEq fifth["mnemonic"], "ANDI", "fifth mnemonic"
call assertEq fifth["operand"], octToDec("600000"), "ANDI mask"
call assertEq fifth["pcAfter"], octToDec("040006"), "ANDI next PC"
call assertEq cpu~accumulator(ac15), 0, "AC15 after real ANDI"

sixth = cpu~step
call assertEq sixth["ioAction"], "PAG_CONO_ZERO", "sixth action"
call assertEq sixth["effectiveAddress"], 0, "real indexed E"
call assertEq sixth["pcAfter"], octToDec("040007"), "indexed PAG CONO next PC"

seventhIns = cpu~nextInstruction
call assertEq seventhIns["mnemonic"], "MOVSI", "seventh mnemonic"
call assertEq seventhIns["ac"], octToDec("17"), "seventh AC17"
call assertEq seventhIns["address"], octToDec("254016"), "seventh immediate E"

seventh = cpu~step
call assertEq seventh["mnemonic"], "MOVSI", "executed seventh mnemonic"
call assertEq seventh["effectiveAddress"], octToDec("254016"), "MOVSI E"
call assertEq seventh["operand"], octToDec("254016000000"), "MOVSI E,,0"
call assertEq cpu~accumulator(octToDec("17")), octToDec("254016000000"), "AC17 after MOVSI"
call assertEq seventh["pcAfter"], octToDec("040010"), "MOVSI next PC"
call assertEq cpu~halted, 1, "halt after seventh step"

/* Execute JSP from core. */
ac16 = octToDec("16")
ac17 = octToDec("17")
call assertEq cpu~flags, 0, "bounded flags before JSP"
call assertEq cpu~accumulator(ac17), octToDec("254016000000"), "AC17 trampoline word"

eighth = cpu~step
call assertEq eighth["mnemonic"], "JSP", "eighth mnemonic"
call assertEq eighth["fetchSource"], "MEMORY", "JSP fetch source"
call assertEq eighth["effectiveAddress"], octToDec("17"), "JSP E"
call assertEq eighth["savedWord"], octToDec("000000040011"), "JSP saved flags,,PC"
call assertEq cpu~accumulator(ac16), octToDec("000000040011"), "AC16 after JSP"
call assertEq eighth["pcAfter"], octToDec("17"), "JSP target PC"
call assertEq cpu~halted, 1, "halt after eighth step"

/* PC=17 octal is the AC window.  Fetch/decode and now execute JRST 0(16). */
nextWord = cpu~fetch
next = cpu~nextInstruction
call assertEq nextWord, octToDec("254016000000"), "word fetched from AC17"
call assertEq cpu~pc, octToDec("17"), "AC17 instruction before execution"
call assertEq next["format"], "GENERAL", "AC17 format"
call assertEq next["mnemonic"], "JRST", "AC17 mnemonic"
call assertEq next["opcode"], octToDec("254"), "AC17 opcode"
call assertEq next["ac"], 0, "AC17 JRST function"
call assertEq next["indirect"], 0, "AC17 JRST indirect"
call assertEq next["index"], octToDec("16"), "AC17 JRST X=16"
call assertEq next["address"], 0, "AC17 JRST Y=0"

flagsBeforeJrst = cpu~flags
ninth = cpu~step
call assertEq ninth["mnemonic"], "JRST", "executed ninth mnemonic"
call assertEq ninth["fetchSource"], "AC", "JRST fetched from AC17"
call assertEq ninth["effectiveAddress"], octToDec("040011"), "JRST indexed target"
call assertEq ninth["pcAfter"], octToDec("040011"), "JRST returns to core"
call assertEq cpu~flags, flagsBeforeJrst, "plain JRST preserves FLAGS"
call assertEq cpu~halted, 1, "halt after ninth step"

/* Untouched next core word: decode only. */
tenthWord = cpu~fetch
tenth = cpu~nextInstruction
call assertEq tenthWord, octToDec("275700000011"), "word at 040011"
call assertEq cpu~pc, octToDec("040011"), "SUBI remains unexecuted"
call assertEq tenth["mnemonic"], "SUBI", "next mnemonic"
call assertEq tenth["opcode"], octToDec("275"), "next opcode 275"
call assertEq tenth["ac"], octToDec("16"), "next AC16"
call assertEq tenth["indirect"], 0, "next indirect"
call assertEq tenth["index"], 0, "next X"
call assertEq tenth["address"], octToDec("11"), "next Y=11"

tape~close
say "KL10 MTBOOT nine-step acceptance: PASS"
say "  040000  TDZ   0,0          -> 040001"
say "  040001  SKIPA 0,0          -> 040003"
say "  040003  CONO  APR,200000   -> 040004"
say "  040004  CONI  PAG,000015   -> 040005"
say "  040005  ANDI  15,600000    -> 040006"
say "  040006  CONO  PAG,0(15)    -> 040007  E=0"
say "  040007  MOVSI 17,254016    -> 040010"
say "  040010  JSP   16,17        -> 000017  AC16=000000,,040011"
say "  000017  JRST  0(16)        -> 040011  fetched from AC17"
say "  next, not executed: 040011  275700,,000011  SUBI 16,11"
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

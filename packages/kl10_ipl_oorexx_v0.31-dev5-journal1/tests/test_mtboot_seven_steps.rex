/* Real MTBOOT.EXB: execute exactly seven admitted instructions, stopping
 * after MOVSI 17,254016 at 040007, then expose 040010 without executing it.
 * Usage: rexx test_mtboot_seven_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_seven_steps.rex /path/to/bb-h137f-bm.tap"
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

/* Decode the next real word, but do not execute it. */
nextWord = cpu~fetch
next = cpu~nextInstruction
call assertEq nextWord, octToDec("265700000017"), "unexecuted word at 040010"
call assertEq cpu~pc, octToDec("040010"), "040010 remains unexecuted"
call assertEq next["format"], "GENERAL", "040010 format"
call assertEq next["mnemonic"], "JSP", "040010 mnemonic"
call assertEq next["opcode"], octToDec("265"), "040010 opcode"
call assertEq next["ac"], octToDec("16"), "040010 AC16"
call assertEq next["indirect"], 0, "040010 indirect"
call assertEq next["index"], 0, "040010 index"
call assertEq next["address"], octToDec("17"), "040010 address"

tape~close
say "KL10 MTBOOT seven-step acceptance: PASS"
say "  040000  TDZ   0,0          -> 040001"
say "  040001  SKIPA 0,0          -> 040003"
say "  040003  CONO  APR,200000   -> 040004"
say "  040004  CONI  PAG,000015   -> 040005"
say "  040005  ANDI  15,600000    -> 040006"
say "  040006  CONO  PAG,0(15)    -> 040007  E=0"
say "  040007  MOVSI 17,254016    -> 040010"
say "  next, not executed: 040010  265700,,000017  JSP 16,17"
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

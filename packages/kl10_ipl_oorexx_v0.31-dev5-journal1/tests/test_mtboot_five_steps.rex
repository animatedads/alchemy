/* Real MTBOOT.EXB: execute exactly five admitted instructions, stopping
 * after ANDI 15,600000 at 040005, then expose 040006 without executing it.
 * Usage: rexx test_mtboot_five_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_five_steps.rex /path/to/bb-h137f-bm.tap"
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
call assertEq third["pcAfter"], octToDec("040004"), "reset next PC"

fourth = cpu~step
call assertEq fourth["ioAction"], "PAG_CONI_STATUS", "fourth action"
call assertEq fourth["pcAfter"], octToDec("040005"), "CONI next PC"
ac15 = octToDec("15")
call assertEq cpu~accumulator(ac15), 0, "AC15 after CONI"

fifthIns = cpu~nextInstruction
call assertEq fifthIns["mnemonic"], "ANDI", "fifth mnemonic"
call assertEq fifthIns["opcode"], octToDec("405"), "fifth opcode"
call assertEq fifthIns["ac"], ac15, "fifth AC"
call assertEq fifthIns["address"], octToDec("600000"), "fifth immediate"

fifth = cpu~step
call assertEq fifth["mnemonic"], "ANDI", "executed fifth mnemonic"
call assertEq fifth["operand"], octToDec("600000"), "ANDI immediate operand"
call assertEq cpu~accumulator(ac15), 0, "real zero remains zero for correct AND"
call assertEq fifth["pcAfter"], octToDec("040006"), "ANDI next PC"
call assertEq cpu~halted, 1, "halt after fifth step"

/* Decode the next real word, but do not execute it.  Raw fields are asserted;
 * effective-address semantics for indexed I/O remain the next boundary. */
nextWord = cpu~fetch
next = cpu~nextInstruction
call assertEq nextWord, octToDec("701215000000"), "unexecuted word at 040006"
call assertEq cpu~pc, octToDec("040006"), "next word remains unexecuted"
call assertEq next["format"], "IO", "040006 format"
call assertEq next["mnemonic"], "CONO", "040006 I/O function"
call assertEq next["deviceName"], "PAG", "040006 device"
call assertEq next["indirect"], 0, "040006 indirect"
call assertEq next["index"], ac15, "040006 X field is 15 octal"
call assertEq next["address"], 0, "040006 Y field"

tape~close
say "KL10 MTBOOT five-step acceptance: PASS"
say "  040000  TDZ   0,0          -> 040001"
say "  040001  SKIPA 0,0          -> 040003"
say "  040003  CONO  APR,200000   -> 040004"
say "  040004  CONI  PAG,000015   -> 040005  AC15(octal)=0"
say "  040005  ANDI  15,600000    -> 040006  AC15(octal)=0"
say "  next, not executed: 040006  701215,,000000  IO raw: CONO PAG, X=15(octal), Y=0"
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

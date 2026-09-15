/* Real MTBOOT.EXB: execute TDZ, SKIPA, CONO APR reset, then exactly
 * CONI PAG,000015.  Halt after each and expose 040005 without executing it.
 * Usage: rexx test_mtboot_four_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_four_steps.rex /path/to/bb-h137f-bm.tap"
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
call assertEq cpu~pag~status, 0, "PAG status after reset"

fourthIns = cpu~nextInstruction
call assertEq fourthIns["format"], "IO", "fourth format"
call assertEq fourthIns["mnemonic"], "CONI", "fourth mnemonic"
call assertEq fourthIns["deviceName"], "PAG", "fourth PAG device"
call assertEq fourthIns["address"], octToDec("000015"), "fourth E"

/* AC15 in DEC notation is octal accumulator number 15 = numeric 13. */
ac15 = octToDec("15")
cpu~setAccumulator(ac15, octToDec("777777777777"))
fourth = cpu~step
call assertEq fourth["ioAction"], "PAG_CONI_STATUS", "fourth action"
call assertEq fourth["ioDestination"], ac15, "CONI destination AC15 octal"
call assertEq fourth["ioStatus"], 0, "PAG status value"
call assertEq cpu~accumulator(ac15), 0, "AC15 octal after CONI"
call assertEq fourth["pcAfter"], octToDec("040005"), "CONI next PC"
call assertEq cpu~halted, 1, "halt after fourth step"

/* Decode the next real word, but do not execute it. */
nextWord = cpu~fetch
next = cpu~nextInstruction
call assertEq nextWord, octToDec("405640600000"), "unexecuted word at 040005"
call assertEq cpu~pc, octToDec("040005"), "next word remains unexecuted"
call assertEq next["format"], "GENERAL", "040005 format"
call assertEq next["mnemonic"], "ANDI", "040005 decode"
call assertEq next["opcode"], octToDec("405"), "040005 opcode"
call assertEq next["ac"], ac15, "040005 AC field"
call assertEq next["address"], octToDec("600000"), "040005 immediate/address field"

tape~close
say "KL10 MTBOOT four-step acceptance: PASS"
say "  040000  630000,,000000  TDZ 0,0          -> 040001"
say "  040001  334000,,000000  SKIPA 0,0        -> 040003"
say "  040003  700200,,200000  CONO APR,200000  -> 040004"
say "  040004  701240,,000015  CONI PAG,000015  -> 040005  AC15(octal)=0"
say "  next, not executed: 040005  405640,,600000  ANDI 15,600000"
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

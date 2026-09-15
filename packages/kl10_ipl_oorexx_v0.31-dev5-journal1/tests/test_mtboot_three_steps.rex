/* Real MTBOOT.EXB: execute TDZ, SKIPA, then exactly CONO APR,200000.
 * Halt after each instruction and expose 040004 without executing it.
 * Usage: rexx test_mtboot_three_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_three_steps.rex /path/to/bb-h137f-bm.tap"
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

thirdIns = cpu~nextInstruction
call assertEq thirdIns["format"], "IO", "third instruction format"
call assertEq thirdIns["mnemonic"], "CONO", "third mnemonic"
call assertEq thirdIns["device"], 0, "third device APR"
call assertEq thirdIns["address"], octToDec("200000"), "third reset condition"
call assertEq cpu~apr~ioResetCount, 0, "APR before third step"
third = cpu~step
call assertEq third["pcBefore"], octToDec("040003"), "third PC before"
call assertEq third["instruction"], octToDec("700200200000"), "CONO APR instruction"
call assertEq third["ioAction"], "APR_IO_RESET", "third action"
call assertEq third["pcAfter"], octToDec("040004"), "I/O reset next PC"
call assertEq cpu~apr~ioResetCount, 1, "APR reset count after third step"
call assertEq cpu~apr~ioResetDone, 1, "APR reset marker after third step"
call assertEq cpu~halted, 1, "halt after third step"

/* Print/decode the next word but do not execute it. */
nextWord = cpu~fetch
next = cpu~nextInstruction
call assertEq nextWord, octToDec("701240000015"), "unexecuted word at 040004"
call assertEq cpu~pc, octToDec("040004"), "next word remains unexecuted"
call assertEq next["format"], "IO", "040004 format"
call assertEq next["mnemonic"], "CONI", "040004 I/O function decode"
call assertEq next["device"], octToDec("010"), "040004 device code"
call assertEq next["deviceName"], "PAG", "040004 device name"
call assertEq next["address"], octToDec("000015"), "040004 E field"

tape~close
say "KL10 MTBOOT three-step acceptance: PASS"
say "  040000  630000,,000000  TDZ 0,0          -> 040001"
say "  040001  334000,,000000  SKIPA 0,0        -> 040003"
say "  040003  700200,,200000  CONO APR,200000  -> 040004  APR reset recorded"
say "  next, not executed: 040004  701240,,000015  CONI PAG,000015"
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

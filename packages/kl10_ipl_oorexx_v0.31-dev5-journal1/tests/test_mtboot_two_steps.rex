/* Real MTBOOT.EXB: execute TDZ then SKIPA, halting after each instruction.
 * Usage: rexx test_mtboot_two_steps.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_two_steps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

first = cpu~step
call assertEq first["mnemonic"], "TDZ", "first mnemonic"
call assertEq first["pcBefore"], octToDec("040000"), "first PC before"
call assertEq first["pcAfter"], octToDec("040001"), "TDZ next PC"
call assertEq first["operand"], 0, "TDZ 0,0 reads fresh AC0 through fast-memory alias"
call assertEq cpu~halted, 1, "halt after first step"

secondIns = cpu~nextInstruction
call assertEq secondIns["opcode"], octToDec("334"), "second opcode"
call assertEq secondIns["mnemonic"], "SKIPA", "second mnemonic"
call assertEq secondIns["ac"], 0, "SKIPA AC field"
call assertEq secondIns["address"], 0, "SKIPA address"
second = cpu~step
call assertEq second["pcBefore"], octToDec("040001"), "second PC before"
call assertEq second["instruction"], octToDec("334000000000"), "SKIPA instruction"
call assertEq second["operand"], 0, "SKIPA 0,0 reads AC0"
call assertEq second["pcAfter"], octToDec("040003"), "SKIPA skips 040002"
call assertEq cpu~pc, octToDec("040003"), "CPU lands on 040003"
call assertEq cpu~halted, 1, "halt after second step"

next = cpu~nextInstruction
call assertEq cpu~fetch, octToDec("700200200000"), "next instruction word"
call assertEq next["format"], "IO", "next instruction format"
call assertEq next["mnemonic"], "CONO", "next I/O mnemonic"
call assertEq next["device"], 0, "APR device code"
call assertEq next["deviceName"], "APR", "APR device name"
call assertEq next["address"], octToDec("200000"), "CONO APR condition word"

tape~close
say "KL10 MTBOOT two-step acceptance: PASS"
say "  040000  630000,,000000  TDZ 0,0     -> 040001"
say "  040001  334000,,000000  SKIPA 0,0   -> 040003"
say "  skipped 040002  001100,,000315"
say "  next    040003  700200,,200000  CONO APR,200000 (not executed)"
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

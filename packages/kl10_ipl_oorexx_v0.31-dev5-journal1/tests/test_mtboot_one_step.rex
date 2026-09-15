/* Extract real MTBOOT.EXB from BB-H137F-BM, establish loader state, execute
 * exactly one PDP-10 instruction, then remain halted.
 * Usage: rexx test_mtboot_one_step.rex /path/to/bb-h137f-bm.tap
 * External fixture SHA-256 (decompressed):
 *   7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_one_step.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
extractor = .Tops20DumperExtractor~new(tape)
mtboot = extractor~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
call assertEq mtboot~sourceRecords, 11, "MTBOOT DUMPER data records"
call assertEq mtboot~words, 5632, "MTBOOT padded DUMPER payload words"
call assertEq mtboot~byteCount, 22528, "MTBOOT four-byte logical stream capacity"

loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
call assertEq loader~dataRecords, 24, "EXB data-record count"
call assertEq loader~depositedWords, 4067, "EXB deposited word count"
call assertEq loader~consumedBytes, 20494, "EXB bytes through start terminator"
call assertEq loader~startAddress, octToDec("040000"), "EXB start address"
call assertEq mem~highestAddress, octToDec("054641"), "EXB highest deposited address"
call assertEq mem~word(octToDec("040000")), octToDec("630000000000"), "MTBOOT first instruction"
call assertEq mem~word(octToDec("040001")), octToDec("334000000000"), "MTBOOT second instruction"

cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)
call assertEq cpu~pc, octToDec("040000"), "CPU starts at EXB terminator address"
call assertEq cpu~halted, 1, "CPU staged halted"
call assertEq cpu~accumulator(0), 0, "fresh AC0"
ins = cpu~nextInstruction
call assertEq ins["opcode"], octToDec("630"), "first opcode 630 octal"
call assertEq ins["mnemonic"], "TDZ", "first mnemonic"
call assertEq ins["ac"], 0, "TDZ AC"
call assertEq ins["indirect"], 0, "TDZ indirect"
call assertEq ins["index"], 0, "TDZ index"
call assertEq ins["address"], 0, "TDZ effective address field"

trace = cpu~step
call assertEq trace["pcBefore"], octToDec("040000"), "step PC before"
call assertEq trace["instruction"], octToDec("630000000000"), "step instruction"
call assertEq trace["mnemonic"], "TDZ", "step mnemonic"
call assertEq trace["effectiveAddress"], 0, "TDZ effective address"
call assertEq trace["operand"], 0, "fresh sparse memory word zero"
call assertEq trace["acBefore"], 0, "AC0 before"
call assertEq trace["acAfter"], 0, "AC0 after TDZ"
call assertEq trace["pcAfter"], octToDec("040001"), "single-step PC increment"
call assertEq trace["halted"], 1, "single step halts again"
call assertEq cpu~pc, octToDec("040001"), "CPU PC after one instruction"
call assertEq cpu~halted, 1, "CPU remains halted after one instruction"
call assertEq cpu~fetch, octToDec("334000000000"), "next instruction visible but not executed"

tape~close
say "KL10 MTBOOT one-step acceptance: PASS"
say "  DUMPER file: PS:<NEW-SYSTEM>MTBOOT.EXB.1"
say "  EXB: 24 records, 4067 words, start PC 040000"
say "  step: 040000  630000,,000000  TDZ 0,0"
say "  after: PC 040001, AC0 000000000000, HALTED"
say "  next: 040001  334000,,000000  (not executed)"
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

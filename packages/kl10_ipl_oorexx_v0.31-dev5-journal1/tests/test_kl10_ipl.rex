/* test_kl10_ipl.rex
 * Usage: rexx test_kl10_ipl.rex /path/to/bb-h137f-bm.tap
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_kl10_ipl.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .Tops20InstallTape~new~~mount(tapePath)
call assertEq tape~filePages, 597, "first tape file page count"

image = .Tops20ExeImage~new(tape)
call assertEq image~directoryWords, 15, ".EXE directory length (17 octal)"
call assertEq image~mappedPageCount, 596, "directory mapped page count"
call assertEq image~entryAddress, 103, "entry address (147 octal)"
call assertEq image~groups~items, 7, ".EXE page-map group count"
blocks = image~blocks
call assertEq blocks~items, 4, ".EXE block count"
call assertEq blocks[1]["code"], 1022, "directory block 1776 octal"
call assertEq blocks[2]["code"], 1021, "entry block 1775 octal"
call assertEq blocks[3]["code"], 1020, "unknown block 1774 octal preserved"
call assertEq blocks[4]["code"], 1023, "end block 1777 octal"

/* Directory + 596 mapped data pages consumes all 597 records in file 1. */
call assertEq image~mappedPageCount + 1, tape~filePages, "directory/data page accounting"

mem = image~loadMemory
call assertEq mem~mappedPages, 596, "KL10 mapped process pages"

cpu = .KL10CPU~new~~loadImage(mem, image~entryAddress)
call assertEq cpu~pc, 103, "CPU PC staged at entry vector"
call assertEq cpu~halted, 1, "CPU deliberately remains halted before first instruction"

firstWord = cpu~fetch
call assertEq firstWord, x2d36("254000002723"), "entry instruction word"
ins = cpu~nextInstruction
call assertEq ins["opcode"], 172, "opcode 254 octal"
call assertEq ins["mnemonic"], "JRST", "entry mnemonic"
call assertEq ins["ac"], 0, "entry AC"
call assertEq ins["indirect"], 0, "entry indirect"
call assertEq ins["index"], 0, "entry index"
call assertEq ins["address"], 1491, "entry target 2723 octal"

say "KL10/TOPS-20 IPL staging acceptance: PASS"
say "  tape file 1 pages: 597 (1 directory + 596 data)"
say "  mapped process pages:" mem~mappedPages
say "  entry PC: 000147"
say "  first instruction: 254000,,002723  JRST 2723"
say "  CPU state: HALTED (MONITR.EXE path not executed by this test)"
tape~close
exit 0

x2d36: procedure
  use arg octalWord
  numeric digits 30
  /* Name retained for compact call site; input is a 12-digit OCTAL PDP-10 word. */
  value = 0
  do i = 1 to octalWord~length
    digit = octalWord~substr(i, 1) + 0
    value = value * 8 + digit
  end
  return value

assertEq: procedure
  parse arg got, expected, label
  if got \= expected then do
    say "FAIL:" label
    say "  expected:" expected
    say "  got:     " got
    exit 1
  end
  return

::requires "../KL10IPL.cls"

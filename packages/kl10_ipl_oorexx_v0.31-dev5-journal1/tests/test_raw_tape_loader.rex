/* Run from tests/: rexx test_raw_tape_loader.rex /path/to/bb-h137f-bm.tap */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_raw_tape_loader.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
loader = .KL10RawTapeLoader~new(tape)
mem = loader~loadFile(0, 0, 32)
call assertEq loader~loadedWords, 32, "bounded raw probe word count"
call assertEq loader~classification, "TOPS20_EXE_DIRECTORY", "first file classification"
call assertEq loader~canAssumePcZero, 0, "raw loader must not invent PC=0"
call assertEq mem~examine(0), octToDec("001776000017"), "MONITR.EXE directory first word"
call assertEq mem~depositedWords, 32, "no silent deposit loss"
tape~close

say "KL10 raw tape loader acceptance: PASS"
say "  first word: 001776,,000017 (.EXE directory, not an instruction)"
say "  raw depositor: 32-word bounded probe, no PC invented"
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
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10TapeRaw.cls"

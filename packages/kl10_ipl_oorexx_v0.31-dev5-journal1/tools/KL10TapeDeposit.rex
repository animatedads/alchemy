/* KL10TapeDeposit.rex
 * Generic PDP-10 raw tape-file deposit probe.
 *
 * Usage (run from package root):
 *   rexx tools/KL10TapeDeposit.rex tape.tap [fileNo] [words]
 *
 * This intentionally does NOT set PC or execute anything.  A tape file can
 * be a structured .EXE, a DUMPER saveset, or a genuine raw bootstrap; merely
 * depositing its representation does not make it an IPL image.
 */
numeric digits 30
parse arg tapPath fileNo maxWords
if tapPath = "" then do
  say "usage: rexx tools/KL10TapeDeposit.rex <simh.tap> [fileNo] [words]"
  exit 2
end
if fileNo = "" then fileNo = 0
if maxWords = "" then maxWords = 32

tape = .SimhTapeReader~new~~mount(tapPath)
loader = .KL10RawTapeLoader~new(tape)
mem = loader~loadFile(fileNo, 0, maxWords)

say "tape file:" fileNo
say "deposited:" loader~loadedWords "words (probe limit" maxWords || ")"
say "classification:" loader~classification
if loader~classification = "TOPS20_EXE_DIRECTORY" then
  say "NOTE: this begins with a TOPS-20 .EXE directory; use the .EXE page mapper, not PC=0."
say "PC: not set"
say "---- words ----"
do loc = 0 to loader~loadedWords - 1
  say oct18(loc) ":" oct36(mem~examine(loc)) sevenbit(mem~examine(loc))
end
say "CPU: not started"
tape~close
exit 0

oct18: procedure
  use arg n
  numeric digits 30
  n = n // (2 ** 18)
  out = ""
  do 6
    out = n // 8 || out
    n = n % 8
  end
  return out

oct36: procedure
  use arg n
  numeric digits 30
  n = n // (2 ** 36)
  out = ""
  do 12
    out = n // 8 || out
    n = n % 8
  end
  return out

sevenbit: procedure
  use arg word
  numeric digits 30
  out = ""
  do shift = 29 by -7 for 5
    c = (word % (2 ** shift)) // 128
    if c >= 32 then do
      if c < 127 then out = out || d2c(c)
      else out = out || "."
    end
    else out = out || "."
  end
  return out

::requires "KL10TapeRaw.cls"

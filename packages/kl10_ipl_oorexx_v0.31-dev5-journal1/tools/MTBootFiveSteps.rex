/* Demonstrate exactly five bounded instructions from the real MTBOOT.EXB,
 * then show the raw decoded instruction at 040006 without executing it. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx MTBootFiveSteps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

do n = 1 to 5
  t = cpu~step
  say oct18(t["pcBefore"]) t["mnemonic"] "-> PC" oct18(t["pcAfter"])
end

nextWord = cpu~fetch
next = cpu~nextInstruction
say "next word, not executed:" nextWord
say "  format:" next["format"] "mnemonic:" next["mnemonic"] "device:" next["deviceName"]
say "  I:" next["indirect"] "X:" next["index"] "Y:" next["address"]
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

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"

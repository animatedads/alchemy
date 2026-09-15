/* Demonstrate exactly six bounded instructions from the real MTBOOT.EXB,
 * then show the decoded instruction at 040007 without executing it. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx MTBootSixSteps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

do n = 1 to 6
  t = cpu~step
  say oct18(t["pcBefore"]) t["mnemonic"] "-> PC" oct18(t["pcAfter"])
  if t["ioAction"] = "PAG_CONO_ZERO" then
    say "  PAG indexed E:" t["effectiveAddress"] "X right-half:" t["ioIndexRightHalf"]
end

nextWord = cpu~fetch
next = cpu~nextInstruction
say "next word, not executed:" oct18(cpu~pc) oct36(nextWord)
say "  format:" next["format"] "mnemonic:" next["mnemonic"] "opcode:" oct3(next["opcode"])
say "  AC:" oct2(next["ac"]) "I:" next["indirect"] "X:" oct2(next["index"]) "Y:" oct18(next["address"])
tape~close
exit 0

oct2: procedure
  use arg n
  numeric digits 30
  n = n // 64
  out = ""
  do 2
    out = n // 8 || out
    n = n % 8
  end
  return out

oct3: procedure
  use arg n
  numeric digits 30
  n = n // 512
  out = ""
  do 3
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

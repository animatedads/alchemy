/* Demonstrate exactly eleven bounded instructions from the real MTBOOT.EXB.
 * The eleventh is indexed AND 0,124(16); then show the next core instruction without executing it. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx MTBootElevenSteps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

do n = 1 to 11
  t = cpu~step
  say oct18(t["pcBefore"]) t["mnemonic"] "-> PC" oct18(t["pcAfter"]) "fetch=" t["fetchSource"]
  if t["ioAction"] = "PAG_CONO_ZERO" then
    say "  PAG indexed E:" oct18(t["effectiveAddress"]) "X right-half:" oct18(t["ioIndexRightHalf"])
  if t["mnemonic"] = "JSP" then
    say "  saved in AC16:" oct36(t["savedWord"])
  if t["mnemonic"] = "JRST" then
    say "  indexed target:" oct18(t["effectiveAddress"])
  if t["mnemonic"] = "SUBI" then
    say "  result AC16:" oct36(t["acAfter"]) "FLAGS:" oct18(t["flagsAfter"])
  if t["mnemonic"] = "AND" then
    say "  indexed E:" oct18(t["effectiveAddress"]) "operand:" oct36(t["operand"]) "result:" oct36(t["result"])
end

nextWord = cpu~fetch
next = cpu~nextInstruction
say "next core word, not executed:" oct18(cpu~pc) oct36(nextWord)
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
  return substr(out,1,6) || ",," || substr(out,7,6)

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

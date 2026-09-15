/* MTBootOneStep.rex
 * Run from package root:
 *   rexx tools/MTBootOneStep.rex /path/to/bb-h137f-bm.tap
 *
 * Establish the real MTBOOT.EXB load state, execute exactly one supported
 * PDP-10 instruction, halt again, and print octal evidence.
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx tools/MTBootOneStep.rex <bb-h137f-bm.tap>"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

say "MTBOOT.EXB:" mtboot~name
say "EXB records:" loader~dataRecords
say "deposited:" loader~depositedWords "36-bit words"
say "PC:" oct18(cpu~pc)
say "instruction:" oct36(cpu~fetch)
trace = cpu~step
say "executed:" trace["mnemonic"] "AC" trace["ac"] "," oct18(trace["effectiveAddress"])
say "PC after:" oct18(cpu~pc)
say "AC after:" oct36(cpu~accumulator(trace["ac"]))
say "HALTED:" cpu~halted
say "next, not executed:" oct36(cpu~fetch)
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

::requires "KL10IPL.cls"
::requires "MTBoot.cls"

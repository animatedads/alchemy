/* MTBootTwoSteps.rex
 * Establish real MTBOOT.EXB state, execute exactly TDZ then SKIPA, halting
 * after each step, and expose the first unsupported hardware instruction.
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx tools/MTBootTwoSteps.rex <bb-h137f-bm.tap>"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

say "MTBOOT.EXB:" mtboot~name
say "start PC:" oct18(cpu~pc)

do stepNo = 1 to 2
  ins = cpu~nextInstruction
  before = cpu~pc
  trace = cpu~step
  say "step" stepNo || ":" oct18(before) oct36(trace["instruction"]) trace["mnemonic"] "->" oct18(cpu~pc) "HALTED=" cpu~halted
end

next = cpu~nextInstruction
say "next, not executed:" oct18(cpu~pc) oct36(cpu~fetch) next["mnemonic"] next["deviceName"] "device=" oct3(next["device"]) "E=" oct18(next["address"])
tape~close
exit 0

oct3: procedure
  use arg n
  numeric digits 30
  out = ""
  do 3
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

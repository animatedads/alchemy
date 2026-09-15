/* Establish real MTBOOT.EXB state, execute exactly TDZ, SKIPA,
 * CONO APR,200000 and CONI PAG,000015, halting after each.  Show 040005 only.
 */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx tools/MTBootFourSteps.rex <bb-h137f-bm.tap>"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

say "MTBOOT.EXB:" mtboot~name
say "start PC:" oct18(cpu~pc)

/* The real first three establish the reset state. */
do stepNo = 1 to 3
  before = cpu~pc
  trace = cpu~step
  say "step" stepNo || ":" oct18(before) oct36(trace["instruction"]) trace["mnemonic"] "->" oct18(cpu~pc) "HALTED=" cpu~halted
  if trace["ioAction"] \= .nil then say "  I/O action:" trace["ioAction"]
end

/* Make the AC-window write visible rather than succeeding because AC15 was
 * already zero.  AC15 here is DEC octal accumulator 15 (numeric 13). */
ac15 = octToDec("15")
cpu~setAccumulator(ac15, octToDec("777777777777"))
before = cpu~pc
trace = cpu~step
say "step 4:" oct18(before) oct36(trace["instruction"]) trace["mnemonic"] trace["deviceName"] "->" oct18(cpu~pc) "HALTED=" cpu~halted
say "  PAG status:" oct36(trace["ioStatus"]) "destination AC" oct2(ac15) "=" oct36(cpu~accumulator(ac15))

next = cpu~nextInstruction
say "next, not executed:" oct18(cpu~pc) oct36(cpu~fetch) next["mnemonic"] "AC=" oct2(next["ac"]) "field=" oct18(next["address"])
tape~close
exit 0

octToDec: procedure
  use arg text
  numeric digits 30
  n = 0
  do i = 1 to text~length
    n = n * 8 + text~substr(i, 1)
  end
  return n

oct2: procedure
  use arg n
  numeric digits 30
  out = ""
  do 2
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

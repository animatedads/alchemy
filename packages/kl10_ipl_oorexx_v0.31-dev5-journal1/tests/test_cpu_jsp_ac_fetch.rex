/* JSP semantic + AC-window instruction-fetch guard.
 *
 * Proves three boundaries together:
 *   1. JSP 16,17 saves the bounded zero-flags PC word in AC16 octal.
 *   2. PC transfers to 17 octal.
 *   3. The next instruction is fetched from AC17 octal, not sparse memory[17].
 */
numeric digits 30
pc = octToDec("000100")
jspWord = Oct("265700,,000017")~decimal
jrstWord = Oct("254016,,000000")~decimal
ac16 = octToDec("16")   /* numeric 14 */
ac17 = octToDec("17")   /* numeric 15 */
poison = Oct("777777,,777777")~decimal
expectedSaved = Oct("000000,,000101")~decimal

mem = .FetchOnlyMemory~new(pc, jspWord)
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(ac16, poison)
cpu~setAccumulator(ac17, jrstWord)

call assertEq cpu~flags, 0, "bounded flags begin clear"

trace = cpu~step
call assertEq trace["mnemonic"], "JSP", "JSP mnemonic"
call assertEq trace["fetchSource"], "MEMORY", "JSP fetched from core"
call assertEq trace["effectiveAddress"], octToDec("17"), "JSP target"
call assertEq trace["savedWord"], expectedSaved, "JSP saved flags,,PC"
call assertEq trace["acBefore"], poison, "AC16 poison before"
call assertEq trace["acAfter"], expectedSaved, "AC16 after JSP"
call assertEq cpu~accumulator(ac16), expectedSaved, "AC16 saved word"
call assertEq cpu~pc, octToDec("17"), "JSP transfers to AC17 address"
call assertEq cpu~halted, 1, "halt after JSP step"
call assertEq mem~reads, 1, "JSP performs one core instruction fetch"

/* The next fetch must come from AC17.  FetchOnlyMemory rejects every address
 * except the original JSP location, so a sparse-memory read of 17 fails. */
nextWord = cpu~fetch
call assertEq nextWord, jrstWord, "instruction fetched from AC17"
call assertEq mem~reads, 1, "AC-window fetch performs no core read"
next = cpu~nextInstruction
call assertEq mem~reads, 1, "AC-window decode performs no core read"
call assertEq next["mnemonic"], "JRST", "AC17 instruction mnemonic"
call assertEq next["opcode"], octToDec("254"), "AC17 opcode"
call assertEq next["ac"], 0, "JRST AC field"
call assertEq next["indirect"], 0, "JRST indirect"
call assertEq next["index"], octToDec("16"), "JRST X=16 octal"
call assertEq next["address"], 0, "JRST Y=0"
call assertEq cpu~pc, octToDec("17"), "JRST remains unexecuted"

say "KL10 JSP + AC fetch acceptance: PASS"
say "  JSP 16,17: AC16 <- 000000,,000101; PC <- 000017"
say "  next fetch comes from AC17, not sparse core"
say "  AC17 decodes: 254016,,000000  JRST 0(16)  NOT executed"
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

::class FetchOnlyMemory public
::method init
  expose base instruction readCount
  use arg at, word
  base = at
  instruction = word
  readCount = 0
::method word
  expose base instruction readCount
  use arg at
  readCount = readCount + 1
  if at = base then return instruction
  raise syntax 40.900 array("unexpected sparse-core instruction fetch at" at)
::method reads
  expose readCount
  return readCount

::requires "../KL10IPL.cls"
::requires "../lib/OctalBits.cls"

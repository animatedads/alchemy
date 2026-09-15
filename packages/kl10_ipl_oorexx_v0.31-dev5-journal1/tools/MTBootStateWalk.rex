/* Walk MTBOOT with visible-event accounting.
 * The CPU's architectural step semantics remain untouched.  The proven
 * AC1..AC6 relocation loop is summarized by this presentation tool rather
 * than replayed ~92,000 times under the debug interpreter.
 *
 * Usage: rexx MTBootStateWalk.rex /path/to/bb-h137f-bm.tap [visible-events]
 */
numeric digits 30
parse arg tapePath visibleLimit
if tapePath = "" then do
  say "usage: rexx MTBootStateWalk.rex /path/to/bb-h137f-bm.tap [visible-events]"
  exit 2
end
if visibleLimit = "" then visibleLimit = 40
if \datatype(visibleLimit, "W") | visibleLimit < 1 then do
  say "visible-events must be a positive integer"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

say "=== KL10 MTBOOT live state walk ==="
say "initial" cpu~string
say "        " cpu~memory~string
say "        " cpu~ioBus~string
say "        " cpu~apr~string
say "        " cpu~pag~string
say

visible = 0
machineSteps = 0
do while visible < visibleLimit
  pc = cpu~pc
  word = cpu~fetch
  d = cpu~decode(word)

  /* At AC6 the first MOVE/EXCH/MOVEM/AOS/AOS body has already executed.
   * This exact loop has an instruction-by-instruction regression.  Finish
   * its remaining swaps mathematically, preserving the resulting machine
   * state while avoiding debug-interpreter replay cost. */
  if pc = 6 & d["mnemonic"] = "SOJG" then do
    startCount = cpu~accumulator(octToDec('13'))
    original11 = (cpu~accumulator(octToDec('11')) - 1) // (2 ** 18)
    original12 = (cpu~accumulator(octToDec('12')) - 1) // (2 ** 18)
    src = cpu~accumulator(octToDec('12')) // (2 ** 18)
    dst = cpu~accumulator(octToDec('11')) // (2 ** 18)
    remainingBodies = startCount - 1

    do n = 1 to remainingBodies
      sw = cpu~memory~word(src)
      dw = cpu~memory~word(dst)
      cpu~memory~put(dst, sw)
      cpu~memory~put(src, dw)
      src = (src + 1) // (2 ** 18)
      dst = (dst + 1) // (2 ** 18)
    end

    cpu~setAccumulator(octToDec('11'), dst)
    cpu~setAccumulator(octToDec('12'), src)
    cpu~setAccumulator(octToDec('13'), 0)
    ignored = cpu~restoreCoreState(7, cpu~flags, cpu~halted)
    /* From PC6: one current SOJG plus (count-1) complete six-word turns. */
    machineSteps = machineSteps + startCount * 6 - 5
    visible = visible + 1

    say "AC-loop trips=" || startCount -
        "AC11" .LROct~fromDecimal(original11)~right || "->" || .LROct~fromDecimal(cpu~accumulator(octToDec('11')))~right -
        "AC12" .LROct~fromDecimal(original12)~right || "->" || .LROct~fromDecimal(cpu~accumulator(octToDec('12')))~right -
        "AC13" .LROct~fromDecimal(startCount)~right || "->000000"
    nextWord = cpu~fetch
    nextD = cpu~decode(nextWord)
    say "fallthrough PC=" || .LROct~fromDecimal(cpu~pc)~right -
        .LROct~fromDecimal(nextWord)~string nextD["mnemonic"]

    /* Follow the real panel-switch JRST exactly once, then stop. */
    if nextD["mnemonic"] = "JRST" then do
      tr = cpu~step
      machineSteps = machineSteps + 1
      say "panel-switch JRST ->" .LROct~fromDecimal(cpu~pc)~right
      say "visible=" || visible "machine-steps=" || machineSteps
      leave
    end
    iterate
  end

  tr = cpu~step
  machineSteps = machineSteps + 1
  visible = visible + 1
  pcBefore = .LROct~fromDecimal(tr["pcBefore"])~right
  pcAfter = .LROct~fromDecimal(tr["pcAfter"])~right
  inst = .LROct~fromDecimal(tr["instruction"])~string
  say "step" right(machineSteps, 6) pcBefore inst left(tr["mnemonic"], 6) "->" pcAfter "fetch=" || tr["fetchSource"]
  if tr["effectiveAddress"] \= .nil then
    say "       E=" || .LROct~fromDecimal(tr["effectiveAddress"])~right
  if tr["memoryWrite"] \= .nil then do
    if tr["memoryWrite"] then say "       write result=" || .LROct~fromDecimal(tr["result"])~string
  end
  if tr["mnemonic"] = "BLT" then
    say "       BLT src=" || .LROct~fromDecimal(tr["bltSourceStart"])~right -
        "dst=" || .LROct~fromDecimal(tr["bltDestinationStart"])~right -
        "end=" || .LROct~fromDecimal(tr["bltEndDestination"])~right -
        "count=" || tr["bltTransferCount"] -
        "final=" || .LROct~fromDecimal(tr["bltFinalPointer"])~string
  if tr["format"] = "IO" then do
    say "       " cpu~ioBus~string
    say "       " cpu~apr~string
    say "       " cpu~pag~string
  end
  say "       " cpu~string
  say
end

if visible >= visibleLimit then
  say "next (not executed):" .LROct~fromDecimal(cpu~pc)~right .LROct~fromDecimal(cpu~fetch)~string cpu~decode(cpu~fetch)["mnemonic"]
tape~close
exit 0

octToDec: procedure
  use arg text
  numeric digits 30
  n=0
  do i=1 to text~length
    n=n*8+text~substr(i,1)
  end
  return n

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"

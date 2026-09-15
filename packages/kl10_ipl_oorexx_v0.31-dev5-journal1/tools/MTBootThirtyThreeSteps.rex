/* Execute the currently admitted 33-instruction MTBOOT path and display its
 * final live machine state. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx MTBootThirtyThreeSteps.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)
cpu = .KL10CPU~new~~loadImage(mem, loader~startAddress)

do i = 1 to 33
  tr = cpu~step
  say right(i, 2) .LROct~fromDecimal(tr["pcBefore"])~right -
      .LROct~fromDecimal(tr["instruction"])~string left(tr["mnemonic"], 6) -
      "->" .LROct~fromDecimal(tr["pcAfter"])~right "fetch=" || tr["fetchSource"]
  if tr["mnemonic"] = "BLT" then
    say "     BLT" .LROct~fromDecimal(tr["bltSourceStart"])~right || ".." || -
        .LROct~fromDecimal(tr["bltSourceStart"] + tr["bltTransferCount"] - 1)~right -
        "->" .LROct~fromDecimal(tr["bltDestinationStart"])~right || ".." || -
        .LROct~fromDecimal(tr["bltEndDestination"])~right -
        "final=" || .LROct~fromDecimal(tr["bltFinalPointer"])~string
end

say
say cpu
say cpu~memory
say cpu~ioBus
say cpu~apr
say cpu~pag
say "M[047503]=" || .LROct~fromDecimal(cpu~memory~word(octToDec("047503")))~string
say "next, not executed:" .LROct~fromDecimal(cpu~pc)~right -
    .LROct~fromDecimal(cpu~fetch)~string cpu~decode(cpu~fetch)["mnemonic"] -
    "fetch=" || cpu~memory~sourceKind(cpu~pc)
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

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"

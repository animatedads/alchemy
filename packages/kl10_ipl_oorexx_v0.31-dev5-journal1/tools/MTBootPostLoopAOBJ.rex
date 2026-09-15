numeric digits 30
parse arg tapePath steps
if tapePath = "" then exit 2
if steps = "" then steps = 80

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)

/* Reproduce the 036000(octal)-iteration AC-resident swap loop directly.
 * Each turn does MOVE src; EXCH dst; MOVEM src; AOS dst; AOS src; SOJG count. */
src = octToDec("742000")
dst = octToDec("011000")
count = octToDec("036000")
do i = 1 to count
  srcWord = mem~word(src)
  dstWord = mem~word(dst)
  mem~put(dst, srcWord)
  mem~put(src, dstWord)
  src = (src + 1) // (2 ** 18)
  dst = (dst + 1) // (2 ** 18)
end

/* State immediately after SOJG falls through and AC7 JRST reaches 771044. */
cpu = .KL10CPU~new~~loadImage(mem, octToDec("771044"))
cpu~setAccumulator(0, 0)
cpu~setAccumulator(1, octToDec("200612000000"))
cpu~setAccumulator(2, octToDec("250611000000"))
cpu~setAccumulator(3, octToDec("202612000000"))
cpu~setAccumulator(4, octToDec("350000000011"))
cpu~setAccumulator(5, octToDec("350000000012"))
cpu~setAccumulator(6, octToDec("367540000001"))
cpu~setAccumulator(7, octToDec("254010772044"))
cpu~setAccumulator(8, octToDec("000000777000"))
cpu~setAccumulator(9, octToDec("000000047000"))
cpu~setAccumulator(10, 0)
cpu~setAccumulator(11, 0)
cpu~setAccumulator(12, 0)
cpu~setAccumulator(13, 0)
cpu~setAccumulator(14, octToDec("000000000047"))
cpu~setAccumulator(15, octToDec("000000011000"))

say "post-loop dst=" || .LROct~fromDecimal(dst)~right "src=" || .LROct~fromDecimal(src)~right
say "start" .LROct~fromDecimal(cpu~pc)~right .LROct~fromDecimal(cpu~fetch)~string cpu~decode(cpu~fetch)["mnemonic"]
do i = 1 to steps
  tr = cpu~step
  if tr["result"] = .nil then resultText = "-"
  else resultText = .LROct~fromDecimal(tr["result"])~string
  say "step" i .LROct~fromDecimal(tr["pcBefore"])~right tr["mnemonic"] "->" .LROct~fromDecimal(cpu~pc)~right,
      "AC=" || .LROct~fromDecimal(tr["ac"])~right,
      "result=" || resultText
end
say "next" .LROct~fromDecimal(cpu~pc)~right .LROct~fromDecimal(cpu~fetch)~string cpu~decode(cpu~fetch)["mnemonic"]
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

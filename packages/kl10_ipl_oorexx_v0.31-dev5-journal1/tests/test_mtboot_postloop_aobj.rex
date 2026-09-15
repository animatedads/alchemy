/* Tape-derived post-loop handoff: reproduce the known 036000-turn swap loop
 * directly, then execute the real code at 771044 through the first AOBJN. */
numeric digits 30
parse arg tapePath
if tapePath = "" then do
  say "usage: rexx test_mtboot_postloop_aobj.rex /path/to/bb-h137f-bm.tap"
  exit 2
end

tape = .SimhTapeReader~new~~mount(tapePath)
mtboot = .Tops20DumperExtractor~new(tape)~extract("PS:<NEW-SYSTEM>MTBOOT.EXB.1")
loader = .KL10ExbLoader~new
mem = loader~load(mtboot)

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
call assertEq dst, octToDec("047000"), "loop final AC11/destination"
call assertEq src, 0, "loop final AC12/source wraps to zero"

cpu = .KL10CPU~new~~loadImage(mem, octToDec("771044"))
/* Architectural state observed at the real loop handoff. */
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

expectedNames = .array~of("HRRZI", "MOVE", "SUBI", "MOVEI", "HRL", "SETZM", "BLT", -
  "MOVSI", "MOVEM", "MOVEI", "MOVEM", "MOVE", "LSH", "MOVEI", "LSH", -
  "MOVEM", "MOVSI", "MOVEM", "ADDI", "MOVEI", "LSH", "HRLI", "MOVEI", -
  "HRRZ", "TLO", "MOVEM", "ADDI", "AOBJN")

do i = 1 to expectedNames~items
  tr = cpu~step
  call assertEq tr["mnemonic"], expectedNames[i], "post-loop step" i "mnemonic"
  if i = 28 then aobjTrace = tr
end

call assertEq aobjTrace["pcBefore"], octToDec("771077"), "AOBJN real site"
call assertEq aobjTrace["effectiveAddress"], octToDec("771073"), "AOBJN branch E"
call assertEq aobjTrace["operand"], octToDec("777742000742"), "AOBJN AC2 before"
call assertEq aobjTrace["result"], octToDec("777743000743"), "AOBJN independent-half result"
call assertEq aobjTrace["branchTaken"], 1, "AOBJN branch taken"
call assertEq cpu~pc, octToDec("771073"), "AOBJN branch destination"
call assertEq cpu~accumulator(2), octToDec("777743000743"), "AOBJN AC2 after"

tape~close
say "KL10 MTBOOT post-loop AOBJ acceptance: PASS"
say "  direct 036000-turn tape-memory swap reproduces the real loop handoff"
say "  771077 AOBJN: AC2 777742,,000742 -> 777743,,000743, branch 771073"
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

::requires "../KL10IPL.cls"
::requires "../MTBoot.cls"

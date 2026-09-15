/* Indexed PAG CONO semantic guard for v0.8.
 * The real MTBOOT instruction is CONO PAG,0(15) octal.  Section-zero PDP-10
 * indexing adds the RIGHT half of AC[X] to Y modulo 2**18.  The resulting E
 * is the I/O condition word; it is not fetched as memory.
 */
numeric digits 30
pc = octToDec("000100")
conoIndexed = octToDec("701215000000")  /* CONO PAG,0(15) */
ac15 = octToDec("15")

/* Valid zero condition: left half is deliberately nonzero, right half zero.
 * Only the right half may contribute to the 18-bit effective address. */
leftOnly = octToDec("123456000000")
mem = .FetchOnlyMemory~new(pc, conoIndexed)
cpu = .KL10CPU~new~~loadImage(mem, pc)
cpu~setAccumulator(ac15, leftOnly)
trace = cpu~step
call assertEq trace["mnemonic"], "CONO", "mnemonic"
call assertEq trace["deviceName"], "PAG", "device"
call assertEq trace["ioIndexValue"], leftOnly, "index full value"
call assertEq trace["ioIndexRightHalf"], 0, "index right half"
call assertEq trace["effectiveAddress"], 0, "indexed effective condition"
call assertEq trace["ioCondition"], 0, "PAG condition"
call assertEq trace["ioAction"], "PAG_CONO_ZERO", "bounded PAG action"
call assertEq trace["pagConoZeroCountBefore"], 0, "PAG CONO count before"
call assertEq trace["pagConoZeroCountAfter"], 1, "PAG CONO count after"
call assertEq trace["pagStatusAfter"], 0, "PAG status after zero control"
call assertEq cpu~pc, pc + 1, "PC after valid indexed PAG CONO"
call assertEq cpu~halted, 1, "halt after valid indexed PAG CONO"
call assertEq mem~reads, 1, "indexed CONO performs instruction fetch only"

/* A right-half page-enable bit must be honored.  If indexing were ignored
 * this would incorrectly execute as CONO PAG,0; the bounded memory model must
 * reject the transition because address translation is not implemented yet. */
nonzeroIndex = octToDec("000000020000")
badMem = .FetchOnlyMemory~new(pc, conoIndexed)
bad = .KL10CPU~new~~loadImage(badMem, pc)
bad~setAccumulator(ac15, nonzeroIndex)
signal on syntax name expectedNonzeroIndex
ignored = bad~step
signal off syntax
say "FAIL: indexed CONO PAG with AC15=020000 should be rejected"
exit 1

expectedNonzeroIndex:
signal off syntax
call assertEq bad~pc, pc, "page-enable indexed condition leaves PC"
call assertEq bad~pag~conoZeroCount, 0, "page-enable indexed condition leaves PAG untouched"
call assertEq badMem~reads, 1, "rejected indexed CONO still fetched instruction only"

say "KL10 indexed PAG CONO acceptance: PASS"
say "  X=15(octal) contributes AC15 right half only"
say "  AC15 RH=0 -> E=0 -> PAG_CONO_ZERO"
say "  AC15 RH=020000 -> E=020000 -> pager enable rejected"
say "  I/O condition E is not fetched from memory"
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
  raise syntax 40.900 array("unexpected memory fetch at" at)
::method reads
  expose readCount
  return readCount

::requires "../KL10IPL.cls"

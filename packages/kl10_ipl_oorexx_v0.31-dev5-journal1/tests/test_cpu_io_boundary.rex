/* v0.6 I/O boundary: CONI PAG is admitted only after the modeled APR I/O
 * reset establishes the one bounded status value we know.  A fresh CPU must
 * still refuse it rather than guessing reset state. */
numeric digits 30
mem = .KL10DepositMemory~new
pc = octToDec("000100")
mem~deposit(pc, octToDec("701240000015"))   /* CONI PAG,000015 */
cpu = .KL10CPU~new~~loadImage(mem, pc)
ins = cpu~nextInstruction
call assertEq ins["format"], "IO", "I/O format"
call assertEq ins["mnemonic"], "CONI", "I/O mnemonic"
call assertEq ins["device"], octToDec("010"), "PAG device code"
call assertEq ins["deviceName"], "PAG", "PAG device name"
call assertEq ins["address"], octToDec("000015"), "PAG E field"

signal on syntax name expectedUnsupported
ignored = cpu~step
signal off syntax
say "FAIL: pre-reset CONI PAG execution should have been rejected"
exit 1

expectedUnsupported:
signal off syntax
call assertEq cpu~pc, pc, "unsupported I/O leaves PC unchanged"
call assertEq cpu~halted, 1, "unsupported I/O remains halted"
call assertEq cpu~apr~ioResetCount, 0, "unsupported PAG I/O does not fake APR reset"
say "KL10 I/O boundary acceptance: PASS"
say "  decoded 701240,,000015 as CONI PAG,000015"
say "  pre-reset execution rejected: PAG status is not guessed"
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
    say "FAIL:" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
::requires "../KL10TapeRaw.cls"

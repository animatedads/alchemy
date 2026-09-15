MICRO = 1000000
clock = .WLUTestTimeSource~new(1000000)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-2026-08", "000102030405060708090a0b0c0d0e0f")
ledger = .WLUMemoryLedger~new
auth = .WLUAuthority~new(keys, ledger, clock)

account = .WLUAccount~new("acct-ai-gpt", 10 * MICRO)
auth~addAccount(account)
bucket = .WLUCapacityBucket~new("terminal-global", 3 * MICRO, 1 * MICRO)
auth~addBucket(bucket)
auth~bindAccount("AI_GPT", "TERMINAL:*", account~accountId)
auth~bindBucket("*", "TERMINAL:*", bucket~bucketId)

r1 = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 2 * MICRO, 30, "request-1")
call assertTrue r1~ok, "first reservation"
call assertEq 2 * MICRO, account~reservedMicroWlu, "account hold"
call assertEq 1 * MICRO, bucket~tokensMicroWlu, "bucket hold"
call assertTrue auth~admit(r1~value)~ok, "reservation admission"

/* Idempotency cannot double-hold. */
r1again = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 2 * MICRO, 30, "request-1")
call assertTrue r1again~ok, "idempotent reserve replay"
call assertEq r1~value~reservationId, r1again~value~reservationId, "same reservation id"
call assertEq 2 * MICRO, account~reservedMicroWlu, "no duplicate account hold"

/* Same key, different request parameters is an explicit conflict. */
conflict = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 1 * MICRO, 30, "request-1")
call assertEq "WLU_IDEMPOTENCY_CONFLICT", conflict~code, "idempotency conflict"

/* Mandatory policy bucket is derived by authority, not supplied by caller. */
r2 = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 2 * MICRO, 30, "request-2")
call assertTrue \r2~ok, "capacity refusal"
call assertEq "WLU_CAPACITY_EXHAUSTED", r2~code, "temporary capacity code"
call assertEq 1, r2~retryAfterSeconds, "capacity retry hint"
call assertEq 2 * MICRO, account~reservedMicroWlu, "failed reserve leaves account untouched"

/* Record actual work, then release only the unused part. */
consumed = auth~consume(r1~value, 1500000, "op-A")
call assertTrue consumed~ok, "consume"
consumedAgain = auth~consume(r1~value, 1500000, "op-A")
call assertTrue consumedAgain~ok, "idempotent consume replay"
call assertEq 2 * MICRO, account~reservedMicroWlu, "consumption remains inside existing hold until settlement"
released = auth~release(r1~value)
call assertTrue released~ok, "release"
call assertEq 0, account~reservedMicroWlu, "reservation released"
call assertEq 1500000, account~spentMicroWlu, "consumed WLU remains spent"
call assertEq 1500000, bucket~tokensMicroWlu, "unused capacity refunded, actual remains consumed"

/* Refill makes a temporary capacity denial become admissible later. */
ignore = clock~advanceSeconds(1)
r3 = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 2 * MICRO, 30, "request-3")
call assertTrue r3~ok, "capacity refilled"
oldProof = r3~value
extra = auth~topUp(r3~value, 600000)
call assertTrue \extra~ok, "top-up correctly constrained by bucket"
call assertEq "WLU_CAPACITY_EXHAUSTED", extra~code, "top-up capacity code"
ignore = auth~release(r3~value)

/* Expiry is accounting cleanup plus an unambiguous admission failure. */
r4 = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 1 * MICRO, 1, "request-4")
call assertTrue r4~ok, "expiring reservation created"
ignore = auth~consume(r4~value, 250000, "op-exp")
ignore = clock~advanceSeconds(2)
expired = auth~admit(r4~value)
call assertTrue \expired~ok, "expired reservation rejected"
call assertEq "WLU_RESERVATION_EXPIRED", expired~code, "expiry code"
call assertEq 1750000, account~spentMicroWlu, "expiry charges already-observed work"
call assertEq "EXPIRED", auth~reservationState(r4~value~reservationId)~value, "expiry state"

/* A forged amount with a copied tag is rejected. */
good = auth~reserve("AI_GPT", "TERMINAL:QPADEV0037", 500000, 30, "request-5")
call assertTrue good~ok, "forgery fixture reserve"
g = good~value
forged = .WLUReservation~new(g~reservationId, g~identity, g~accountId, g~scope, g~rateCardId, g~rateCardVersion, g~reservedMicroWlu + 1, g~issuedTick, g~expiresTick, g~bucketIds, g~proofRevision, g~proof)
forgedResult = auth~admit(forged)
call assertTrue \forgedResult~ok, "forged reservation rejected"
call assertEq "WLU_RESERVATION_PROOF_INVALID", forgedResult~code, "forged proof code"
ignore = auth~release(g)

call assertTrue ledger~count >= 10, "ledger receives admission/accounting evidence"
say "PASS test_authority"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WorkLoadUnits.cls"

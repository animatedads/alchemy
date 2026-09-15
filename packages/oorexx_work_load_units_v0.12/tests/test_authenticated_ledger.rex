path = "/tmp/wlu_authenticated_ledger_test.log"
ignore = RxFuncAdd("SysFileDelete", "rxunixsys", "SysFileDelete")
ignore = SysFileDelete(path)
keys = .WLUFastMacKeyRing~new
ignore = keys~addKey("hot-1", "000102030405060708090a0b0c0d0e0f")
ledger = .WLUAuthenticatedFileLedger~new(path, keys)
ignore = ledger~append(1000000, "RESERVE", "r1", "AI_GPT", "acct1", "TERMINAL:QPADEV0037", 2000000, "")
ignore = ledger~append(1100000, "CONSUME", "r1", "AI_GPT", "acct1", "TERMINAL:QPADEV0037", 500000, "AID")
ignore = ledger~append(1200000, "SETTLED", "r1", "AI_GPT", "acct1", "TERMINAL:QPADEV0037", 500000, "reserved=2000000")
verified = ledger~readVerified
call assertTrue verified~ok, "ledger verifies"
call assertEq 3, verified~value[1]~items, "ledger count"
call assertEq ledger~previousTag, verified~value[2], "chain head"

/* Re-open/recover from the authenticated chain. */
reopened = .WLUAuthenticatedFileLedger~new(path, keys)
call assertEq 3, reopened~sequence, "recovered sequence"
call assertEq ledger~previousTag, reopened~previousTag, "recovered chain head"

/* An occasional Ed25519 checkpoint can make the shared-key chain portable. */
seed = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
checkpointSigner = .WLUEd25519CheckpointAuthority~new("audit-ed-1", seed)
checkpointResult = ledger~checkpoint(checkpointSigner, 1300000)
call assertTrue checkpointResult~ok, "checkpoint created"
call assertTrue ledger~verifyCheckpoint(checkpointSigner, checkpointResult~value), "checkpoint verifies"

say "PASS test_authenticated_ledger"
call sysFileDelete path
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

::requires "WLULedger.cls"

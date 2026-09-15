/* Prove a new worker/Engine object can recover a committed receipt from the
   SQL boundary and does not need in-memory account state to re-execute it. */
executor = .FederationBankFixtureSqlExecutor~new
db = .FederationBankFixtures~database(executor)
ext1 = .FederationBankFixtures~externalEnvironment
e1 = .FederationBankFixtures~buildEngine(db, .true, ext1)
call open e1, "USD-R-SRC", "OPEN-R-SRC"
call open e1, "USD-R-DST", "OPEN-R-DST"
call must e1~ledger~postTransfer("SEED-R", "FB-SETTLEMENT-USD", "USD-R-SRC", 1000000, "USD"), "seed"
cmd = .FederationBankCommand~new("R-CMD", "TRANSFER", "R-IDEM", "CUST-001", "USD-R-SRC", "USD-R-DST", "USD", 125000, "WEB", "CUST-001")
r1 = e1~handle(cmd)
call must r1, "first transfer"
call assert r1~value["transactionId"] = "R-IDEM", "first transaction committed"

/* Simulate worker restart: new Engine and empty receipt cache. The test engine
   intentionally does not rehydrate USD-R-SRC/USD-R-DST, proving replay is
   settled from the durable receipt before any attempt to execute the transfer. */
ext2 = .FederationBankFixtures~externalEnvironment
e2 = .FederationBankFixtures~buildEngine(db, .true, ext2)
beforeCommands = executor~commands~items
r2 = e2~handle(cmd)
call assert r2~ok, "replay returns committed outcome"
call assert r2~code = "REPLAY_RECOVERED", "restart replay recovered from DB receipt"
call assert r2~value["transactionId"] = "R-IDEM", "original banking transaction identity retained"
call assert r2~value["recoveredFromDurableReceipt"] = "true", "DB recovery provenance retained"
call assert r2~value["replaySecurityDisposition"] = "REJECT", "Bouncer rejects replay execution"
afterCommands = executor~commands~items
call assert afterCommands = beforeCommands + 1, "restart replay performs one DB receipt lookup only"
sql = executor~lastCommand~stdinText
call assert sql~pos("fb_receipt_select") > 0, "durable receipt queried"
call assert sql~pos("federationbank_ledger_postings") = 0, "replay performs no ledger write"
say "PASS durable restart-safe receipt recovery + Bouncer replay rejection"
exit 0
open: procedure
  use arg e, accountId, idem
  c=.FederationBankCommand~new("CMD-" || idem,"OPEN_ACCOUNT",idem,"CUST-001","","","USD",0,"WEB","CUST-001",.nil,"OFFSHORE_CURRENT",accountId)
  call must e~handle(c), "open " || accountId
  return
must: procedure
  use arg r,label
  if r~ok=.false then do; say "FAIL" label r~code r~detail; exit 1; end
  return
assert: procedure
  use arg condition,label
  if \condition then do; say "FAIL" label; exit 1; end
  return
::requires "FederationBankFixtures.cls"

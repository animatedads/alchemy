numeric digits 50
storePath="./tests/tmp_vmm_accounting_durable_funding_v010.jsonl"
v=.VectorMeridianMarkets~new
f=.VMMFundingFacility~new("FAC-DUR","FEDERATIONBANK_MERCHANT_CAPITAL","VECTOR_MERIDIAN_MARKETS_LTD","MERCHANT_CAPITAL","GBP",5000000,100,"LEGAL-DUR","POL-DUR","20271231")
v~registerFundingFacility(f)
eng=.VMMAccountingStore~createEngine(storePath,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
acct=.VMMAccountingService~new(v,eng)
d1=.VMMFundingDraw~new("DRAW-DUR-1","FAC-DUR",1000000,"GBP","20260828T120000","LENDER-AUTH-1","OBL-DUR-1")
r1=acct~postFundingDraw(d1,"2026-08-28","2026-08")
call assertEq "POSTED",r1~status,"first durable funding draw posts"
call assertEq 100000000,acct~book~balance("1000","GBP")~netDebitMinor,"first draw cash balance"

/* Replay-only recovery deliberately has no current policy catalogue. */
replayEngine=.VMMAccountingStore~recoverReplayOnlyEngine(storePath)
replayAcct=.VMMAccountingService~new(v,replayEngine)
r2=replayAcct~postFundingDraw(d1,"2026-08-28","2026-08")
call assertEq "DUPLICATE",r2~status,"exact source replay survives restart before policy dispatch"
call assertEq r1~entry~entryId,r2~entry~entryId,"restart replay returns original immutable journal"
call assertEq r1~policyIdentity,r2~policyIdentity,"restart replay retains exact executable policy identity"

d1changed=.VMMFundingDraw~new("DRAW-DUR-1","FAC-DUR",1000001,"GBP","20260828T120000","LENDER-AUTH-1","OBL-DUR-1")
rConflict=replayAcct~postFundingDraw(d1changed,"2026-08-28","2026-08")
call assertEq "SOURCE_EVENT_CONFLICT",rConflict~errorCode,"changed economics under durable source identity conflicts before policy dispatch"

/* Full VMM recovery re-registers current policy for genuinely new events. */
eng2=.VMMAccountingStore~recoverEngine(storePath)
acct2=.VMMAccountingService~new(v,eng2)
d2=.VMMFundingDraw~new("DRAW-DUR-2","FAC-DUR",500000,"GBP","20260828T130000","LENDER-AUTH-2","OBL-DUR-2")
r3=acct2~postFundingDraw(d2,"2026-08-28","2026-08")
call assertEq "POSTED",r3~status,"new event posts after durable recovery and policy registration"
call assertEq 150000000,acct2~book~balance("1000","GBP")~netDebitMinor,"durable cash balance continues after restart"
call assertEq 150000000,acct2~book~balance("2100","GBP")~creditMinor,"durable arm-length borrowing balance continues after restart"
call assertEq "accounting.store/0.1",.VMMAccountingBuild~storeApi,"VMM exposes Accounting Core durable store API"
say "PASS test_accounting_v04_durable_funding_restart"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VMMAccountingPersistence.cls"

numeric digits 50
storePath="./tests/tmp_vmm_accounting_period_lifecycle_v010.jsonl"
eng=.VMMAccountingStore~createEngine(storePath,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
ev=.array~of("VMM-MONTH-END-RECON-2026-08")
.VMMAccountingPeriodControl~close(eng,"2026-08","VMM.FINANCE.CONTROLLER","MONTH_END_CLOSE",ev,"2026-09-01T00:05:00")
call assertEq "CLOSED",eng~book~period("2026-08")~state,"VMM close transitions period"

eng2=.VMMAccountingStore~recoverEngine(storePath)
call assertEq "CLOSED",eng2~book~period("2026-08")~state,"closed period survives accounting restart"
trs=eng2~book~periodTransitions
call assertEq 1,trs~items,"one durable close transition"
tr=trs[1]
call assertEq "VMM.FINANCE.CONTROLLER",tr~actorRef,"close actor survives restart"
call assertEq "MONTH_END_CLOSE",tr~reason,"close reason survives restart"
call assertEq "VMM-MONTH-END-RECON-2026-08",tr~evidenceRefs[1],"close evidence survives restart"
call assertEq "2026-09-01T00:05:00",tr~occurredAt,"close occurrence time survives restart"

.VMMAccountingPeriodControl~lock(eng2,"2026-08","VMM.FINANCE.CONTROLLER","STATUTORY_LOCK",.array~of("VMM-STATUTORY-SIGNOFF-2026-08"),"2026-09-03T10:00:00")
eng3=.VMMAccountingStore~recoverEngine(storePath)
call assertEq "LOCKED",eng3~book~period("2026-08")~state,"locked period survives second restart"
call assertEq 2,eng3~book~periodTransitions~items,"close and lock transition history survives restart"
call assertEq "accounting.integer-minor-unit.numeric-digits-50/0.1",eng3~book~arithmeticProfile,"recovered VMM book retains Accounting Core arithmetic profile"
say "PASS test_accounting_v04_period_lifecycle_restart"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VMMAccountingPersistence.cls"

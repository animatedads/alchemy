ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
billing=.AJITestSupport~actor("BILLING-JP",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)

first=rating~totalPremiumMinor%2
second=rating~totalPremiumMinor-first
schedule=.AllJapanInsurancePremiumSchedule~new("SCH-1",p~policyId,"2026-08-28T13:00:00",.array~of( -
  .AllJapanInsurancePremiumInstalment~new("INST-1",1,"2026-09-01",first,"JPY"), -
  .AllJapanInsurancePremiumInstalment~new("INST-2",2,"2026-10-01",second,"JPY")))
.AJITestSupport~must(tx~registerInitialSchedule(billing,schedule),"register initial instalment schedule")
.AJITestSupport~assert(schedule~totalMinor=rating~totalPremiumMinor,"instalments equal bound quote")
copy=schedule~instalments
copy~append(.AllJapanInsurancePremiumInstalment~new("MUTATION",99,"2026-11-01",1,"JPY"))
.AJITestSupport~assert(schedule~instalments~items=2 & schedule~totalMinor=rating~totalPremiumMinor,"schedule returns detached instalment collection")

failed=.AllJapanInsurancePremiumCollectionAttempt~new("ATT-FAIL",p~policyId,"INST-1",first,"JPY","2026-09-02T09:00:00","FAILED","","BANK:DECLINE:1","INSUFFICIENT_FUNDS")
.AJITestSupport~must(tx~recordCollectionAttempt(billing,failed),"record failed collection")
.AJITestSupport~assert(tx~collectedForInstalment("INST-1")=0,"failed collection does not settle instalment")
arrears=tx~arrearsAsOf(p~policyId,"2026-09-10")
.AJITestSupport~assert(arrears~items=1 & arrears[1]["outstandingMinor"]=first,"failed due instalment is arrears")

badEvidence=.AllJapanInsurancePremiumCollectionAttempt~new("ATT-BAD",p~policyId,"INST-1",1,"JPY","2026-09-03T09:00:00","COLLECTED","BANK-PAY-0","","")
bad=tx~recordCollectionAttempt(billing,badEvidence)
.AJITestSupport~assert(\bad~ok & bad~code="PREMIUM_COLLECTION_BANK_EVIDENCE_REQUIRED","successful collection requires bank evidence")

collected=.AllJapanInsurancePremiumCollectionAttempt~new("ATT-1",p~policyId,"INST-1",first,"JPY","2026-09-03T10:00:00","COLLECTED","BANK-PAY-1","BANK:EVIDENCE:1","")
.AJITestSupport~must(tx~recordCollectionAttempt(billing,collected),"record successful collection")
.AJITestSupport~assert(tx~outstandingForInstalment("INST-1")=0,"successful collection settles instalment")
.AJITestSupport~assert(tx~arrearsAsOf(p~policyId,"2026-09-10")~items=0,"settled instalment leaves arrears")
.AJITestSupport~assert(tx~arrearsAsOf(p~policyId,"2026-10-10")~items=1,"second unpaid instalment becomes arrears")

over=.AllJapanInsurancePremiumCollectionAttempt~new("ATT-OVER",p~policyId,"INST-1",1,"JPY","2026-09-04T10:00:00","COLLECTED","BANK-PAY-X","BANK:EVIDENCE:X","")
overResult=tx~recordCollectionAttempt(billing,over)
.AJITestSupport~assert(\overResult~ok & overResult~code="PREMIUM_COLLECTION_EXCEEDS_INSTALMENT","collection cannot over-settle instalment")

engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)
bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01"),"bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"recognise initial receivable")
failedEvent=adapter~premiumCollectionAttemptEvent("ATT-FAIL")
.AJITestSupport~assert(\failedEvent~ok & failedEvent~code="PREMIUM_COLLECTION_NO_ACCOUNTING_EFFECT","failed collection creates no journal event")
colEvent=.AJITestSupport~must(adapter~premiumCollectionAttemptEvent("ATT-1"),"successful collection event")~value
.AJITestSupport~assert(colEvent~value("paymentRef")="BANK-PAY-1" & colEvent~value("bankEvidenceRef")="BANK:EVIDENCE:1","bank attribution retained in accounting event")
.AJITestSupport~assert(engine~transact(colEvent)~ok,"successful attempt posts")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=second,"accounting receivable follows collection")

say "PASS premium instalments, failed collection, arrears and bank-attributed collection are explicit"
::requires "AccountingTestSupport.cls"

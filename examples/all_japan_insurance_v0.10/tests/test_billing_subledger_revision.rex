ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
billing=.AJITestSupport~actor("BILL-REV",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)

first=rating~totalPremiumMinor%3
second=rating~totalPremiumMinor-first
schedule=.AllJapanInsurancePremiumSchedule~new("SCH-REV",p~policyId,"2026-08-28T14:00:00",.array~of( -
  .AllJapanInsurancePremiumInstalment~new("REV-I1",1,"2026-09-01",first,"JPY"), -
  .AllJapanInsurancePremiumInstalment~new("REV-I2",2,"2026-12-01",second,"JPY")))
.AJITestSupport~must(tx~registerInitialSchedule(billing,schedule),"initial billing schedule")
.AJITestSupport~assert(tx~currentBillingScheduleRef(p~policyId)="INITIAL:SCH-REV","initial schedule has immutable version ref")

paid=.AllJapanInsurancePremiumCollectionAttempt~new("REV-PAY-1",p~policyId,"REV-I1",first,"JPY","2026-09-02T10:00:00","COLLECTED","BANK-REV-1","BANK:EVID:REV-1","")
.AJITestSupport~must(tx~recordCollectionAttempt(billing,paid),"settle first instalment")
.AJITestSupport~assert(tx~billingOpenDebitMinor("INSTALMENT:REV-I1")=0,"settled historic item stays closed")

revId="BILL-REVISION-1"
new1=second%2
new2=second-new1
items=.array~of( -
  .AllJapanInsuranceBillingItem~new("REV-N1",p~policyId,revId,revId,.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_REVISION,1,"2026-12-15",.AllJapanInsuranceTransactionBuild~BILLING_DEBIT,new1,"JPY","2026-10-15T09:00:00"), -
  .AllJapanInsuranceBillingItem~new("REV-N2",p~policyId,revId,revId,.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_REVISION,2,"2027-02-01",.AllJapanInsuranceTransactionBuild~BILLING_DEBIT,new2,"JPY","2026-10-15T09:00:00"))
revision=.AllJapanInsuranceBillingScheduleRevision~new(revId,p~policyId,"INITIAL:SCH-REV","2026-10-15","2026-10-15T09:00:00","CUSTOMER_RESCHEDULE",.array~of("INSTALMENT:REV-I2"),items)
r=.AJITestSupport~must(tx~recordBillingScheduleRevision(billing,revision),"replace open future instalment")
.AJITestSupport~assert(r~detail=.AllJapanInsuranceTransactionBuild~BILLING_REVISION_FUNCTION,"revision pins executable schedule-replacement identity")
.AJITestSupport~assert(tx~currentBillingScheduleRef(p~policyId)=revId,"revision advances current billing schedule ref")
.AJITestSupport~assert(tx~billingOpenDebitMinor("INSTALMENT:REV-I2")=0,"reversal closes exact replaced debit")
.AJITestSupport~assert(tx~billingOpenDebitMinor("REV-N1")+tx~billingOpenDebitMinor("REV-N2")=second,"replacement instalments preserve economic amount")

arrears=tx~billingArrearsAsOf(p~policyId,"2027-01-10")
.AJITestSupport~assert(arrears~items=1 & arrears[1]["billingItemId"]="REV-N1" & arrears[1]["outstandingMinor"]=new1,"arrears follows revised immutable billing items")

stale=.AllJapanInsuranceBillingScheduleRevision~new("BILL-REVISION-STALE",p~policyId,"INITIAL:SCH-REV","2026-11-01","2026-11-01T09:00:00","STALE",.array~of("REV-N2"),.array~of(.AllJapanInsuranceBillingItem~new("STALE-N",p~policyId,"BILL-REVISION-STALE","BILL-REVISION-STALE",.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_REVISION,1,"2027-02-01",.AllJapanInsuranceTransactionBuild~BILLING_DEBIT,new2,"JPY","2026-11-01T09:00:00")))
sr=tx~recordBillingScheduleRevision(billing,stale)
.AJITestSupport~assert(\sr~ok & sr~code="BILLING_REVISION_PREDECESSOR_STALE","schedule revisions cannot branch from stale billing state")

say "PASS billing subledger replaces only open future instalments, preserves amount and rejects stale schedule branches"
::requires "AccountingTestSupport.cls"

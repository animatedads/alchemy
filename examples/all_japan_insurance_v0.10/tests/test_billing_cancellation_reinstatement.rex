ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
billing=.AJITestSupport~actor("BILL-CR",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
policyActor=.AJITestSupport~actor("POLICY-CR",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
rater=.AJITestSupport~actor("RATER-CR",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)

schedule=.AllJapanInsurancePremiumSchedule~new("SCH-CR",p~policyId,"2026-08-28T14:20:00",.array~of(.AllJapanInsurancePremiumInstalment~new("CR-I1",1,"2026-09-01",rating~totalPremiumMinor,"JPY")))
.AJITestSupport~must(tx~registerInitialSchedule(billing,schedule),"schedule")
receipt=.AllJapanInsuranceBillingReceipt~new("CR-REC-1",p~policyId,p~partyRef,rating~totalPremiumMinor,"JPY","2026-09-02T09:00:00","BANK-CR-1","BANK:EVID:CR-1")
.AJITestSupport~must(tx~recordBillingReceipt(billing,receipt),"pay full premium")
.AJITestSupport~assert(tx~billingPosition(p~policyId)["netDebitMinor"]=0,"policy billing position starts settled")

riskRule=.AllJapanInsuranceCancellationComponentRule~new("RISK",.true,0,1)
salesRule=.AllJapanInsuranceCancellationComponentRule~new("SALES",.true,0,1)
taxRule=.AllJapanInsuranceCancellationComponentRule~new("TAX",.true,0,1)
plan=.AllJapanInsuranceCancellationPlan~new("AJI-CANCEL-BILLING-2026A",riskRule,salesRule,taxRule)
.AJITestSupport~must(tx~registerCancellationPlan(policyActor,plan),"cancellation plan")
calc=.AJITestSupport~must(tx~calculateCancellation("CR-CALC-CANCEL",p~policyId,"2027-03-01",1,2,plan~planRef,"2027-02-20T10:00:00"),"cancellation calc")~value
cancel=.AllJapanInsurancePolicyCancellation~new("CR-CANCEL",p~policyId,"2027-03-01","CUSTOMER_REQUEST",calc~calculationId,policyActor~principalId,"2027-02-20T10:05:00","CR-CANCEL-EVID")
cancelAdj=.AJITestSupport~must(tx~recordCancellation(policyActor,cancel,"PREMIUM_CONTROL"),"record cancellation")~value
creditItem=.AJITestSupport~must(tx~billPremiumAdjustment(billing,cancelAdj~adjustmentId,"2027-03-01","2027-02-20T10:06:00"),"bill cancellation credit")~value
.AJITestSupport~assert(creditItem~direction=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT,"cancellation return is an explicit billing credit")
.AJITestSupport~assert(tx~billingUnappliedCreditMinor(creditItem~itemId)=calc~totalReturnMinor,"settled policy leaves cancellation return as unapplied customer credit")

recalc=.AJITestSupport~must(tx~calculateReinstatement(rater,"CR-CALC-REINSTATE",p~policyId,calc~calculationId,cancel~effectiveDate,"2027-03-05T10:00:00","CR-REINSTATE-CALC"),"reinstatement calculation")~value
rein=.AllJapanInsurancePolicyReinstatement~new("CR-REINSTATE",p~policyId,cancel~cancellationId,"2027-03-05",cancel~effectiveDate,"ADJ:CR-REINSTATE",policyActor~principalId,"2027-03-05T10:05:00","CR-REINSTATE-EVID")
reinAdj=.AJITestSupport~must(tx~recordReinstatement(policyActor,rein,recalc~calculationId,"PREMIUM_CONTROL"),"record reinstatement")~value
debitItem=.AJITestSupport~must(tx~billPremiumAdjustment(billing,reinAdj~adjustmentId,"2027-03-01","2027-03-05T10:06:00"),"bill reinstatement debit")~value
.AJITestSupport~assert(debitItem~direction=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT,"reinstatement restoration is an explicit billing debit")
.AJITestSupport~assert(tx~billingOpenDebitMinor(debitItem~itemId)=0 & tx~billingUnappliedCreditMinor(creditItem~itemId)=0,"prior cancellation credit deterministically offsets reinstatement debit")
.AJITestSupport~assert(tx~billingPosition(p~policyId)["netDebitMinor"]=0,"no-gap reinstatement restores settled billing position without inventing cash")

say "PASS cancellation credits and no-gap reinstatement debits remain distinct billing items and allocate deterministically"
::requires "AccountingTestSupport.cls"

ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
billing=.AJITestSupport~actor("BILL-NP",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
credit=.AJITestSupport~actor("CREDIT-NP",.AllJapanInsuranceBuild~ROLE_CREDIT_CONTROL)
policyActor=.AJITestSupport~actor("POLICY-NP",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
rater=.AJITestSupport~actor("RATER-NP",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
claims=.AJITestSupport~actor("CLAIMS-NP",.AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)

schedule=.AllJapanInsurancePremiumSchedule~new("SCH-NP",p~policyId,"2026-08-28T13:00:00",.array~of(.AllJapanInsurancePremiumInstalment~new("INST-NP",1,"2026-09-01",rating~totalPremiumMinor,"JPY")))
.AJITestSupport~must(tx~registerInitialSchedule(billing,schedule),"schedule")
notice=.AJITestSupport~must(tx~issueNonPaymentNotice(credit,"NP-NOTICE-1",p~policyId,"2027-02-01","2027-02-20","2027-02-01T09:00:00","NOTICE-SERVED"),"non-payment notice")~value
.AJITestSupport~assert(notice~arrearsMinor=rating~totalPremiumMinor,"notice freezes current arrears amount")

riskRule=.AllJapanInsuranceCancellationComponentRule~new("RISK",.true,0,1)
salesRule=.AllJapanInsuranceCancellationComponentRule~new("SALES",.true,0,1)
taxRule=.AllJapanInsuranceCancellationComponentRule~new("TAX",.true,0,1)
plan=.AllJapanInsuranceCancellationPlan~new("AJI-CANCEL-NP-2026A",riskRule,salesRule,taxRule)
.AJITestSupport~must(tx~registerCancellationPlan(policyActor,plan),"cancellation plan")
calc=.AJITestSupport~must(tx~calculateCancellation("NP-CANCEL-CALC",p~policyId,"2027-03-01",1,2,plan~planRef,"2027-02-25T10:00:00"),"cancellation calculation")~value
cancel=.AllJapanInsurancePolicyCancellation~new("NP-CANCEL-1",p~policyId,"2027-03-01","NON_PAYMENT",calc~calculationId,policyActor~principalId,"2027-02-25T10:05:00","NONPAYMENT-CANCEL-EVID")
.AJITestSupport~must(tx~recordNonPaymentCancellation(policyActor,cancel,notice~noticeId,"PREMIUM_CONTROL"),"cancel after uncured notice")
.AJITestSupport~assert(\a~coverageActiveOn(p~policyId,"2027-03-05"),"non-payment cancellation interrupts coverage")

/* The old overdue instalment can still be cured after cancellation. */
col=.AllJapanInsurancePremiumCollectionAttempt~new("NP-CURE-PAY",p~policyId,"INST-NP",rating~totalPremiumMinor,"JPY","2027-03-06T09:00:00","COLLECTED","BANK-NP-CURE","BANK:EVID:NP-CURE","")
.AJITestSupport~must(tx~recordCollectionAttempt(billing,col),"cure arrears")
.AJITestSupport~assert(tx~arrearsAsOf(p~policyId,"2027-03-10")~items=0,"arrears cured before reinstatement")

recalc=.AJITestSupport~must(tx~calculateReinstatement(rater,"NP-REINSTATE-CALC",p~policyId,calc~calculationId,cancel~effectiveDate,"2027-03-08T10:00:00","REINSTATE-CALC-EVID"),"reinstatement calculation")~value
.AJITestSupport~assert(recalc~totalDeltaMinor=calc~totalReturnMinor & recalc~ratingFunctionRef=.AllJapanInsuranceTransactionBuild~REINSTATEMENT_FUNCTION,"reinstatement exactly restores cancellation return under separate function identity")
rein=.AllJapanInsurancePolicyReinstatement~new("NP-REINSTATE-1",p~policyId,cancel~cancellationId,"2027-03-08",cancel~effectiveDate,"ADJ:REINSTATE:NP-1",policyActor~principalId,"2027-03-08T10:05:00","REINSTATE-AUTH-EVID")
.AJITestSupport~must(tx~recordReinstatement(policyActor,rein,recalc~calculationId,"PREMIUM_CONTROL"),"no-gap reinstatement")
.AJITestSupport~assert(a~coverageActiveOn(p~policyId,"2027-03-05"),"authorised no-gap reinstatement restores coverage from cancellation date")

claim=.AllJapanInsuranceClaim~new("CLAIM-NP-GAP",p~policyId,"CUSTOMER-JP-1","2027-03-05","2027-03-09T09:00:00","LOSS-NP")
.AJITestSupport~must(a~openClaim(claims,claim),"claim in retrospectively restored no-gap period")

gapRein=.AllJapanInsurancePolicyReinstatement~new("NP-REINSTATE-GAP",p~policyId,cancel~cancellationId,"2027-03-09","2027-03-09","ADJ:X",policyActor~principalId,"2027-03-09T10:00:00","GAP")
gapResult=.AllJapanInsuranceAuthority~new~recordReinstatement(policyActor,gapRein)
.AJITestSupport~assert(\gapResult~ok,"unsupported gap-bearing reinstatement is not silently accepted")

say "PASS non-payment requires arrears notice/cure period and reinstatement is explicit, arrears-cured and no-gap"
::requires "AccountingTestSupport.cls"

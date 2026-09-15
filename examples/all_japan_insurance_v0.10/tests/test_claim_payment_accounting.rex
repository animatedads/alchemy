ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
ci=.AJITestSupport~actor("CLAIMS-INTAKE-PAY",.AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)
ca=.AJITestSupport~actor("CLAIMS-ASSESS-PAY",.AllJapanInsuranceBuild~ROLE_CLAIMS_ASSESSOR)
cp=.AJITestSupport~actor("CLAIMS-PAY",.AllJapanInsuranceBuild~ROLE_CLAIMS_PAYMENT)
claim=.AllJapanInsuranceClaim~new("C-PAY-1",p~policyId,"CUSTOMER-JP-1","2026-10-01","2026-10-02T09:00:00","LOSS-PAY-1")
.AJITestSupport~must(a~openClaim(ci,claim),"open payment claim")
ass1=.AJITestSupport~must(a~assessClaim(ca,"A-PAY-1",claim~claimId,80000,"2026-10-03T10:00:00","EVID-PAY-ASSESS-1"),"assess payment claim")~value
adapter=.AllJapanInsuranceAccountingAdapter~new(a)
engine=.AJIAccountingTestSupport~accountingEngine

/* Accounting may not accept a source-supplied prior reserve that disagrees
 * with the claim-specific posted book position. */
stale=.AJITestSupport~must(adapter~claimReserveChangedEvent(ass1~assessmentId,10000,"2026-10-03","CLAIM-PAY-CORR"),"build stale reserve event")~value
stalePost=engine~transact(stale)
.AJITestSupport~assert(\stalePost~ok & stalePost~errorCode="AJI_ACCOUNTING_CLAIM_OUTSTANDING_MISMATCH","stale claim reserve position rejected")

reserve1=.AJITestSupport~must(adapter~claimReserveChangedEvent(ass1~assessmentId,0,"2026-10-03","CLAIM-PAY-CORR"),"initial reserve event")~value
.AJITestSupport~assert(engine~transact(reserve1)~ok,"initial reserve posts")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(engine~book,claim~claimId)=80000,"claim-specific reserve established")

pay1=.AllJapanInsuranceClaimPayment~new("PAY-1",claim~claimId,p~policyId,ass1~assessmentId,"CUSTOMER-JP-1",30000,"JPY","2026-10-10T11:00:00","SETTLEMENT-REF-1","BANK-EVID-1")
.AJITestSupport~must(a~recordClaimPayment(cp,pay1),"record first claim payment")
payEvent1=.AJITestSupport~must(adapter~claimPaidEvent(pay1~paymentId,"2026-10-10","CLAIM-PAY-CORR"),"first payment accounting event")~value
.AJITestSupport~assert(payEvent1~value("reserveBeforeMinor")=80000 & payEvent1~value("reserveAfterMinor")=50000,"payment event consumes reserve")
.AJITestSupport~assert(engine~transact(payEvent1)~ok,"first claim payment posts")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(engine~book,claim~claimId)=50000,"claim outstanding falls after payment")
.AJITestSupport~assert(engine~book~balance("6100","JPY")~netDebitMinor=80000,"cash settlement does not rewrite incurred claim")
.AJITestSupport~assert(engine~book~balance("1000","JPY")~netDebitMinor=-30000,"claim payment credits AJI cash")

pay2=.AllJapanInsuranceClaimPayment~new("PAY-2",claim~claimId,p~policyId,ass1~assessmentId,"CUSTOMER-JP-1",20000,"JPY","2026-10-12T11:00:00","SETTLEMENT-REF-2","BANK-EVID-2")
.AJITestSupport~must(a~recordClaimPayment(cp,pay2),"record second claim payment")
payEvent2=.AJITestSupport~must(adapter~claimPaidEvent(pay2~paymentId,"2026-10-12","CLAIM-PAY-CORR"),"second payment accounting event")~value
.AJITestSupport~assert(engine~transact(payEvent2)~ok,"second claim payment posts")
.AJITestSupport~assert(a~claimPaidTotal(claim~claimId)=50000,"cumulative paid is operational truth")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(engine~book,claim~claimId)=30000,"second payment reduces claim outstanding")

over=.AllJapanInsuranceClaimPayment~new("PAY-OVER",claim~claimId,p~policyId,ass1~assessmentId,"CUSTOMER-JP-1",40000,"JPY","2026-10-13T11:00:00","SETTLEMENT-REF-OVER")
overResult=a~recordClaimPayment(cp,over)
.AJITestSupport~assert(\overResult~ok & overResult~code="CLAIM_PAYMENT_EXCEEDS_CURRENT_ASSESSMENT","payment cannot exceed current assessed payable")

/* A new assessment changes total incurred/payable. Paid cash remains retained,
 * so only the unpaid outstanding portion is re-reserved. */
ass2=.AJITestSupport~must(a~assessClaim(ca,"A-PAY-2",claim~claimId,50000,"2026-10-15T10:00:00","EVID-PAY-ASSESS-2"),"reassess claim to paid total")~value
reserve2=.AJITestSupport~must(adapter~claimReserveChangedEvent(ass2~assessmentId,30000,"2026-10-15","CLAIM-PAY-CORR"),"reserve release after reassessment")~value
.AJITestSupport~assert(reserve2~value("reserveAfterMinor")=0 & reserve2~value("paidToDateMinor")=50000,"reserve target excludes amounts already paid")
.AJITestSupport~assert(engine~transact(reserve2)~ok,"post reserve release after reassessment")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(engine~book,claim~claimId)=0,"fully paid assessed claim has zero outstanding")
.AJITestSupport~assert(engine~book~balance("6100","JPY")~netDebitMinor=50000,"incurred claim equals latest total payable")

belowPaid=a~assessClaim(ca,"A-PAY-3",claim~claimId,40000,"2026-10-16T10:00:00","EVID-PAY-ASSESS-3")
.AJITestSupport~assert(\belowPaid~ok & belowPaid~code="CLAIM_ASSESSMENT_BELOW_PAID_AMOUNT","assessment cannot rewrite history below cash already paid")

stalePayment=.AllJapanInsuranceClaimPayment~new("PAY-STALE",claim~claimId,p~policyId,ass1~assessmentId,"CUSTOMER-JP-1",1,"JPY","2026-10-17T11:00:00","SETTLEMENT-REF-STALE")
staleResult=a~recordClaimPayment(cp,stalePayment)
.AJITestSupport~assert(\staleResult~ok & staleResult~code="CLAIM_PAYMENT_ASSESSMENT_STALE","payment must reference current assessment")

say "PASS claim payments are authoritative, cumulative and reserve-aware in JPY accounting"
::requires "AccountingTestSupport.cls"

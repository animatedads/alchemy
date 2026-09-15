ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
q=ctx["quote"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
rater=.AJITestSupport~actor("RATING-JP",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY-TXN-JP",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)
bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01","","","PREMIUM_CONTROL"),"bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post bound premium")
initialReceivable=.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)
initialControl=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2200",p~policyId)
initialTax=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2220",p~policyId)

calc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-END-1",p~policyId,"ENDORSEMENT","2026-11-01",1000,100,50,1150,"JPY",q~ratingFunctionRef,"2026-10-25T10:00:00","RISK-CHANGE-EVID-1")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,calc),"record endorsement calculation")
adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-END-1",p~policyId,"ENDORSEMENT","2026-11-01",calc~calculationId,1000,100,50,1150,"JPY","PREMIUM_CONTROL","SUM_INSURED_CHANGE",policyActor~principalId,"2026-10-25T10:05:00","ENDORSEMENT-EVID-1")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,adj),"record calculation-backed endorsement")
ev=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"endorsement accounting event")~value
.AJITestSupport~assert(engine~transact(ev)~ok,"post additional premium")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=initialReceivable+1150,"additional premium increases receivable")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2200",p~policyId)=initialControl+1100,"risk plus sales premium control increases")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2220",p~policyId)=initialTax+50,"tax payable increases")

invented=.AllJapanInsurancePremiumAdjustment~new("ADJ-FAKE",p~policyId,"ENDORSEMENT","2026-12-01","NO-CALC",1,0,0,1,"JPY","PREMIUM_CONTROL","FAKE",policyActor~principalId,"2026-11-20T10:00:00","EVID")
fakeResult=tx~recordPremiumAdjustment(policyActor,invented)
.AJITestSupport~assert(\fakeResult~ok & fakeResult~code="PREMIUM_ADJUSTMENT_CALCULATION_NOT_FOUND","endorsement cannot invent calculation reference")

mismatchCalc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-END-2",p~policyId,"ENDORSEMENT","2026-12-01",-500,-50,-25,-575,"JPY",q~ratingFunctionRef,"2026-11-20T10:00:00","RISK-CHANGE-EVID-2")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,mismatchCalc),"record return calculation")
returnAdj=.AllJapanInsurancePremiumAdjustment~new("ADJ-END-2",p~policyId,"ENDORSEMENT","2026-12-01",mismatchCalc~calculationId,-500,-50,-25,-575,"JPY","PREMIUM_CONTROL","RISK_REDUCTION",policyActor~principalId,"2026-11-20T10:05:00","ENDORSEMENT-EVID-2")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,returnAdj),"record return premium endorsement")
retEvent=.AJITestSupport~must(adapter~premiumAdjustmentEvent(returnAdj~adjustmentId),"return premium accounting event")~value
.AJITestSupport~assert(engine~transact(retEvent)~ok,"post return premium adjustment")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=initialReceivable+575,"return premium reduces receivable by exact delta")

say "PASS endorsements require executable-rating calculation evidence and post signed premium deltas"
::requires "AccountingTestSupport.cls"

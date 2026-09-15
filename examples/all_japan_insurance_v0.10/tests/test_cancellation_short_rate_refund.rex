ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
policyActor=.AJITestSupport~actor("POLICY-TXN-JP",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
billing=.AJITestSupport~actor("BILLING-JP",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
claims=.AJITestSupport~actor("CLAIMS-IN-JP",.AllJapanInsuranceBuild~ROLE_CLAIMS_INTAKE)
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)

bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01","","","PREMIUM_CONTROL"),"bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post initial premium")
col=.AJITestSupport~must(adapter~premiumCollectedEvent("COLL-FULL",p~policyId,rating~totalPremiumMinor,"2026-09-02"),"full collection")~value
.AJITestSupport~assert(engine~transact(col)~ok,"collect initial premium")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=0,"initial receivable cleared before cancellation")

riskRule=.AllJapanInsuranceCancellationComponentRule~new("RISK",.true,1,10)
salesRule=.AllJapanInsuranceCancellationComponentRule~new("SALES",.true,0,1)
taxRule=.AllJapanInsuranceCancellationComponentRule~new("TAX",.true,0,1)
plan=.AllJapanInsuranceCancellationPlan~new("AJI-CANCEL-JP-2026A",riskRule,salesRule,taxRule)
.AJITestSupport~must(tx~registerCancellationPlan(policyActor,plan),"register immutable cancellation plan")
conflictPlan=.AllJapanInsuranceCancellationPlan~new("AJI-CANCEL-JP-2026A",.AllJapanInsuranceCancellationComponentRule~new("RISK",.true,0,1),salesRule,taxRule)
conflict=tx~registerCancellationPlan(policyActor,conflictPlan)
.AJITestSupport~assert(\conflict~ok & conflict~code="CANCELLATION_PLAN_IDENTITY_CONFLICT","cancellation plan reference is immutable")
position=.AJITestSupport~must(tx~currentWrittenComponents(p~policyId),"current written components")~value
calc=.AJITestSupport~must(tx~calculateCancellation("CANCEL-CALC-1",p~policyId,"2027-03-01",1,2,plan~planRef,"2027-02-20T10:00:00"),"calculate cancellation")~value
grossRisk=.AllJapanInsuranceTransactionMath~roundFraction(position["riskPremiumMinor"],2)
retained=.AllJapanInsuranceTransactionMath~roundFraction(grossRisk,10)
.AJITestSupport~assert(calc~riskReturnMinor=grossRisk-retained,"risk return applies explicit short-rate retention")
.AJITestSupport~assert(calc~shortRateRetainedMinor=retained,"short-rate charge retained separately")
.AJITestSupport~assert(calc~functionRef=.AllJapanInsuranceTransactionBuild~CANCELLATION_FUNCTION,"cancellation calculation pins executable function identity")
.AJITestSupport~assert(calc~totalReturnMinor>0,"cancellation produces return premium")

cancel=.AllJapanInsurancePolicyCancellation~new("CANCEL-1",p~policyId,"2027-03-01","CUSTOMER_REQUEST",calc~calculationId,policyActor~principalId,"2027-02-20T10:05:00","CANCEL-EVID-1")
adjResult=.AJITestSupport~must(tx~recordCancellation(policyActor,cancel,"PREMIUM_CONTROL"),"record policy cancellation")
adj=adjResult~value
.AJITestSupport~assert(adj~totalDeltaMinor=-calc~totalReturnMinor,"cancellation creates exact negative premium adjustment")
cancelEvent=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"cancellation accounting event")~value
.AJITestSupport~assert(engine~transact(cancelEvent)~ok,"post cancellation return premium")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=-calc~totalReturnMinor,"return premium becomes policyholder credit after cash was collected")

lateClaim=.AllJapanInsuranceClaim~new("C-AFTER-CANCEL",p~policyId,"CUSTOMER-JP-1","2027-03-01","2027-03-02T09:00:00","LOSS")
lateResult=a~openClaim(claims,lateClaim)
.AJITestSupport~assert(\lateResult~ok & lateResult~code="LOSS_AFTER_POLICY_CANCELLATION","cancellation ends coverage at effective date")

refund=.AllJapanInsurancePolicyholderRefund~new("REFUND-1",p~policyId,"CUSTOMER-JP-1",calc~totalReturnMinor,"JPY","2027-03-03T11:00:00","BANK-REFUND-1","BANK:EVIDENCE:REFUND-1")
.AJITestSupport~must(tx~recordPolicyholderRefund(billing,refund),"record policyholder refund")
refundEvent=.AJITestSupport~must(adapter~policyholderRefundPaidEvent(refund~refundId),"refund accounting event")~value
.AJITestSupport~assert(engine~transact(refundEvent)~ok,"pay return premium")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=0,"policyholder credit clears after refund")
.AJITestSupport~assert(engine~book~balance("1000","JPY")~netDebitMinor=rating~totalPremiumMinor-calc~totalReturnMinor,"cash retains earned plus short-rate premium")

say "PASS cancellation is calculation-backed, short-rate explicit, coverage-ending and refundable in JPY"
::requires "AccountingTestSupport.cls"

ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
q=ctx["quote"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
commissionActor=.AJITestSupport~actor("COMM-JP",.AllJapanInsuranceBuild~ROLE_COMMISSION_SETTLEMENT)
rater=.AJITestSupport~actor("RATING-JP",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY-TXN-JP",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)

bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01","","","COMMISSION_PAYABLE"),"commission-bearing bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post commission payable")
commissionDue=bound~value("salesCostMinor")
.AJITestSupport~assert(commissionDue>0,"test policy has producer commission")
settled=commissionDue%2
if settled=0 then settled=1

bad=.AllJapanInsuranceCommissionSettlement~new("COMM-BAD",p~policyId,"BROKER-JP-1",1,"JPY","2026-09-05T10:00:00","BANK-COMM-BAD","")
badResult=tx~recordCommissionSettlement(commissionActor,bad)
.AJITestSupport~assert(\badResult~ok & badResult~code="COMMISSION_SETTLEMENT_BANK_EVIDENCE_REQUIRED","commission payment requires bank evidence")

settlement=.AllJapanInsuranceCommissionSettlement~new("COMM-1",p~policyId,"BROKER-JP-1",settled,"JPY","2026-09-05T10:00:00","BANK-COMM-1","BANK:EVIDENCE:COMM-1")
.AJITestSupport~must(tx~recordCommissionSettlement(commissionActor,settlement),"record commission settlement")
ev=.AJITestSupport~must(adapter~commissionPaidEvent(settlement~settlementId),"commission accounting event")~value
.AJITestSupport~assert(engine~transact(ev)~ok,"pay commission")
remaining=commissionDue-settled
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2210",p~policyId)=remaining,"commission payable falls by bank-attributed payment")

over=.AllJapanInsuranceCommissionSettlement~new("COMM-OVER",p~policyId,"BROKER-JP-1",remaining+1,"JPY","2026-09-06T10:00:00","BANK-COMM-OVER","BANK:EVIDENCE:COMM-OVER")
.AJITestSupport~must(tx~recordCommissionSettlement(commissionActor,over),"record proposed over-settlement")
overEvent=.AJITestSupport~must(adapter~commissionPaidEvent(over~settlementId),"over-settlement event")~value
overPost=engine~transact(overEvent)
.AJITestSupport~assert(\overPost~ok & overPost~errorCode="AJI_ACCOUNTING_COMMISSION_PAYMENT_EXCEEDS_PAYABLE","accounting refuses payment above policy-specific payable")

/* Return commission greater than the still-unpaid payable requires an explicit
 * producer clawback/recovery policy; AJI does not manufacture a debit liability. */
reverse=remaining+1
calc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-COMM-REV",p~policyId,"ENDORSEMENT","2026-10-01",0,-reverse,0,-reverse,"JPY",q~ratingFunctionRef,"2026-09-20T10:00:00","COMMISSION-REVERSAL-CALC")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,calc),"record commission reversal calculation")
adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-COMM-REV",p~policyId,"ENDORSEMENT","2026-10-01",calc~calculationId,0,-reverse,0,-reverse,"JPY","COMMISSION_PAYABLE","RISK_REDUCTION",policyActor~principalId,"2026-09-20T10:05:00","COMMISSION-REVERSAL-EVID")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,adj),"record commission-bearing return endorsement")
adjEvent=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"commission reversal accounting event")~value
adjPost=engine~transact(adjEvent)
.AJITestSupport~assert(\adjPost~ok & adjPost~errorCode="AJI_ACCOUNTING_COMMISSION_CLAWBACK_REQUIRED","paid commission cannot be silently reversed through payable")

say "PASS commission settlement is bank-attributed and post-payment clawback fails closed"
::requires "AccountingTestSupport.cls"

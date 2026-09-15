ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
q=ctx["quote"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
commissionActor=.AJITestSupport~actor("COMM-REC",.AllJapanInsuranceBuild~ROLE_COMMISSION_SETTLEMENT)
rater=.AJITestSupport~actor("RATING-REC",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY-REC",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)

bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01","","","COMMISSION_PAYABLE"),"commission bound")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post commission payable")
commission=bound~value("salesCostMinor")
settlement=.AllJapanInsuranceCommissionSettlement~new("COMM-REC-PAID",p~policyId,"BROKER-JP-R",commission,"JPY","2026-09-05T10:00:00","BANK-COMM-PAID","BANK:EVID:COMM-PAID")
.AJITestSupport~must(tx~recordCommissionSettlement(commissionActor,settlement),"record full commission payment")
.AJITestSupport~assert(engine~transact(.AJITestSupport~must(adapter~commissionPaidEvent(settlement~settlementId),"commission pay event")~value)~ok,"pay full commission")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2210",p~policyId)=0,"commission payable exhausted")

calc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-COMM-CLAW",p~policyId,"ENDORSEMENT","2026-10-01",0,-commission,0,-commission,"JPY",q~ratingFunctionRef,"2026-09-20T10:00:00","CLAWBACK-CALC")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,calc),"clawback calc")
adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-COMM-CLAW",p~policyId,"ENDORSEMENT","2026-10-01",calc~calculationId,0,-commission,0,-commission,"JPY","COMMISSION_PAYABLE","RISK_REDUCTION",policyActor~principalId,"2026-09-20T10:05:00","CLAWBACK-ADJ")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,adj),"record return endorsement")
without=engine~transact(.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"unauthorised clawback event")~value)
.AJITestSupport~assert(\without~ok & without~errorCode="AJI_ACCOUNTING_COMMISSION_CLAWBACK_REQUIRED","paid commission still fails closed without explicit producer recovery")

recovery=.AllJapanInsuranceCommissionRecoveryAuthorization~new("COMM-RECOVERY-1",p~policyId,adj~adjustmentId,"BROKER-JP-R",commission,"JPY",commissionActor~principalId,"2026-09-20T10:10:00","PRODUCER-CLAWBACK-AUTH")
.AJITestSupport~must(tx~authorizeCommissionRecovery(commissionActor,recovery),"authorise producer recovery")
withAuth=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"authorised clawback event")~value
.AJITestSupport~assert(withAuth~value("commissionRecoveryRef")=recovery~recoveryId,"recovery authorization travels with accounting event")
.AJITestSupport~assert(engine~transact(withAuth)~ok,"post return premium with explicit producer recovery")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"2210",p~policyId)=commission,"commission control now carries explicit debit producer recovery")

receipt=.AllJapanInsuranceCommissionRecoveryReceipt~new("COMM-REC-RCPT-1",recovery~recoveryId,p~policyId,recovery~producerRef,commission,"JPY","2026-10-10T09:00:00","BANK-COMM-RECOVERED","BANK:EVID:COMM-RECOVERED")
.AJITestSupport~must(tx~recordCommissionRecoveryReceipt(commissionActor,receipt),"record producer repayment")
recv=.AJITestSupport~must(adapter~commissionRecoveryReceivedEvent(receipt~receiptId),"producer recovery accounting event")~value
.AJITestSupport~assert(engine~transact(recv)~ok,"receive producer recovery cash")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"2210",p~policyId)=0,"producer recovery control clears after cash receipt")

say "PASS paid producer commission is clawed back only through explicit authorised recovery and attributable cash receipt"
::requires "AccountingTestSupport.cls"

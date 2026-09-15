ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
q=ctx["quote"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
taxActor=.AJITestSupport~actor("TAX-JP",.AllJapanInsuranceBuild~ROLE_TAX_SETTLEMENT)
rater=.AJITestSupport~actor("RATING-TAX",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY-TAX",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)

bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01"),"bound")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post bound premium")
tax=bound~value("taxMinor")
.AJITestSupport~assert(tax>0,"fixture has premium tax")

remit=.AllJapanInsuranceTaxRemittance~new("TAX-REMIT-1",p~policyId,"JP-TAX-AUTHORITY",tax,"JPY","2026-09-30T10:00:00","BANK-TAX-REMIT","BANK:EVID:TAX-REMIT")
.AJITestSupport~must(tx~recordTaxRemittance(taxActor,remit),"record tax remittance")
remitEvent=.AJITestSupport~must(adapter~taxRemittedEvent(remit~remittanceId),"tax remittance event")~value
.AJITestSupport~assert(engine~transact(remitEvent)~ok,"remit premium tax")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(engine~book,"2220",p~policyId)=0,"tax payable cleared by remittance")

over=.AllJapanInsuranceTaxRemittance~new("TAX-REMIT-OVER",p~policyId,"JP-TAX-AUTHORITY",1,"JPY","2026-10-01T10:00:00","BANK-TAX-OVER","BANK:EVID:TAX-OVER")
.AJITestSupport~must(tx~recordTaxRemittance(taxActor,over),"record proposed over-remittance")
overPost=engine~transact(.AJITestSupport~must(adapter~taxRemittedEvent(over~remittanceId),"over-remit event")~value)
.AJITestSupport~assert(\overPost~ok & overPost~errorCode="AJI_ACCOUNTING_TAX_REMITTANCE_EXCEEDS_PAYABLE","cannot remit tax beyond posted policy tax liability")

calc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-TAX-REC",p~policyId,"ENDORSEMENT","2026-10-15",0,0,-tax,-tax,"JPY",q~ratingFunctionRef,"2026-10-10T09:00:00","TAX-RETURN-CALC")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,calc),"tax return calc")
adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-TAX-REC",p~policyId,"ENDORSEMENT","2026-10-15",calc~calculationId,0,0,-tax,-tax,"JPY","PREMIUM_CONTROL","RISK_REDUCTION",policyActor~principalId,"2026-10-10T09:05:00","TAX-RETURN-ADJ")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,adj),"record tax return adjustment")
without=engine~transact(.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"tax return no recovery")~value)
.AJITestSupport~assert(\without~ok & without~errorCode="AJI_ACCOUNTING_TAX_RECOVERY_POLICY_REQUIRED","remitted tax cannot be reversed without explicit recovery authority")

recovery=.AllJapanInsuranceTaxRecoveryAuthorization~new("TAX-RECOVERY-1",p~policyId,adj~adjustmentId,"JP-TAX-AUTHORITY",tax,"JPY",taxActor~principalId,"2026-10-10T09:10:00","TAX-RECOVERY-AUTH")
.AJITestSupport~must(tx~authorizeTaxRecovery(taxActor,recovery),"authorise tax recovery")
withAuth=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"tax recovery-backed adjustment")~value
.AJITestSupport~assert(withAuth~value("taxRecoveryRef")=recovery~recoveryId,"tax recovery authority travels with premium adjustment")
.AJITestSupport~assert(engine~transact(withAuth)~ok,"establish tax recovery while returning tax to policyholder control")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"2220",p~policyId)=tax,"tax settlement control carries explicit tax-authority receivable")

receipt=.AllJapanInsuranceTaxRecoveryReceipt~new("TAX-REC-RCPT-1",recovery~recoveryId,p~policyId,recovery~taxAuthorityRef,tax,"JPY","2026-11-01T10:00:00","BANK-TAX-REC","BANK:EVID:TAX-REC")
.AJITestSupport~must(tx~recordTaxRecoveryReceipt(taxActor,receipt),"record recovered tax cash")
recv=.AJITestSupport~must(adapter~taxRecoveryReceivedEvent(receipt~receiptId),"tax recovery receipt event")~value
.AJITestSupport~assert(engine~transact(recv)~ok,"receive tax recovery")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"2220",p~policyId)=0,"tax recovery control clears on cash receipt")

say "PASS premium tax remittance and post-remittance recovery are explicit, authority-gated and bank-attributed"
::requires "AccountingTestSupport.cls"

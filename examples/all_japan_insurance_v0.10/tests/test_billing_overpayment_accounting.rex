ctx=.AJIAccountingTestSupport~ratedHomeContext
a=ctx["authority"]
p=ctx["policy"]
q=ctx["quote"]
rating=ctx["rating"]
tx=.AllJapanInsuranceTransactionAuthority~new(a)
billing=.AJITestSupport~actor("BILL-OVER",.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
rater=.AJITestSupport~actor("RATER-OVER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
policyActor=.AJITestSupport~actor("POLICY-OVER",.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)

schedule=.AllJapanInsurancePremiumSchedule~new("SCH-OVER",p~policyId,"2026-08-28T14:10:00",.array~of(.AllJapanInsurancePremiumInstalment~new("OVER-I1",1,"2026-09-01",rating~totalPremiumMinor,"JPY")))
.AJITestSupport~must(tx~registerInitialSchedule(billing,schedule),"initial schedule")

engine=.AJIAccountingTestSupport~accountingEngine
adapter=.AllJapanInsuranceAccountingAdapter~new(a,tx)
bound=.AJITestSupport~must(adapter~policyBoundEvent(p~policyId,"2026-09-01"),"bound event")~value
.AJITestSupport~assert(engine~transact(bound)~ok,"post initial receivable")

overpay=500
receipt=.AllJapanInsuranceBillingReceipt~new("BILL-REC-OVER",p~policyId,p~partyRef,rating~totalPremiumMinor+overpay,"JPY","2026-09-02T10:00:00","BANK-OVERPAY-1","BANK:EVID:OVERPAY-1")
.AJITestSupport~must(tx~recordBillingReceipt(billing,receipt),"record bank-attributed overpayment")
pos=tx~billingPosition(p~policyId)
.AJITestSupport~assert(pos["openDebitMinor"]=0 & pos["unappliedCashMinor"]=overpay & pos["netDebitMinor"]=-overpay,"receipt allocates oldest due debit and leaves explicit unapplied cash")
ev=.AJITestSupport~must(adapter~billingReceiptEvent(receipt~receiptId),"billing receipt accounting event")~value
.AJITestSupport~assert(ev~value("appliedAtReceiptMinor")=rating~totalPremiumMinor & ev~value("unappliedAtReceiptMinor")=overpay,"receipt freezes allocation snapshot at receipt time")
first=engine~transact(ev)
.AJITestSupport~assert(first~ok & first~status="POSTED","overpayment cash posts")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=-overpay,"overpayment is explicit customer credit in policy control account")

calc=.AllJapanInsurancePremiumAdjustmentCalculation~new("CALC-OVER-ADD",p~policyId,"ENDORSEMENT","2026-10-01",300,0,0,300,"JPY",q~ratingFunctionRef,"2026-09-25T10:00:00","ADDITIONAL-RISK")
.AJITestSupport~must(tx~recordAdjustmentCalculation(rater,calc),"additional premium calculation")
adj=.AllJapanInsurancePremiumAdjustment~new("ADJ-OVER-ADD",p~policyId,"ENDORSEMENT","2026-10-01",calc~calculationId,300,0,0,300,"JPY","PREMIUM_CONTROL","RISK_INCREASE",policyActor~principalId,"2026-09-25T10:05:00","ADJ-EVID")
.AJITestSupport~must(tx~recordPremiumAdjustment(policyActor,adj),"additional premium adjustment")
adjEvent=.AJITestSupport~must(adapter~premiumAdjustmentEvent(adj~adjustmentId),"premium adjustment event")~value
.AJITestSupport~assert(engine~transact(adjEvent)~ok,"additional premium posts")
.AJITestSupport~must(tx~billPremiumAdjustment(billing,adj~adjustmentId,"2026-10-01","2026-09-25T10:06:00"),"bill additional premium")
pos2=tx~billingPosition(p~policyId)
.AJITestSupport~assert(pos2["openDebitMinor"]=0 & pos2["unappliedCashMinor"]=200,"historic unapplied cash auto-allocates to later debit before new arrears arise")

again=.AJITestSupport~must(adapter~billingReceiptEvent(receipt~receiptId),"rebuild immutable receipt event")~value
.AJITestSupport~assert(again~value("appliedAtReceiptMinor")=rating~totalPremiumMinor & again~value("unappliedAtReceiptMinor")=overpay,"later allocations do not rewrite receipt-time allocation evidence")
replay=engine~transact(again)
.AJITestSupport~assert(replay~ok & replay~status="DUPLICATE","receipt event remains replay-stable after later allocations")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(engine~book,"1100",p~policyId)=-200,"GL customer credit agrees with remaining unapplied cash after additional premium")

say "PASS overpayments become explicit unapplied cash, later auto-allocate, and accounting replay remains receipt-time stable"
::requires "AccountingTestSupport.cls"

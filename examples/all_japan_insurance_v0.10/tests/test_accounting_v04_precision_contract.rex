engine=.AJIAccountingTestSupport~accountingEngine
policy=engine~policies~policyByIdentity(.AllJapanInsuranceAccountingBuild~POLICY_BOUND_IDENTITY)
payPolicy=engine~policies~policyByIdentity(.AllJapanInsuranceAccountingBuild~CLAIM_PAID_IDENTITY)
.AJITestSupport~assert(policy~class~package~digits>=50,"AJI accounting policy package declares NUMERIC DIGITS 50")
.AJITestSupport~assert(payPolicy~class~package~digits>=50,"claim payment policy package declares NUMERIC DIGITS 50")
.AJITestSupport~assert(.AllJapanInsuranceAuthority~new~class~package~digits>=50,"AJI operational authority compiles with 50-digit arithmetic")

huge="1234567890123456789012345678901234567890"
payload=.directory~new
payload["currency"]="JPY"
payload["reserveBeforeMinor"]="0"
payload["reserveDeltaMinor"]=huge
payload["reserveAfterMinor"]=huge
payload["paidToDateMinor"]="0"
payload["claimId"]="C-HUGE-JPY"
payload["assessmentId"]="A-HUGE-JPY"
event=.AccountingEvent~new("AJI:CLAIM_RESERVE:A-HUGE-JPY",.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_CLAIM_RESERVE_CHANGED,"2026-08-28","AJI-HUGE-JPY","","ALL_JAPAN.CLAIMS.AUTHORITY",payload,.array~of("EVID-HUGE-JPY"))
posted=engine~transact(event)
.AJITestSupport~assert(posted~ok,"40-digit whole-yen reserve posts through AJI policy")
.AJITestSupport~assert(engine~book~balance("2230","JPY")~creditMinor~string=huge,"40-digit JPY liability remains exact")
.AJITestSupport~assert(.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(engine~book,"C-HUGE-JPY")~string=huge,"claim-specific 40-digit JPY amount remains exact")
say "PASS AJI and Accounting Core v0.7 retain the v0.4 exact 50-digit whole-yen arithmetic contract"
::requires "AccountingTestSupport.cls"

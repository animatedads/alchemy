t=.MBAccountingTest~new
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
refs=.array~of("MB-MARK-1","MB-TRADE-T100")
e=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EV-1","FEDERATIONBANK_MERCHANT_BANK","MB:FV:T100:1","2026-08-28","2026-08","T100","PF-100","T100","USD",2500,"ASSET","INCREASE","MERCHANT_VALUATION","","MM-X","EXTERNAL_HEDGE",refs)
r1=adapter~postDerivativeFairValueMovement(e)
t~assertEq("POSTED",r1~status,"authoritative Merchant evidence posts")
r2=adapter~postDerivativeFairValueMovement(e)
t~assertEq("DUPLICATE",r2~status,"same Merchant source event is idempotent")
changed=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EV-1B","FEDERATIONBANK_MERCHANT_BANK","MB:FV:T100:1","2026-08-28","2026-08","T100","PF-100","T100","USD",2600,"ASSET","INCREASE","MERCHANT_VALUATION","","MM-X","EXTERNAL_HEDGE",refs)
r3=adapter~postDerivativeFairValueMovement(changed)
t~assertEq("SOURCE_EVENT_CONFLICT",r3~errorCode,"changed economic reuse of source event is rejected")
foreign=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EV-VMM","VECTOR_MERIDIAN_MARKETS_LTD","VMM:FV:1","2026-08-28","2026-08","V1","VP1","V1","USD",1,"ASSET","INCREASE","VMM_VALUATION")
r4=adapter~postDerivativeFairValueMovement(foreign)
t~assertEq("MERCHANT_ENTITY_MISMATCH",r4~errorCode,"external company cannot post into Merchant book")
t~assertEq(1,adapter~book~entryCount,"rejected/duplicate evidence does not create extra journals")
t~assertEq("federationbank.merchant.accounting.derivative_fair_value/0.2",r1~entry~policyRef,"posting is bound to Merchant accounting policy")
t~assertEq("MERCHANT_VALUATION",r1~entry~lines[1]~dimensions["sourceAuthority"],"Merchant source authority retained")
t~assertEq("MM-X",r1~entry~lines[1]~dimensions["counterpartyEntity"],"counterparty evidence retained")

say "posting boundary assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"

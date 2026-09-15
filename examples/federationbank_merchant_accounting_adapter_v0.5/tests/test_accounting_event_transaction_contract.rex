t=.MBAccountingTest~new
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
refs=.array~of("MERCHANT:MARK:EV1","MERCHANT:VALUATION:VAL1")
e=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EVENT-1","FEDERATIONBANK_MERCHANT_BANK","MB:FV:EVENT:1","2026-08-28","2026-08","T-EVENT","PF-EVENT","ROOT-EVENT","GBP",1250,"ASSET","INCREASE","FEDERATIONBANK_MERCHANT_BANK:VALUATION","","MM-EVENT","EXTERNAL_HEDGE",refs)
event=adapter~accountingEventForDerivativeFairValueMovement(e)
t~assertTrue(event~isA(.AccountingEvent),"Merchant evidence becomes AccountingEvent")
t~assertEq("MERCHANT_DERIVATIVE_FAIR_VALUE_MOVEMENT",event~eventType,"stable Merchant accounting event type")
t~assertEq("ROOT-EVENT",event~correlationRef,"economic root becomes cross-event correlation")
t~assertEq("MM-EVENT",event~counterpartyEntityId,"counterparty bound at AccountingEvent boundary")
t~assertEq("FEDERATIONBANK_MERCHANT_BANK:VALUATION",event~sourceAuthorityRef,"Merchant valuation authority bound at AccountingEvent boundary")
projection=adapter~accountingEventProjectionForDerivativeFairValueMovement(e)
t~assertEq("accounting.event/0.1",projection["contract_generation"],"normalized Accounting Core event contract used")
t~assertEq("1250",projection["payload"]["amountMinor"]~string,"minor units survive scalar event projection")
fp=event~fingerprint
projection["payload"]["amountMinor"]="999999"
t~assertEq(fp,event~fingerprint,"event payload is detached from transport projection mutation")
r=adapter~postDerivativeFairValueMovement(e)
t~assertEq("POSTED",r~status,"AccountingEvent transacts through executable Merchant policy")
t~assertEq(.FederationBankMerchantAccountingBuild~FAIR_VALUE_POLICY,r~policyRef,"transaction reports semantic policy ref")
expectedIdentity=.FederationBankMerchantAccountingBuild~POLICY_ARTIFACT_IDENTITY || "#MBAccountingDerivativeFairValueMovementPolicy"
t~assertEq(expectedIdentity,r~policyIdentity,"transaction reports exact release-scoped executable policy identity")
t~assertEq(expectedIdentity,r~entry~policyIdentity,"journal retains exact executable policy identity")
t~assertEq(event~fingerprint,r~entry~sourceEventFingerprint,"journal retains source AccountingEvent fingerprint")
t~assertEq(event~eventType,r~entry~eventType,"journal retains normalized Merchant event type")
t~assertEq("FEDERATIONBANK_MERCHANT_BANK:VALUATION",r~entry~metadata["accounting.sourceAuthorityRef"],"Core stamps source authority on immutable journal")
say "accounting event transaction assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"

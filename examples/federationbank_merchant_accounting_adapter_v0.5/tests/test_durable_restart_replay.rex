t=.MBAccountingTest~new
storePath="./tests/tmp_merchant_accounting_v03.jsonl"
adapter=.FederationBankMerchantAccountingAdapter~createDurable(storePath)
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
refs=.array~of("MERCHANT:MARK:D1","MERCHANT:VALUATION:D1")
e=.MBAccountingDerivativeFairValueMovementEvidence~new("DURABLE-EV-1","FEDERATIONBANK_MERCHANT_BANK","MB:FV:DURABLE:1","2026-08-28","2026-08","T-DUR","PF-DUR","ROOT-DUR","GBP",7777,"ASSET","INCREASE","FEDERATIONBANK_MERCHANT_BANK:VALUATION","","MM-DUR","EXTERNAL_HEDGE",refs)
event=adapter~accountingEventForDerivativeFairValueMovement(e)
first=adapter~postDerivativeFairValueMovement(e)
t~assertEq("POSTED",first~status,"durable Merchant accounting event posts")
entryId=first~entry~entryId
identity=first~entry~policyIdentity

store=.AccountingFileStore~new(storePath)
recoveredBook=store~recoverBook
t~assertEq(1,recoveredBook~entryCount,"Merchant accounting journal survives restart")
t~assertEq(7777,recoveredBook~balance("1300","GBP")~netDebitMinor,"Merchant derivative balance survives restart exactly")

/* Deliberately use an engine with no Merchant policy registered. Historical
 * replay must be resolved from recovered source-event identity first. */
bare=.AccountingEngine~new(recoveredBook~legalEntityId,recoveredBook~bookId,recoveredBook~reportingBasis,recoveredBook)
replay=bare~transact(event)
t~assertEq("DUPLICATE",replay~status,"historical Merchant event replay does not redispatch policy")
t~assertEq(entryId,replay~entry~entryId,"replay returns original immutable journal")
t~assertEq(identity,replay~policyIdentity,"replay returns original executable policy identity")
changedPayload=event~payload
changedPayload["amountMinor"]="8888"
changed=.AccountingEvent~new(event~sourceEventRef,event~legalEntityId,event~eventType,event~eventDate,event~correlationRef,event~counterpartyEntityId,event~sourceAuthorityRef,changedPayload,event~evidenceRefs,event~metadata)
conflict=bare~transact(changed)
t~assertEq("SOURCE_EVENT_CONFLICT",conflict~errorCode,"changed historical Merchant event conflicts before policy lookup")
newEvent=.AccountingEvent~new("MB:FV:DURABLE:2",event~legalEntityId,event~eventType,event~eventDate,"ROOT-DUR-2","MM-DUR",event~sourceAuthorityRef,event~payload,event~evidenceRefs,event~metadata)
missing=bare~transact(newEvent)
t~assertEq("POLICY_NOT_FOUND",missing~errorCode,"genuinely new event still needs current executable Merchant policy")

restored=.FederationBankMerchantAccountingAdapter~recoverDurable(storePath)
t~assertEq(1,restored~book~entryCount,"Merchant adapter can recover its durable independent book")
t~assertEq(.FederationBankMerchantAccountingBuild~POLICY_ARTIFACT_IDENTITY || "#MBAccountingDerivativeFairValueMovementPolicy",restored~engine~policies~policyByIdentity(.FederationBankMerchantAccountingBuild~POLICY_ARTIFACT_IDENTITY || "#MBAccountingDerivativeFairValueMovementPolicy")~policyIdentity,"recovered adapter registers current Merchant accounting policy for new events")
say "durable restart assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"

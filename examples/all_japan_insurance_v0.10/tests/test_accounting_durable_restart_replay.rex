ctx=.AJIAccountingTestSupport~ratedHomeContext
adapter=.AllJapanInsuranceAccountingAdapter~new(ctx["authority"])
event=.AJITestSupport~must(adapter~policyBoundEvent(ctx["policy"]~policyId,"2026-09-01","AJI-DURABLE-CORR"),"durable policy-bound event")~value
storePath="./tests/tmp_aji_accounting_v08.jsonl"
engine=.AllJapanInsuranceAccountingFactory~createDurable(storePath,"2026-2027","2026-01-01","2027-12-31")
first=engine~transact(event)
.AJITestSupport~assert(first~ok & first~status="POSTED","durable AJI event posts")
entryId=first~entry~entryId
identity=first~entry~policyIdentity

store=.AccountingFileStore~new(storePath)
book=store~recoverBook
.AJITestSupport~assert(book~entryCount=1,"AJI journal survives durable restart")
.AJITestSupport~assert(book~balance("1100","JPY")~netDebitMinor=ctx["rating"]~totalPremiumMinor,"JPY balance survives durable restart")

/* Replay must resolve from persisted source identity before any current
 * executable policy is consulted. */
bare=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
replay=bare~transact(event)
.AJITestSupport~assert(replay~ok & replay~status="DUPLICATE","historical AJI replay does not redispatch current policy")
.AJITestSupport~assert(replay~entry~entryId=entryId & replay~policyIdentity=identity,"durable replay returns original executable identity")
changedPayload=event~payload
changedPayload["totalPremiumMinor"]=changedPayload["totalPremiumMinor"]+1
changed=.AccountingEvent~new(event~sourceEventRef,event~legalEntityId,event~eventType,event~eventDate,event~correlationRef,event~counterpartyEntityId,event~sourceAuthorityRef,changedPayload,event~evidenceRefs,event~metadata)
conflict=bare~transact(changed)
.AJITestSupport~assert(\conflict~ok & conflict~errorCode="SOURCE_EVENT_CONFLICT","changed historical AJI event conflicts before policy lookup")
newEvent=.AccountingEvent~new("AJI:POLICY_BOUND:NEW-AFTER-RESTART",event~legalEntityId,event~eventType,event~eventDate,"AJI-DURABLE-NEW",event~counterpartyEntityId,event~sourceAuthorityRef,event~payload,event~evidenceRefs,event~metadata)
missing=bare~transact(newEvent)
.AJITestSupport~assert(\missing~ok & missing~errorCode="POLICY_NOT_FOUND","genuinely new event still requires current AJI policy")

restored=.AllJapanInsuranceAccountingFactory~recoverDurable(storePath)
.AJITestSupport~assert(restored~book~entryCount=1,"AJI accounting factory recovers its independent book")
.AJITestSupport~assert(restored~policies~policyByIdentity(.AllJapanInsuranceAccountingBuild~POLICY_BOUND_IDENTITY)\==.nil,"recovered AJI engine registers current accounting policies")
say "PASS AJI Accounting Core v0.7 retains durable restart, replay and policy identity"
::requires "AccountingTestSupport.cls"

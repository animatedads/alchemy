ctx=.AJIAccountingTestSupport~ratedHomeContext
adapter=.AllJapanInsuranceAccountingAdapter~new(ctx["authority"])
event=.AJITestSupport~must(adapter~policyBoundEvent(ctx["policy"]~policyId,"2026-09-01","CORR-REPLAY"),"accounting event")~value
engine=.AJIAccountingTestSupport~accountingEngine
first=engine~transact(event)
.AJITestSupport~assert(first~ok & first~status="POSTED","first event posts")
second=engine~transact(event)
.AJITestSupport~assert(second~ok & second~status="DUPLICATE","exact replay returns immutable journal")
.AJITestSupport~assert(second~entry~entryId=first~entry~entryId,"replay returns original entry")
p=event~payload
p["totalPremiumMinor"]=p["totalPremiumMinor"]+1
changed=.AccountingEvent~new(event~sourceEventRef,event~legalEntityId,event~eventType,event~eventDate,event~correlationRef,event~counterpartyEntityId,event~sourceAuthorityRef,p,event~evidenceRefs,event~metadata)
conflict=engine~transact(changed)
.AJITestSupport~assert(\conflict~ok & conflict~errorCode="SOURCE_EVENT_CONFLICT","changed replay rejected before policy rerun")
say "PASS AJI accounting uses Accounting Core replay-before-policy identity"
::requires "AccountingTestSupport.cls"

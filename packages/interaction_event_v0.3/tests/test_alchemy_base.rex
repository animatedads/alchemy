ring=.CryptoMacKeyRing~new
ring~addKey("interaction-alchemy", "00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring)
authority=.AlchemyCapabilityAuthority~new(ring)

content=.InteractionContentElement~new("c1","CUSTOMER_NAME","Barbie Secret",.InteractionConstant~PRIVACY_CUSTOMER_SPECIFIC,"[CUSTOMER_RELATED_PERSON]",.InteractionConstant~ABSTRACT_ONLY,.InteractionConstant~ORIGIN_CUSTOMER,"prompt/person/1","12:25",100,.nil,sealer,authority)
event=.InteractionEvent~new("evt-alchemy","AGENT_UTTERANCE",.nil,"CHAT","CHAT/REPLY","OUTBOUND",.nil,.nil,.nil,sealer,authority)
call assertTrue event~isA(.AlchemyObject), "event inherits AlchemyObject"
call assertTrue content~isA(.AlchemyObject), "content inherits AlchemyObject"
call assertTrue event~addContent(content), "content attached"
call assertTrue event~addTag("SALESPROP"), "tag attached"
event~seal

assessment=.InteractionAssessment~new("a1",event~eventId,.InteractionConstant~ASSESS_STYLE,"PROFILE","MODEL","tone-assessor","tone-v7",93,.nil,sealer,authority)
call assertTrue assessment~addDimension("SASS",81), "sass dimension"
assessment~seal
link=.InteractionLink~new("l1",event~eventId,event~eventId,.InteractionConstant~LINK_CANDIDATE_TRIGGER,50,.InteractionConstant~CAUSAL_CANDIDATE,"effect-engine",.nil,.nil,sealer,authority)
call assertTrue link~isA(.AlchemyObject), "link inherits AlchemyObject"

lib=.InteractionCaptureLibrary~new(sealer,authority)
call assertTrue lib~isA(.AlchemyObject), "capture library inherits AlchemyObject"
call assertTrue lib~captureEvent(event)~ok, "event captured"
call assertTrue lib~attachAssessment(assessment)~ok, "assessment attached"

pub=event~sealPublicIntrospection
call assertTrue sealer~verify(pub), "public event introspection verifies"
call assertFalse pub~payload~hasIndex("state"), "public profile contains no state values"
call assertFalse hasNamedRecord(pub~payload["state_description"],"CONTENT"), "public state description hides content slot"

cap=authority~issue("tenant",event~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:CUSTOMER")
customer=event~sealedIntrospection("CUSTOMER",cap)
call assertTrue sealer~verify(customer), "customer event introspection verifies"
state=customer~payload["state"]
call assertEqual "evt-alchemy",state["EVENTID"],"customer profile keeps event id"
call assertEqual "AGENT_UTTERANCE",state["EVENTKIND"],"customer profile keeps semantic event kind"
call assertFalse state~hasIndex("CONTENT"), "customer profile hides raw content collection"
call assertFalse state~hasIndex("ACTORREF"), "customer profile hides actor reference"

cap2=authority~issue("auditor",lib~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:INTERNAL")
internal=lib~sealedIntrospection("INTERNAL",cap2)
call assertTrue internal~payload["instrumentation_event_count"] >= 2, "capture operations leave instrumentation evidence"
call assertTrue internal~payload["relationships"]~items >= 2, "capture relationships are detached evidence"

say "PASS test_alchemy_base"
exit 0

hasNamedRecord: procedure
  use strict arg records,wanted
  wanted=wanted~string~translate
  do rec over records
    n=rec~at("name")
    if n \== .nil then if n~string~translate=wanted then return .true
  end
  return .false
assertTrue: procedure
  use arg x,msg
  if x \== .true then raise syntax 88.900 array("assertTrue failed: "||msg)
  return
assertFalse: procedure
  use arg x,msg
  if x \== .false then raise syntax 88.900 array("assertFalse failed: "||msg)
  return
assertEqual: procedure
  use arg e,a,msg
  if e \== a then raise syntax 88.900 array("assertEqual failed: "||msg||" expected="||e||" actual="||a)
  return
::requires "InteractionEvent.cls"

ring=.CryptoMacKeyRing~new; ring~addKey("journey-alchemy","00112233445566778899aabbccddeeff")
sealer=.AlchemyMacSealer~new(ring); authority=.AlchemyCapabilityAuthority~new(ring)
j=.BrandJourney~new("safe-j1","Barbie Example / account 123 / 12 Private Road","CUSTOMER_RELATIONSHIP",sealer,authority)
t=.BrandJourneyTouchpoint~new("t1","SUPPORT","EVENT:1","CHAT",.nil,"OPEN","RESOLVED",.true,.false,.false,sealer,authority); t~addBrandFunction("PROMOTIONAL_WORK"); t~seal; j~addTouchpoint(t); j~seal
call assertTrue j~isA(.AlchemyObject),"journey inherits AlchemyObject"
cap=authority~issue("tenant",j~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:CUSTOMER")
env=j~sealedIntrospection("CUSTOMER",cap); call assertTrue sealer~verify(env),"customer introspection verifies"
state=env~payload["state"]
call assertFalse state~hasIndex("RELATIONSHIPREF"),"customer-specific correlation hidden"
call assertEqual "safe-j1",state["JOURNEYID"],"safe journey id visible"
text=j~canonicalText
call assertEqual 0,pos("Barbie",text),"canonical residue contains no customer identity"
call assertEqual 0,pos("Private Road",text),"canonical residue contains no address"
cap2=authority~issue("auditor",j~alchemyObjectId,"SEALEDINTROSPECTION","INTROSPECT:INTERNAL")
internal=j~sealedIntrospection("INTERNAL",cap2)
call assertFalse internal~payload["state"]~hasIndex("RELATIONSHIPREF"),"SECRET remains hidden from INTERNAL"
call assertTrue internal~payload["instrumentation_event_count"]>=2,"journey operations instrumented"
call assertTrue internal~payload["relationships"]~items>=1,"detached relationship evidence"
say "PASS test_alchemy_privacy"
exit 0
assertTrue: procedure; use arg x,m; if x \== .true then raise syntax 88.900 array(m); return
assertFalse: procedure; use arg x,m; if x \== .false then raise syntax 88.900 array(m); return
assertEqual: procedure; use arg e,a,m; if e \== a then raise syntax 88.900 array(m||" expected="||e||" actual="||a); return
::requires "BrandJourney.cls"
::requires "AlchemySecurity.cls"

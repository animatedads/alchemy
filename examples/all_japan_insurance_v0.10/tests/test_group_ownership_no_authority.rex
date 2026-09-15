a=.AllJapanInsuranceAuthority~new
owner=.AllJapanInsuranceActor~new("FEDERATION",.array~new)
s=.AllJapanInsuranceRiskSubmission~new("S1","HOME","REL-1","HOUSE-1","JP","2026-08-28")
r=a~submitRisk(owner,s)
ignored=.AJITestSupport~assert(\r~ok,"owner without role denied")
ignored=.AJITestSupport~assert(r~code="AUTHORITY_DENIED","ownership is not authority")
say "PASS group ownership does not inherit insurance authority"
::requires "TestSupport.cls"

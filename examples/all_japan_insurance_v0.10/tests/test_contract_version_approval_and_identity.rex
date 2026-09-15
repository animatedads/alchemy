rule=.AJITestSupport~payoutRule("RULE")
unapproved=.AllJapanInsuranceContractVersion~new("AJI-HOME-JP/X","HOME","JP","2026-01-01","","WORDING-X",rule,"","","")
book=.AllJapanInsuranceContractBook~new
r=book~addVersion(unapproved)
ignored=.AJITestSupport~assert(\r~ok,"unapproved release rejected")
ignored=.AJITestSupport~assert(r~code="CONTRACT_VERSION_APPROVAL_REQUIRED","approval evidence required")
v=.AJITestSupport~contractVersion("AJI-HOME-JP/1","HOME","JP","2026-01-01","")
ignored=.AJITestSupport~must(book~addVersion(v),"add approved")
dupe=book~addVersion(v)
ignored=.AJITestSupport~assert(\dupe~ok,"duplicate version ref rejected")
ignored=.AJITestSupport~assert(dupe~code="CONTRACT_VERSION_DUPLICATE","version ref is immutable identity")
say "PASS contract releases require approval and unique immutable identity"
::requires "TestSupport.cls"

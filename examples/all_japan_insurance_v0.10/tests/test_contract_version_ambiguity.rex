book=.AllJapanInsuranceContractBook~new
v1=.AJITestSupport~contractVersion("AJI-HOME-JP/A","HOME","JP","2026-01-01","")
v2=.AJITestSupport~contractVersion("AJI-HOME-JP/B","HOME","JP","2026-07-01","")
ignored=.AJITestSupport~must(book~addVersion(v1),"v1")
ignored=.AJITestSupport~must(book~addVersion(v2),"v2")
r=book~resolve("HOME","JP","2026-08-01")
ignored=.AJITestSupport~assert(\r~ok,"overlap rejected")
ignored=.AJITestSupport~assert(r~code="CONTRACT_VERSION_AMBIGUOUS","no last-release-wins contract semantics")
say "PASS overlapping contract releases are ambiguous"
::requires "TestSupport.cls"

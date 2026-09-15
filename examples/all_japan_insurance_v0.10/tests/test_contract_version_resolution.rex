book=.AllJapanInsuranceContractBook~new
v1=.AJITestSupport~contractVersion("AJI-HOME-JP/1","HOME","JP","2026-01-01","2026-07-01")
v2=.AJITestSupport~contractVersion("AJI-HOME-JP/2","HOME","JP","2026-07-01","")
ignored=.AJITestSupport~must(book~addVersion(v1),"v1")
ignored=.AJITestSupport~must(book~addVersion(v2),"v2")
r1=.AJITestSupport~must(book~resolve("HOME","JP","2026-06-30"),"resolve old")
r2=.AJITestSupport~must(book~resolve("HOME","JP","2026-07-01"),"resolve new")
ignored=.AJITestSupport~assert(r1~value~versionRef="AJI-HOME-JP/1","pre-change new business uses old release")
ignored=.AJITestSupport~assert(r2~value~versionRef="AJI-HOME-JP/2","effective date selects new release")
say "PASS effective-dated contract version resolution"
::requires "TestSupport.cls"

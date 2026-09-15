book=.AllJapanInsuranceContractBook~new
registry=book~functionRegistry
ruleOld=.AJITestSupport~payoutRule("RULE-OLD",10000,4,5,.false,0,"AJI.PAYOUT.DEDUCT_RATE_CAP/1")
ruleNew=.AJITestSupport~payoutRule("RULE-NEW",10000,4,5,.false,0,"AJI.PAYOUT.RATE_DEDUCT_CAP/1")
old=.AJITestSupport~must(registry~execute(ruleOld,100000),"old function")
new=.AJITestSupport~must(registry~execute(ruleNew,100000),"new function")
ignored=.AJITestSupport~assert(old~value=72000,"v1 deducts before applying percentage")
ignored=.AJITestSupport~assert(new~value=70000,"alternate version applies percentage before deductible")
ignored=.AJITestSupport~assert(old~value\=new~value,"function identity changes semantics")
dupe=registry~register(.AllJapanInsurancePayoutFunctionDeductRateCapV1~new)
ignored=.AJITestSupport~assert(\dupe~ok,"published function identity cannot be replaced")
ignored=.AJITestSupport~assert(dupe~code="PAYOUT_FUNCTION_DUPLICATE","same function ref is immutable")
unknown=.AJITestSupport~payoutRule("RULE-X",0,1,1,.false,0,"AJI.PAYOUT.UNKNOWN/9")
v=.AJITestSupport~contractVersion("AJI-HOME-JP/X","HOME","JP","2026-01-01","",unknown)
r=book~addVersion(v)
ignored=.AJITestSupport~assert(\r~ok,"contract cannot reference missing function implementation")
ignored=.AJITestSupport~assert(r~code="PAYOUT_FUNCTION_NOT_FOUND","function deployment is explicit")
say "PASS payout function identity is versioned and cannot be silently replaced"
::requires "TestSupport.cls"

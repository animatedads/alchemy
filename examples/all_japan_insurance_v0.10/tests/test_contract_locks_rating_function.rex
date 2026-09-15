fn=.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE
planRef="AJI-RATE-PI-GB-FNLOCK"
book=.AllJapanInsuranceContractBook~new
v=.AJITestSupport~contractVersion("AJI-CONTRACT-PI-GB/FN","PI","GB","2026-01-01","",.nil,planRef,fn)
ignored=.AJITestSupport~must(book~addVersion(v),"contract")
a=.AllJapanInsuranceAuthority~new(.nil,book)
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uwactor=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
pa=.AJITestSupport~actor("PA",.AllJapanInsuranceBuild~ROLE_POLICY)
s=.AllJapanInsuranceRiskSubmission~new("S-FNLOCK","PI","REL","RISK","GB","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D-FNLOCK","S-FNLOCK","PI","ACCEPT","AJI-PRODUCT-PI/0.1","UW","2026-08-28T10:00:00","E")
ignored=.AJITestSupport~must(a~recordDecision(uwactor,d),"decision")
base=.AJITestSupport~samplePlan(planRef)
plan=.AllJapanInsuranceRatingPlan~new(base~planRef,base~productCode,base~jurisdiction,base~currency,base~effectiveFrom,base~effectiveTo,base~tieredRiskPrice,base~underwritingPrice,base~salesCostRule,base~taxRules,fn)
req=.AllJapanInsuranceRatingRequest~new("S-FNLOCK","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",15000000,"INDEMNITY_LIMIT_MINOR",150000000)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-FNLOCK",req,plan,"2026-08-28T10:01:00"),"rate")
ignored=.AJITestSupport~must(a~recordRating(rater,r~value),"record")
q=.AJITestSupport~must(a~issueRatedQuote(uwactor,"Q-FNLOCK","D-FNLOCK","R-FNLOCK","2026-09-10T23:59:59","2026-08-28T10:02:00"),"quote")~value
ignored=.AJITestSupport~assert(q~ratingFunctionRef=fn,"quote retains function")
p=.AllJapanInsurancePolicy~new("P-FNLOCK","Q-FNLOCK","REL","PI","RISK","2026-09-01","2027-09-01","2026-08-29T10:00:00")
ignored=.AJITestSupport~must(a~bindPolicy(pa,p),"bind")
lock=a~policyContractLock("P-FNLOCK")
ignored=.AJITestSupport~assert(lock~ratingFunctionRef=fn,"bound policy locks executable rating function")
say "PASS contract and bound term retain executable rating function identity"
::requires "TestSupport.cls"

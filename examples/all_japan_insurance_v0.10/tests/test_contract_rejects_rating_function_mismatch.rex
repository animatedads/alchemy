expected=.AllJapanInsuranceRatingBuild~FUNCTION_MIN_THEN_PRORATE
actual=.AllJapanInsuranceRatingBuild~FUNCTION_PRORATE_THEN_MIN
planRef="AJI-RATE-PI-GB-FNMISMATCH"
book=.AllJapanInsuranceContractBook~new
v=.AJITestSupport~contractVersion("AJI-CONTRACT-PI-GB/FNMISMATCH","PI","GB","2026-01-01","",.nil,planRef,expected)
ignored=.AJITestSupport~must(book~addVersion(v),"contract")
a=.AllJapanInsuranceAuthority~new(.nil,book)
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uwactor=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
pa=.AJITestSupport~actor("PA",.AllJapanInsuranceBuild~ROLE_POLICY)
s=.AllJapanInsuranceRiskSubmission~new("S-FNM","PI","REL","RISK","GB","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D-FNM","S-FNM","PI","ACCEPT","AJI-PRODUCT-PI/0.1","UW","2026-08-28T10:00:00","E")
ignored=.AJITestSupport~must(a~recordDecision(uwactor,d),"decision")
base=.AJITestSupport~samplePlan(planRef)
plan=.AllJapanInsuranceRatingPlan~new(base~planRef,base~productCode,base~jurisdiction,base~currency,base~effectiveFrom,base~effectiveTo,base~tieredRiskPrice,base~underwritingPrice,base~salesCostRule,base~taxRules,actual)
req=.AllJapanInsuranceRatingRequest~new("S-FNM","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",15000000,"INDEMNITY_LIMIT_MINOR",150000000)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-FNM",req,plan,"2026-08-28T10:01:00"),"rate")
ignored=.AJITestSupport~must(a~recordRating(rater,r~value),"record")
ignored=.AJITestSupport~must(a~issueRatedQuote(uwactor,"Q-FNM","D-FNM","R-FNM","2026-09-10T23:59:59","2026-08-28T10:02:00"),"quote")
p=.AllJapanInsurancePolicy~new("P-FNM","Q-FNM","REL","PI","RISK","2026-09-01","2027-09-01","2026-08-29T10:00:00")
b=a~bindPolicy(pa,p)
ignored=.AJITestSupport~assert(\b~ok,"contract rejects different executable rating semantics")
ignored=.AJITestSupport~assert(b~code="CONTRACT_RATING_FUNCTION_MISMATCH","function mismatch code")
say "PASS contract release can constrain executable rating-function release"
::requires "TestSupport.cls"

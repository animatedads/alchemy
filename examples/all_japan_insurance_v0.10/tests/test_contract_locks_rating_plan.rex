book=.AllJapanInsuranceContractBook~new
v=.AJITestSupport~contractVersion("AJI-CONTRACT-PI-GB/1","PI","GB","2026-01-01","",.nil,"AJI-RATE-PI-GB-EXPECTED")
ignored=.AJITestSupport~must(book~addVersion(v),"contract")
a=.AllJapanInsuranceAuthority~new(.nil,book)
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
pa=.AJITestSupport~actor("PA",.AllJapanInsuranceBuild~ROLE_POLICY)
s=.AllJapanInsuranceRiskSubmission~new("S-RATE-LOCK","PI","REL","RISK","GB","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D-RATE-LOCK","S-RATE-LOCK","PI","ACCEPT","AJI-PRODUCT-PI/0.1","UW","2026-08-28T10:00:00","E")
ignored=.AJITestSupport~must(a~recordDecision(uw,d),"decision")
plan=.AJITestSupport~samplePlan("AJI-RATE-PI-GB-WRONG")
req=.AllJapanInsuranceRatingRequest~new("S-RATE-LOCK","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",15000000,"INDEMNITY_LIMIT_MINOR",150000000)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("R-RATE-LOCK",req,plan,"2026-08-28T10:01:00"),"rate")
ignored=.AJITestSupport~must(a~recordRating(rater,r~value),"record")
q=.AJITestSupport~must(a~issueRatedQuote(uw,"Q-RATE-LOCK","D-RATE-LOCK","R-RATE-LOCK","2026-09-10T23:59:59","2026-08-28T10:02:00"),"quote")~value
p=.AllJapanInsurancePolicy~new("P-RATE-LOCK","Q-RATE-LOCK","REL","PI","RISK","2026-09-01","2027-09-01","2026-08-29T10:00:00")
b=a~bindPolicy(pa,p)
ignored=.AJITestSupport~assert(\b~ok,"contract release rejects quote from another rate plan")
ignored=.AJITestSupport~assert(b~code="CONTRACT_RATING_PLAN_MISMATCH","rating plan is part of contract release compatibility")
say "PASS contract release can lock the permitted rating-plan release"
::requires "TestSupport.cls"

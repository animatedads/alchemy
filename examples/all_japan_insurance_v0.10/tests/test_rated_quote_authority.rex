a=.AllJapanInsuranceAuthority~new
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
rater=.AJITestSupport~actor("RATER",.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
s=.AllJapanInsuranceRiskSubmission~new("S-QUOTE-1","PI","REL","PI-RISK","GB","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D-QUOTE-1","S-QUOTE-1","PI","ACCEPT","AJI-PRODUCT-PI/0.1","UW","2026-08-28T10:00:00","UW-EVID")
ignored=.AJITestSupport~must(a~recordDecision(uw,d),"decision")
plan=.AJITestSupport~samplePlan
req=.AllJapanInsuranceRatingRequest~new("S-QUOTE-1","PI","GB","GBP","2026-08-28","TURNOVER_MINOR",15000000,"INDEMNITY_LIMIT_MINOR",150000000)
r=.AJITestSupport~must(.AllJapanInsuranceRatingEngine~new~rate("RATE-QUOTE-1",req,plan,"2026-08-28T10:01:00"),"rate")
ignored=.AJITestSupport~must(a~recordRating(rater,r~value),"record rating")
q=.AJITestSupport~must(a~issueRatedQuote(uw,"Q-QUOTE-1","D-QUOTE-1","RATE-QUOTE-1","2026-09-01T23:59:59","2026-08-28T10:02:00"),"issue rated quote")~value
ignored=.AJITestSupport~assert(q~premiumMinor=49280,"quote uses rated total")
ignored=.AJITestSupport~assert(q~ratingId="RATE-QUOTE-1","quote retains rating evidence")
ignored=.AJITestSupport~assert(q~ratingPlanRef="AJI-RATE-PI-GB-2026A","quote retains rate plan")
manual=.AllJapanInsuranceQuote~new("Q-MANUAL","D-QUOTE-1","S-QUOTE-1","PI",1,"GBP","2026-09-01T23:59:59","2026-08-28T10:03:00")
denied=a~issueQuote(uw,manual)
ignored=.AJITestSupport~assert(\denied~ok,"arbitrary premium denied")
ignored=.AJITestSupport~assert(denied~code="RATING_REQUIRED","manual price requires explicit override authority")
say "PASS rated quotation is calculation-backed and arbitrary premium is gated"
::requires "TestSupport.cls"

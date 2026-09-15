a=.AllJapanInsuranceAuthority~new
channel=.AJITestSupport~actor("DIRECT-WEB",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW-1",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
s=.AllJapanInsuranceRiskSubmission~new("S1","CAR","REL-1","VEH-1","JP","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D1","S1","CAR","DECLINE","AJI-PRODUCT-CAR/0.1","UW-1","2026-08-28T12:00:00","EVID-1")
ignored=.AJITestSupport~must(a~recordDecision(uw,d),"decline")
q=.AllJapanInsuranceQuote~new("Q1","D1","S1","CAR",10000,"JPY","2026-09-01T00:00:00","2026-08-28T12:01:00")
r=a~issueQuote(uw,q)
ignored=.AJITestSupport~assert(\r~ok,"declined risk cannot quote")
ignored=.AJITestSupport~assert(r~code="DECISION_NOT_ACCEPTED","decline enforced")
say "PASS quote requires accepted underwriting decision"
::requires "TestSupport.cls"

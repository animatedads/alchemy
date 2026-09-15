a=.AllJapanInsuranceAuthority~new
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actor("UW",.AllJapanInsuranceBuild~ROLE_UNDERWRITER)
s=.AllJapanInsuranceRiskSubmission~new("S1","HOME","REL","RISK","JP","2026-08-28")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D1","S1","HOME","ACCEPT","AJI-PRODUCT-CAR/0.1","UW","2026-08-28T10:00:00","E")
r=a~recordDecision(uw,d)
ignored=.AJITestSupport~assert(\r~ok,"wrong product policy ref denied")
ignored=.AJITestSupport~assert(r~code="PRODUCT_POLICY_REF_MISMATCH","product identity preserved")
say "PASS product policy identity cannot cross lines"
::requires "TestSupport.cls"

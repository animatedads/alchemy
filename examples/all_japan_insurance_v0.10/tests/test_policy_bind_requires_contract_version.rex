book=.AllJapanInsuranceContractBook~new
a=.AllJapanInsuranceAuthority~new(.nil,book)
channel=.AJITestSupport~actor("DIRECT",.AllJapanInsuranceBuild~ROLE_DISTRIBUTION)
uw=.AJITestSupport~actorRoles("UW",.array~of(.AllJapanInsuranceBuild~ROLE_UNDERWRITER,.AllJapanInsuranceBuild~ROLE_RATE_OVERRIDE))
pa=.AJITestSupport~actor("PA",.AllJapanInsuranceBuild~ROLE_POLICY)
s=.AllJapanInsuranceRiskSubmission~new("S-NO-CONTRACT","HOME","REL","HOME-1","JP","2026-08-01")
ignored=.AJITestSupport~must(a~submitRisk(channel,s),"submit")
d=.AllJapanInsuranceUnderwritingDecision~new("D-NO-CONTRACT","S-NO-CONTRACT","HOME","ACCEPT","AJI-PRODUCT-HOME/0.1","UW","2026-08-01T10:00:00","E")
ignored=.AJITestSupport~must(a~recordDecision(uw,d),"decision")
q=.AllJapanInsuranceQuote~new("Q-NO-CONTRACT","D-NO-CONTRACT","S-NO-CONTRACT","HOME",10000,"JPY","2026-08-10T23:59:59","2026-08-01T10:01:00","","","MANUAL_OVERRIDE","fixture")
ignored=.AJITestSupport~must(a~issueQuote(uw,q),"quote")
p=.AllJapanInsurancePolicy~new("P-NO-CONTRACT","Q-NO-CONTRACT","REL","HOME","HOME-1","2026-08-02","2027-08-02","2026-08-01T11:00:00")
r=a~bindPolicy(pa,p)
ignored=.AJITestSupport~assert(\r~ok,"policy cannot bind without contract release")
ignored=.AJITestSupport~assert(r~code="CONTRACT_VERSION_NOT_FOUND","missing contract ruleset blocks bind")
say "PASS policy bind requires an effective approved contract version"
::requires "TestSupport.cls"

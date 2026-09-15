env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
e=.RIDTestFixtures~grantStandard(env,"MORTGAGE","INTRODUCE")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-1","CUSTOMER:1","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~ok(engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
r=engine~act(c~caseId,"RECOMMEND","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"])
.RIDTestSupport~failCode("AUTHORITY_MISSING",r,"mortgage advice must require advice authority")
say "PASS mortgage permission gate"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

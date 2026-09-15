env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
.RIDTestFixtures~grantStandard(env,"MORTGAGE","INTRODUCE")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-R","CUSTOMER:R","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~ok(env["INTERMEDIARIES"]~setRepresentativeStatus("REP-1","SUSPENDED"))
r=engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"])
.RIDTestSupport~failCode("REPRESENTATIVE_NOT_ACTIVE",r)
say "PASS representative suspension gate"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

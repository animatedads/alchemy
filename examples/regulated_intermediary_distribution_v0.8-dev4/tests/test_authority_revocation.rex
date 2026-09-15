env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
.RIDTestFixtures~grantStandard(env,"MORTGAGE","INTRODUCE")
ar=env["AUTHORITIES"]
ctl=.RIDAuthorityControlEvent~new("CTL-1","G-CMP-MORTGAGE-INTRODUCE","SUSPENDED",env["NOW"] - .TimeSpan~new(0,0,0,0,1),"FIRM_COMPETENCE","SUSPENSION:1")
.RIDTestSupport~ok(ar~addControl(ctl))
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-G","CUSTOMER:G","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
r=engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"])
.RIDTestSupport~failCode("AUTHORITY_MISSING",r)
say "PASS authority control event gate"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

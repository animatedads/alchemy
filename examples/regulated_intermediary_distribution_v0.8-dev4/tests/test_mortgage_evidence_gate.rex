env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
.RIDTestFixtures~grantStandard(env,"MORTGAGE","INTRODUCE")
.RIDTestFixtures~grantStandard(env,"MORTGAGE","ADVISE")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-2","CUSTOMER:2","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~ok(engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
r=engine~act(c~caseId,"RECOMMEND","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"])
.RIDTestSupport~failCode("REQUIRED_EVIDENCE_MISSING",r)
do t over .array~of("FACT_FIND","AFFORDABILITY_ASSESSMENT","SUITABILITY_ASSESSMENT","PRODUCT_DISCLOSURE")
  .RIDTestFixtures~addEvidence(env,c~caseId,t,"EV-" || t)
end
.RIDTestSupport~ok(engine~act(c~caseId,"RECOMMEND","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~assertEq("RECOMMENDED",c~state)
say "PASS mortgage evidence gate"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

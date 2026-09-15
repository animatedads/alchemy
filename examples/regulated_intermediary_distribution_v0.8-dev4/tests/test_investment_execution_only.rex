env=.RIDTestFixtures~environment("INVESTMENT","EXECUTION_ONLY","FEDERATIONBANK_MERCHANT_BANK","FEDERATION_MERCHANT_DISTRIBUTION","FUND-1","7","FUND-1|7|SEM")
.RIDTestFixtures~grantStandard(env,"INVESTMENT","INTRODUCE")
.RIDTestFixtures~grantStandard(env,"INVESTMENT","ARRANGE")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-I1","CUSTOMER:I1","FIRM-1","REP-1","PROD-1","EXECUTION_ONLY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~ok(engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
r=engine~act(c~caseId,"RECOMMEND","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"])
.RIDTestSupport~failCode("NO_POLICY_RULE",r,"execution-only must not silently become advice")
do t over .array~of("APPROPRIATENESS_ASSESSMENT","PRODUCT_DISCLOSURE","CUSTOMER_INSTRUCTION")
  .RIDTestFixtures~addEvidence(env,c~caseId,t,"EV-" || t)
end
.RIDTestSupport~ok(engine~act(c~caseId,"PREPARE_APPLICATION","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~assertEq("APPLICATION_READY",c~state)
say "PASS investment execution-only separation"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

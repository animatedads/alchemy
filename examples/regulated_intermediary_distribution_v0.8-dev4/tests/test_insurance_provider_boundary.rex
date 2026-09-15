env=.RIDTestFixtures~environment("INSURANCE","ADVISED","ALL_JAPAN_INSURANCE_CO_LTD","ALL_JAPAN_POLICY_ADMIN","HOME-COVER","2027.1","AJI-HOME|2027.1|SEM")
p=env["PRODUCT"]
.RIDTestSupport~assertEq("ALL_JAPAN_INSURANCE_CO_LTD",p~providerIdentity~legalEntityId)
.RIDTestSupport~assertEq("FEDERATION_GROUP",p~providerIdentity~groupOwnerRef)
/* Group ownership does not rewrite provider legal authority. */
.RIDTestFixtures~grantStandard(env,"INSURANCE","INTRODUCE")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-AJI","CUSTOMER:AJI","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
.RIDTestSupport~ok(engine~act(c~caseId,"START_DISCOVERY","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
wrong=.RIDProviderStatusEvidence~new("PS-1","FEDERATIONBANK_PLC","ALL_JAPAN_POLICY_ADMIN","AJI:CASE:1",p~productSemanticIdentity,1,"BOUND",env["NOW"],"AJI:STATUS:1")
r=engine~recordProviderStatus(c~caseId,wrong)
.RIDTestSupport~failCode("PROVIDER_ENTITY_MISMATCH",r,"group owner must not impersonate insurer")
right=.RIDProviderStatusEvidence~new("PS-2","ALL_JAPAN_INSURANCE_CO_LTD","ALL_JAPAN_POLICY_ADMIN","AJI:CASE:1",p~productSemanticIdentity,1,"BOUND",env["NOW"],"AJI:STATUS:2")
.RIDTestSupport~ok(engine~recordProviderStatus(c~caseId,right))
.RIDTestSupport~assertEq("BOUND",c~providerStatus)
say "PASS insurance provider legal-entity boundary"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

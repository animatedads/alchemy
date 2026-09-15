env=.RIDTestFixtures~environment("INSURANCE","ADVISED","ALL_JAPAN_INSURANCE_CO_LTD","ALL_JAPAN_POLICY_ADMIN","HOME-COVER","2026.08","AJI-HOME|2026.08|SEM")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-LATE","CUSTOMER:LATE","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
p=env["PRODUCT"]
latest=.RIDProviderStatusEvidence~new("AJI-11",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"AJI:CASE:LATE",p~productSemanticIdentity,11,"DECLINED",env["NOW"],"AJI:EVENT:11")
.RIDTestSupport~ok(engine~recordProviderStatus(c~caseId,latest))
late=.RIDProviderStatusEvidence~new("AJI-10",p~providerIdentity~legalEntityId,p~providerIdentity~providerSystem,"AJI:CASE:LATE",p~productSemanticIdentity,10,"UNDERWRITING",env["NOW"],"AJI:EVENT:10")
.RIDTestSupport~failCode("STALE_PROVIDER_STATUS",engine~recordProviderStatus(c~caseId,late))
.RIDTestSupport~assertEq("DECLINED",c~providerStatus,"late delivery must not roll the visible state backwards")
.RIDTestSupport~assertEq(11,c~providerSequence)
say "PASS late provider event cannot roll state backwards"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

env=.RIDTestFixtures~environment("MORTGAGE","ADVISED")
engine=env["ENGINE"]
c=.RIDTestSupport~ok(engine~openCase("CASE-BRIDGE","CUSTOMER:B","FIRM-1","REP-1","PROD-1","ADVISED","REP-1","INTERMEDIARY_REPRESENTATIVE",env["NOW"]))
e=.RIDRelationshipCaseBridge~distributionCaseElement(c,"RC-E-1")
.RIDTestSupport~assertEq("REGULATED_DISTRIBUTION_CASE",e~semanticKind)
.RIDTestSupport~assertEq("REGULATED_INTERMEDIARY_DISTRIBUTION",e~sourceSystem)
.RIDTestSupport~assertEq(c~caseId,e~sourceRef)
.RIDTestSupport~assertEq("WORK_COORDINATION_REFERENCE",e~authorityClass)
say "PASS Relationship Case bridge"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "RIDRelationshipCaseBridge.cls"
::requires "TestSupport.cls"
::requires "TestFixtures.cls"

catalog=.FederationBankCasePolicyFixtures~publishedCatalog
module=.RelationshipCaseServiceRuntimeModule~new(catalog)
.RelationshipCaseServiceTestSupport~assertTrue(module~runtimePrepare(.nil), "runtime prepare")
.RelationshipCaseServiceTestSupport~assertTrue(module~runtimeSelfTest, "runtime self test")
.RelationshipCaseServiceTestSupport~assertTrue(module~runtimeStart, "runtime start")
.RelationshipCaseServiceTestSupport~assertEqual("relationship.case.service/0.1", module~apiVersion, "service API")
.RelationshipCaseServiceTestSupport~assertEqual("RELATIONSHIP-CASE-SERVICE-V0.1", module~generationLabel, "generation label")
.RelationshipCaseServiceTestSupport~assertTrue(module~service <> .nil, "service exposed")
.RelationshipCaseServiceTestSupport~assertTrue(module~runtimeQuiesce, "runtime quiesce")
.RelationshipCaseServiceTestSupport~assertTrue(\module~service~accepting, "service quiesced")
.RelationshipCaseServiceTestSupport~assertTrue(module~runtimeStop, "runtime stop")
say "PASS test_runtime_module"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankCasePolicyFixtures.cls"
::requires "RelationshipCaseServiceRuntimeModule.cls"
::requires "InstitutionalPolicy.cls"

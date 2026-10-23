/* Offline protocol/authority test; the verifier is intentionally synthetic. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('synthetic-ssc','SSC receipt test')
engine = .ArchitectureScenarioComparison~new(planner)
engine~register(.ArchitectureScenario~new('a','A','Synthetic ready plan','architect'))
engine~register(.ArchitectureScenario~new('b','B','Other','architect'))
cmp = engine~compare(p)
ready = cmp['scenarios'][1]
ready['state'] = 'READY_FOR_DEPENDENCY_RESOLUTION'
ready['plan']['state'] = 'READY_FOR_DEPENDENCY_RESOLUTION'
ready['plan']['issues'] = .Array~new
ready['plan']['openQuestions'] = .Array~new
ready['plan']['buildRequest']['externalIntegrationRequirements'] = .Array~new
ready['plan']['buildRequest']['businessCapabilityRequirements'] = .Array~new
review = .ArchitecturePromotionReview~new(cmp,'a','architect','reason','evidence://selection')
review~disposition('b','REJECTED','architect','not selected','evidence://b')
review~approve('reviewer','evidence://review')
qualified = review~handoff(cmp,.TestApprovalVerifier~new)
call assert qualified['status'] == 'READY_FOR_SSC_REVIEW','prerequisite promotion ready'
record = .ArchitectureSscReceipt~new(qualified)
call assert record~status == 'PENDING_SSC_AUTHORITY','no SSC claimed initially'
candidate = .Directory~new
candidate['projectId'] = 'synthetic-ssc'
candidate['scenarioId'] = 'a'
candidate['proofRef'] = 'unverified-candidate'
if record~projection['executable'] \== .JSON~false then exit 1
result = record~accept(candidate,.TestSscVerifier~new)
call assert result['status'] == 'SSC_RESOLUTION_VERIFIED','external verified resolution receipt admitted'
call assert result['executable'] == .JSON~false,'not executable'
call assert result['deploymentPlan'] == .nil,'no deployment plan'
call assert pos('PRIVATE_SECRET',.JSON~toJSON(result)) == 0,'no verifier secrets emitted'
result['status'] = 'TAMPERED'
call assert record~projection['status'] == 'SSC_RESOLUTION_VERIFIED','defensive copy'
say 'PASS SSC receipt evidence-only handoff, still non-executable'
exit 0
assert:
  use arg yes, reason
  if yes then return
  say 'FAIL' reason
  exit 1
::requires 'ArchitectureSscReceipt.cls'
::class TestApprovalVerifier
::method verifyArchitectureApproval
  use strict arg projectId, scenarioId, principal, evidence, generation
  r = .Directory~new
  r['verified'] = .JSON~true
  r['principal'] = principal
  r['scope'] = 'ARCHITECTURE_PROMOTION'
  r['generationVerified'] = .JSON~true
  r['proofRef'] = 'FAKE-APPROVAL-TEST'
  return r
::class TestSscVerifier
::method verifyArchitectureSscResolution
  use strict arg projectId, scenarioId, requestJSON, receiptJSON
  r = .Directory~new
  r['accepted'] = .JSON~true
  r['projectId'] = projectId
  r['scenarioId'] = scenarioId
  r['requestVerified'] = .JSON~true
  r['closureVerified'] = .JSON~true
  r['proofRef'] = 'FAKE-SSC-TEST'
  r['closureRef'] = 'FAKE-LOCK-TEST'
  r['internalSecret'] = 'PRIVATE_SECRET'
  return r

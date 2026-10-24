/* Synthetic fully assessed architectural evidence for promotion gate only.
 * This test does NOT assert real component availability, SSC resolution or
 * deployment readiness. No SSC or Deployment method is invoked. */
cat = .ArchitectureCatalog~fromFile('catalog/architecture_catalog.json')
planner = .ArchitecturePlanner~new(cat)
p = planner~project('synthetic-review','Synthetic gate checks')
comparisonEngine = .ArchitectureScenarioComparison~new(planner)
comparisonEngine~register(.ArchitectureScenario~new('a','A','For SSC gate test','architect'))
comparisonEngine~register(.ArchitectureScenario~new('b','B','Rejected alternative','architect'))
fixture = comparisonEngine~compare(p)
chosen = fixture['scenarios'][1]
chosen['state'] = 'READY_FOR_DEPENDENCY_RESOLUTION'
chosen['plan']['state'] = 'READY_FOR_DEPENDENCY_RESOLUTION'
chosen['plan']['issues'] = .Array~new
chosen['plan']['openQuestions'] = .Array~new
chosen['plan']['buildRequest']['externalIntegrationRequirements'] = .Array~new
chosen['plan']['buildRequest']['businessCapabilityRequirements'] = .Array~new
review = .ArchitecturePromotionReview~new(fixture,'a','architect','Gate','evidence://gate')
review~disposition('b','REJECTED','board','Do not choose','evidence://b')
review~approve('reviewer','evidence://board')
call assert review~handoff(fixture)['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'claimed reviewer is not trusted authority'
review~verifyApproval(.GateTestVerifier~new)
call assert pos('PRIVATE_FAKE_TOKEN',.JSON~toJSON(review~review)) == 0, -
  'verifier internal secrets never enter review artifacts'
call assert review~handoff['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'fresh comparison revalidation required even after verification'
call assert review~handoff(fixture)['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'reusing an earlier attestation does not authorize an SSC handoff'
handoff = review~handoff(fixture,.GateTestVerifier~new)
call assert handoff['status'] == 'READY_FOR_SSC_REVIEW','complete fixture may request SSC review'
call assert handoff['sscSubmission'] \== .nil,'typed SSC request proposed'
call assert handoff['sscSubmission']['dependencyLock'] == .nil,'no fabricated lock'
call assert handoff['buildRequest']['executable'] == .JSON~false,'no executable build'
call assert handoff['deploymentPlan'] == .nil,'still no deployment authority'
/* External integration uncertainty vetoes claimed readiness. */
changed = .JSON~fromJSON(.JSON~toJSON(fixture))
changed['scenarios'][1]['plan']['buildRequest']['externalIntegrationRequirements']~append('unqualified jms')
recheck = .ArchitecturePromotionReview~new(changed,'a','architect','Gate','evidence://gate')
recheck~disposition('b','REJECTED','board','No','evidence://b')
recheck~approve('reviewer','evidence://board')
recheck~verifyApproval(.GateTestVerifier~new)
call assert recheck~handoff(changed,.GateTestVerifier~new)['status'] == 'DESIGN_ONLY_UNRESOLVED', -
  'unqualified external integration blocks SSC admission'
say 'PASS synthetic SSC gate; design approval never resolves or deploys'
exit 0
assert:
  use arg cond, label
  if cond then return
  say 'FAIL:' label
  exit 1
::requires 'ArchitecturePromotion.cls'

/* A purely injected FAKE verifier for unit tests. This is never a live
 * identity attestation and must not be used by production applications. */
::class GateTestVerifier
::method verifyArchitectureApproval
  use strict arg projectId, scenarioId, principal, approvalEvidence, snapshot
  receipt = .Directory~new
  receipt['verified'] = .JSON~true
  receipt['principal'] = principal
  receipt['scope'] = 'ARCHITECTURE_PROMOTION'
  receipt['generationVerified'] = .JSON~true
  receipt['proofRef'] = 'TEST-ONLY-ATTESTATION-NOT-TRUSTED'
  receipt['internalToken'] = 'PRIVATE_FAKE_TOKEN'
  return receipt

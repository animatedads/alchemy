/* Architecture Intentions — architecture.promotion/0.1
 * Governs selection of a scenario, not installation, deployment or SSC resolution.
 * The comparison is snapshotted by a JSON boundary before review. All returned
 * objects are independently parsed: callers cannot modify the reviewed plan.
 * The JSON snapshot is a content record, NOT a cryptographic digest/signature.
 */
::requires 'ArchitectureScenarios.cls'

::class ArchitecturePromotionReview public
::attribute scenarioId get
::attribute architect get
::attribute status get

/* Open a new independent review for an exact comparison generation. */
::method init
  expose comparisonJSON scenarioId architect selectionReason selectionEvidence dispositions status decisionAuthority decisionEvidence authorityVerified verificationReceiptJSON
  use strict arg comparison, scenarioId, architect, selectionReason, selectionEvidence
  if comparison['schema'] \== 'alchemy.architecture.scenario-comparison/0.1' then -
    raise syntax 93.900 array('ARCH_PROMOTION_COMPARISON_SCHEMA')
  if scenarioId~strip == '' | architect~strip == '' | selectionReason~strip == '' | selectionEvidence~strip == '' then -
    raise syntax 93.900 array('ARCH_PROMOTION_SELECTION_PROVENANCE_REQUIRED')
  match = .false
  do item over comparison['scenarios']
    if item['id'] == scenarioId then do
      match = .true
      if item['state'] == 'INCONSISTENT' then -
        raise syntax 93.900 array('ARCH_PROMOTION_POLICY_CONFLICT',scenarioId)
    end
  end
  if \match then raise syntax 93.900 array('ARCH_PROMOTION_SCENARIO_NOT_FOUND',scenarioId)
  comparisonJSON = .JSON~toJSON(comparison)
  dispositions = .Directory~new
  status = 'OPEN_REVIEW'
  decisionAuthority = ''
  decisionEvidence = ''
  authorityVerified = .false
  verificationReceiptJSON = ''

/* Freeze a reason for each other option; no silent deletion of alternatives.
 * Rejected and deferred options remain visible in the audit record. */
::method disposition
  expose dispositions status scenarioId comparisonJSON
  use strict arg optionId, finding, authority, reason, evidence
  if status \== 'OPEN_REVIEW' then raise syntax 93.900 array('ARCH_PROMOTION_REVIEW_FROZEN')
  if optionId == scenarioId then raise syntax 93.900 array('ARCH_PROMOTION_SELECTED_CANNOT_BE_REJECTED')
  if wordpos(finding,'REJECTED DEFERRED WITHDRAWN') == 0 then -
    raise syntax 93.900 array('ARCH_PROMOTION_INVALID_DISPOSITION',finding)
  if optionId~strip == '' | authority~strip == '' | reason~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_PROMOTION_DISPOSITION_PROVENANCE_REQUIRED')
  if dispositions~hasIndex(optionId) then -
    raise syntax 93.900 array('ARCH_PROMOTION_DUPLICATE_DISPOSITION',optionId)
  cmp = .JSON~fromJSON(comparisonJSON)
  exists = .false
  do candidate over cmp['scenarios']
    if candidate['id'] == optionId then exists = .true
  end
  if \exists then raise syntax 93.900 array('ARCH_PROMOTION_UNKNOWN_ALTERNATIVE',optionId)
  row = .Directory~new
  row['id'] = optionId
  row['disposition'] = finding
  row['authority'] = authority
  row['reason'] = reason
  row['evidence'] = evidence
  dispositions[optionId] = row
  return .JSON~fromJSON(.JSON~toJSON(row))

/* An independent named reviewer attests a design decision, not compliance.
 * This cannot turn NEEDS_DISCOVERY into READY_FOR_SSC. */
::method approve
  expose status architect decisionAuthority decisionEvidence dispositions comparisonJSON
  use strict arg reviewer, evidence
  if status \== 'OPEN_REVIEW' then raise syntax 93.900 array('ARCH_PROMOTION_REVIEW_FROZEN')
  if reviewer~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_PROMOTION_APPROVAL_EVIDENCE_REQUIRED')
  if reviewer == architect then -
    raise syntax 93.900 array('ARCH_PROMOTION_INDEPENDENT_REVIEW_REQUIRED')
  cmp = .JSON~fromJSON(comparisonJSON)
  do candidate over cmp['scenarios']
    if candidate['id'] == self~scenarioId then iterate
    if \dispositions~hasIndex(candidate['id']) then -
      raise syntax 93.900 array('ARCH_PROMOTION_ALTERNATIVE_UNREVIEWED',candidate['id'])
  end
  decisionAuthority = reviewer
  decisionEvidence = evidence
  status = 'DESIGN_SELECTED'
  return self~review

/* Explicitly refuse approval; retain reasons. The reviewer must be named. */
::method refuse
  expose status decisionAuthority decisionEvidence
  use strict arg reviewer, evidence
  if status \== 'OPEN_REVIEW' then raise syntax 93.900 array('ARCH_PROMOTION_REVIEW_FROZEN')
  if reviewer~strip == '' | evidence~strip == '' then -
    raise syntax 93.900 array('ARCH_PROMOTION_REFUSAL_EVIDENCE_REQUIRED')
  decisionAuthority = reviewer
  decisionEvidence = evidence
  status = 'REFUSED'
  return self~review

/* A comparison object can be checked against the frozen review generation.
 * Any mutated assumptions or candidate plans require a NEW review. */
::method matches
  expose comparisonJSON
  use strict arg comparison
  if comparison['schema'] \== 'alchemy.architecture.scenario-comparison/0.1' then return .false
  return .JSON~toJSON(comparison) == comparisonJSON

/* Host-injected identity/policy verifier is the ONLY approval authority. The
 * reviewer's textual claim is insufficient. A verifier must return a specific
 * attestation matching the reviewed principal and architecture scope. The
 * host must inject an authenticated and trusted verifier; this API does not
 * issue credentials, validate signatures or establish that trust itself. */
::method verifyApproval
  expose status comparisonJSON decisionAuthority decisionEvidence authorityVerified verificationReceiptJSON
  use strict arg verifier
  if status \== 'DESIGN_SELECTED' then -
    raise syntax 93.900 array('ARCH_PROMOTION_APPROVAL_REQUIRED')
  if verifier == .nil then raise syntax 93.900 array('ARCH_PROMOTION_TRUSTED_VERIFIER_REQUIRED')
  if \verifier~hasMethod('verifyArchitectureApproval') then -
    raise syntax 93.900 array('ARCH_PROMOTION_VERIFIER_API_REQUIRED')
  cmp = .JSON~fromJSON(comparisonJSON)
  receipt = verifier~verifyArchitectureApproval(cmp['projectId'],self~scenarioId, -
    decisionAuthority,decisionEvidence,comparisonJSON)
  if \receipt~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_PROMOTION_ATTESTATION_INVALID')
  if receipt['verified'] \== .JSON~true | -
      receipt['principal'] \== decisionAuthority | -
      receipt['scope'] \== 'ARCHITECTURE_PROMOTION' | -
      receipt['generationVerified'] \== .JSON~true then -
    raise syntax 93.900 array('ARCH_PROMOTION_ATTESTATION_DENIED')
  if receipt['proofRef'] == .nil then -
    raise syntax 93.900 array('ARCH_PROMOTION_ATTESTATION_PROOF_MISSING')
  if receipt['proofRef']~strip == '' then -
    raise syntax 93.900 array('ARCH_PROMOTION_ATTESTATION_PROOF_MISSING')
  /* Limit the public evidence projection. Verifiers may possess credentials;
   * their extra internal members must never be embedded in build artifacts. */
  safeReceipt = .Directory~new
  safeReceipt['verified'] = .JSON~true
  safeReceipt['principal'] = decisionAuthority
  safeReceipt['scope'] = 'ARCHITECTURE_PROMOTION'
  safeReceipt['generationVerified'] = .JSON~true
  safeReceipt['proofRef'] = receipt['proofRef']
  verificationReceiptJSON = .JSON~toJSON(safeReceipt)
  authorityVerified = .true
  return self~review

/* Read-only review presentation. Never return retained mutable Directory refs. */
::method review
  expose comparisonJSON scenarioId architect selectionReason selectionEvidence dispositions status decisionAuthority decisionEvidence authorityVerified verificationReceiptJSON
  cmp = .JSON~fromJSON(comparisonJSON)
  record = .Directory~new
  record['schema'] = 'alchemy.architecture.promotion-review/0.1'
  record['projectId'] = cmp['projectId']
  record['scenarioId'] = scenarioId
  record['architect'] = architect
  record['selectionReason'] = selectionReason
  record['selectionEvidence'] = selectionEvidence
  record['status'] = status
  record['approvalAuthority'] = decisionAuthority
  record['approvalEvidence'] = decisionEvidence
  record['approvalVerified'] = .JSON~false
  record['verificationReceipt'] = .nil
  if authorityVerified then do
    record['approvalVerified'] = .JSON~true
    record['verificationReceipt'] = .JSON~fromJSON(verificationReceiptJSON)
  end
  record['alternatives'] = .Array~new
  do candidate over cmp['scenarios']
    if candidate['id'] == scenarioId then iterate
    if dispositions~hasIndex(candidate['id']) then record['alternatives']~append(dispositions[candidate['id']])
    else do
      missing = .Directory~new
      missing['id'] = candidate['id']
      missing['disposition'] = 'UNREVIEWED'
      record['alternatives']~append(missing)
    end
  end
  return .JSON~fromJSON(.JSON~toJSON(record))

/* Handoff is non-executable, not an SSC lock or Deployment plan.
 * READY_FOR_SSC requires planner readiness and zero outstanding external
 * integration/capability qualifications; otherwise issue DESIGN_ONLY review. */
::method handoff
  expose comparisonJSON status authorityVerified
  use strict arg currentComparison = .nil, trustedVerifier = .nil
  if status \== 'DESIGN_SELECTED' then -
    raise syntax 93.900 array('ARCH_PROMOTION_NOT_APPROVED')
  cmp = .JSON~fromJSON(comparisonJSON)
  choice = .nil
  do candidate over cmp['scenarios']
    if candidate['id'] == self~scenarioId then choice = candidate
  end
  if choice == .nil then raise syntax 93.900 array('ARCH_PROMOTION_SNAPSHOT_BROKEN')
  plan = choice['plan']
  request = plan['buildRequest']
  fresh = .false
  if currentComparison \== .nil then do
    if \self~matches(currentComparison) then -
      raise syntax 93.900 array('ARCH_PROMOTION_COMPARISON_CHANGED_NEW_REVIEW_REQUIRED')
    fresh = .true
  end
  verifiedNow = .false
  if trustedVerifier \== .nil then do
    if \fresh then -
      raise syntax 93.900 array('ARCH_PROMOTION_CURRENT_COMPARISON_REQUIRED')
    /* A fresh authorised policy check is required on EACH SSC handoff. */
    self~verifyApproval(trustedVerifier)
    verifiedNow = .true
  end
  eligible = fresh & verifiedNow & authorityVerified & -
    plan['state'] == 'READY_FOR_DEPENDENCY_RESOLUTION'
  if plan['issues']~items > 0 | plan['openQuestions']~items > 0 then eligible = .false
  if request['externalIntegrationRequirements']~items > 0 then eligible = .false
  if request['businessCapabilityRequirements']~items > 0 then eligible = .false
  report = .Directory~new
  report['schema'] = 'alchemy.architecture.promotion-handoff/0.1'
  report['projectId'] = cmp['projectId']
  report['catalogRevision'] = plan['catalogRevision']
  report['scenarioId'] = choice['id']
  report['scenarioLabel'] = choice['label']
  report['review'] = self~review
  report['plan'] = plan
  report['buildRequest'] = request
  report['otherScenarios'] = .Array~new
  report['consideredAlternatives'] = .Array~new
  do other over cmp['scenarios']
    if other['id'] \== choice['id'] then do
      summary = .Directory~new
      summary['id'] = other['id']
      summary['state'] = other['state']
      summary['disposition'] = 'UNREVIEWED'
      do finding over report['review']['alternatives']
        if finding['id'] == other['id'] then summary['disposition'] = finding['disposition']
      end
      report['otherScenarios']~append(summary)
      report['consideredAlternatives']~append(other)
    end
  end
  report['unresolved'] = .Directory~new
  report['unresolved']['issues'] = plan['issues']
  report['unresolved']['questions'] = plan['openQuestions']
  report['unresolved']['externalIntegrations'] = request['externalIntegrationRequirements']
  report['unresolved']['businessCapabilityRequirements'] = request['businessCapabilityRequirements']
  report['readyForSSC'] = .JSON~false
  report['promotionGates'] = .Array~new
  if \fresh then report['promotionGates']~append('FRESH_COMPARISON_REVIEW_REQUIRED')
  if \verifiedNow then report['promotionGates']~append('FRESH_APPROVAL_POLICY_VERIFICATION_REQUIRED')
  report['sscSubmission'] = .nil
  if eligible then do
    report['status'] = 'READY_FOR_SSC_REVIEW'
    report['readyForSSC'] = .JSON~true
    submission = .Directory~new
    submission['schema'] = 'alchemy.architecture.ssc-resolution-request/0.1'
    submission['projectId'] = cmp['projectId']
    submission['scenarioId'] = choice['id']
    submission['requestedComponents'] = request['requirements']
    submission['requestedTarget'] = request['target']
    submission['authority'] = report['review']['approvalAuthority']
    submission['evidence'] = report['review']['approvalEvidence']
    submission['dependencyLock'] = .nil
    submission['requiresSSCResolution'] = .JSON~true
    submission['executable'] = .JSON~false
    report['sscSubmission'] = submission
  end
  else report['status'] = 'DESIGN_ONLY_UNRESOLVED'
  report['nextAuthority'] = 'SSC verification, then Deployment independent qualification'
  report['dependencyLock'] = .nil
  report['deploymentPlan'] = .nil
  report['activationRequested'] = .JSON~false
  report['executable'] = .JSON~false
  return .JSON~fromJSON(.JSON~toJSON(report))

/* File output requires an existing empty destination and refuses overwrites.
 * Publication durability and trusted digest/signature belong to platform
 * FileSystem/Crypto/SSC rather than this design-time writer. */
::class ArchitecturePromotionWriter public
::method write
  use strict arg promotion, directory
  if promotion['schema'] \== 'alchemy.architecture.promotion-handoff/0.1' then -
    raise syntax 93.900 array('ARCH_PROMOTION_WRITER_SCHEMA')
  if SysIsFileDirectory(directory) == 0 then -
    raise syntax 93.900 array('ARCH_PROMOTION_WRITER_DIRECTORY_MISSING')
  if directory~right(1) == '/' then directory = directory~left(directory~length-1)
  files = .Directory~new
  files['promotion-handoff.json'] = promotion
  files['review-decision.json'] = promotion['review']
  files['selected-plan.json'] = promotion['plan']
  files['selected-build-request.json'] = promotion['buildRequest']
  files['considered-alternatives.json'] = promotion['consideredAlternatives']
  if promotion['sscSubmission'] \== .nil then -
    files['ssc-resolution-request.json'] = promotion['sscSubmission']
  do filename over files~allIndexes
    path = directory'/'filename
    if stream(path,'C','QUERY EXISTS') \== '' then -
      raise syntax 93.900 array('ARCH_PROMOTION_WRITER_EXISTS',path)
  end
  paths = .Array~new
  do filename over files~allIndexes
    path = directory'/'filename
    call lineout path,.JSON~toJSON(files[filename])
    call lineout path
    call stream path,'C','CLOSE'
    paths~append(path)
  end
  return paths

/* Architecture Intentions — read-only SSC handoff receipt (design authority only).
 * This DOES NOT implement an SSC resolver or authorize deployment.
 * A deployment host must supply a trusted SSC verifier separately; this class
 * never accepts a ZIP filename or unverifiable self-assertion as source truth.
 */
::requires 'ArchitecturePromotion.cls'

::class ArchitectureSscReceipt public
::attribute status get

::method init
  expose originalJSON requestJSON status verifiedJSON
  use strict arg promotionHandoff
  if \promotionHandoff~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_SSC_HANDOFF_SHAPE')
  if promotionHandoff['schema'] \== 'alchemy.architecture.promotion-handoff/0.1' | -
      promotionHandoff['status'] \== 'READY_FOR_SSC_REVIEW' | -
      promotionHandoff['readyForSSC'] \== .JSON~true then -
    raise syntax 93.900 array('ARCH_SSC_HANDOFF_NOT_READY')
  request = promotionHandoff['sscSubmission']
  if \request~isA(.Directory) then raise syntax 93.900 array('ARCH_SSC_REQUEST_MISSING')
  if request['schema'] \== 'alchemy.architecture.ssc-resolution-request/0.1' | -
      request['projectId'] \== promotionHandoff['projectId'] | -
      request['scenarioId'] \== promotionHandoff['scenarioId'] then -
    raise syntax 93.900 array('ARCH_SSC_REQUEST_MISMATCH')
  if request['dependencyLock'] \== .nil | request['executable'] \== .JSON~false then -
    raise syntax 93.900 array('ARCH_SSC_REQUEST_CLAIMS_EXECUTION')
  originalJSON = .JSON~toJSON(promotionHandoff)
  requestJSON = .JSON~toJSON(request)
  verifiedJSON = ''
  status = 'PENDING_SSC_AUTHORITY'

::method proposedRequest
  expose requestJSON
  return .JSON~fromJSON(requestJSON)

/* The external SSC adapter must validate the exact request, component source
 * identities, lineages, levels, package paths, content digests and dependency
 * closure, and must verify receipt provenance. No self-claimed verified flag
 * from the submitted receipt can replace that external authority. */
::method accept
  expose originalJSON requestJSON status verifiedJSON
  use strict arg candidateReceipt, trustedVerifier
  if status \== 'PENDING_SSC_AUTHORITY' then -
    raise syntax 93.900 array('ARCH_SSC_RECEIPT_ALREADY_ADMITTED')
  if trustedVerifier == .nil then raise syntax 93.900 array('ARCH_SSC_VERIFIER_REQUIRED')
  if \trustedVerifier~hasMethod('verifyArchitectureSscResolution') then -
    raise syntax 93.900 array('ARCH_SSC_VERIFIER_API_REQUIRED')
  if \candidateReceipt~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_SSC_RECEIPT_SHAPE')
  req = .JSON~fromJSON(requestJSON)
  if candidateReceipt['projectId'] \== req['projectId'] | -
      candidateReceipt['scenarioId'] \== req['scenarioId'] then -
    raise syntax 93.900 array('ARCH_SSC_RECEIPT_TARGET_MISMATCH')
  verdict = trustedVerifier~verifyArchitectureSscResolution( -
    req['projectId'], req['scenarioId'], requestJSON, .JSON~toJSON(candidateReceipt))
  if \verdict~isA(.Directory) then raise syntax 93.900 array('ARCH_SSC_VERDICT_SHAPE')
  if verdict['accepted'] \== .JSON~true | -
      verdict['projectId'] \== req['projectId'] | -
      verdict['scenarioId'] \== req['scenarioId'] | -
      verdict['requestVerified'] \== .JSON~true | -
      verdict['closureVerified'] \== .JSON~true then -
    raise syntax 93.900 array('ARCH_SSC_VERDICT_DENIED')
  if verdict['proofRef'] == .nil | verdict['closureRef'] == .nil then -
    raise syntax 93.900 array('ARCH_SSC_PROVENANCE_MISSING')
  if verdict['proofRef']~strip == '' | verdict['closureRef']~strip == '' then -
    raise syntax 93.900 array('ARCH_SSC_PROVENANCE_MISSING')
  /* Whitelist public evidence: no internal keys, tokens or credentials. */
  safe = .Directory~new
  safe['schema'] = 'alchemy.architecture.ssc-qualification/0.1'
  safe['projectId'] = req['projectId']
  safe['scenarioId'] = req['scenarioId']
  safe['status'] = 'SSC_RESOLUTION_VERIFIED'
  safe['proofRef'] = verdict['proofRef']
  safe['closureRef'] = verdict['closureRef']
  safe['requestVerified'] = .JSON~true
  safe['closureVerified'] = .JSON~true
  safe['executable'] = .JSON~false
  safe['deploymentPlan'] = .nil
  safe['activationRequested'] = .JSON~false
  safe['nextAuthority'] = 'Deployment artifact/target qualification and independent activation approval'
  verifiedJSON = .JSON~toJSON(safe)
  status = 'SSC_RESOLUTION_VERIFIED'
  return self~projection

::method projection
  expose verifiedJSON status requestJSON
  if status == 'SSC_RESOLUTION_VERIFIED' then return .JSON~fromJSON(verifiedJSON)
  d = .Directory~new
  d['schema'] = 'alchemy.architecture.ssc-qualification/0.1'
  d['status'] = status
  d['request'] = .JSON~fromJSON(requestJSON)
  d['executable'] = .JSON~false
  d['deploymentPlan'] = .nil
  return d

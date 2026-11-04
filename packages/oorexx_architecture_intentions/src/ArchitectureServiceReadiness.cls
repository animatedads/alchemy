/* Architecture Service Readiness /0.1 — evidence-only gate inventory.
 * Each service may require multiple proofs with distinct owner and scope.
 * No assertion here is a live site probe, an authorisation or deployment.
 */
::requires 'json.cls'

::class ArchitectureServiceReadiness public
::attribute projectId get

::method init
  expose projectId gates order
  use strict arg projectId
  if projectId~string~strip == '' then -
    raise syntax 93.900 array('ARCH_READINESS_PROJECT_ID_REQUIRED')
  gates = .Directory~new
  order = .Array~new

::method requireGate
  expose gates order
  use strict arg serviceId, gateId, description, evidenceAuthority
  if serviceId~string~strip == '' | gateId~string~strip == '' | -
     description~string~strip == '' | evidenceAuthority~string~strip == '' then -
    raise syntax 93.900 array('ARCH_READINESS_GATE_FIELDS_REQUIRED')
  if gates~hasIndex(gateId) then -
    raise syntax 93.900 array('ARCH_READINESS_DUPLICATE_GATE')
  d = .Directory~new
  d['serviceId'] = serviceId
  d['gateId'] = gateId
  d['description'] = description
  d['evidenceAuthority'] = evidenceAuthority
  d['status'] = 'MISSING_VERIFIED_EVIDENCE'
  d['proofRef'] = .nil
  d['evidenceRef'] = .nil
  gates[gateId] = d
  order~append(gateId)
  return self

/* This is *admission of independently checked evidence*, not execution.
 * Candidate evidence alone is never enough; the injected verifier must bind
 * project, service, gate and authority to the submitted evidence.
 */
::method admitEvidence
  expose projectId gates
  use strict arg gateId, candidateReceipt, trustedVerifier
  if \gates~hasIndex(gateId) then -
    raise syntax 93.900 array('ARCH_READINESS_UNKNOWN_GATE')
  if \candidateReceipt~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_READINESS_EVIDENCE_SHAPE')
  if trustedVerifier == .nil then -
    raise syntax 93.900 array('ARCH_READINESS_VERIFIER_REQUIRED')
  if \trustedVerifier~hasMethod('verifyArchitectureServiceGate') then -
    raise syntax 93.900 array('ARCH_READINESS_VERIFIER_API_REQUIRED')
  gate = gates[gateId]
  if gate['status'] == 'VERIFIED_EVIDENCE' then -
    raise syntax 93.900 array('ARCH_READINESS_PROOF_ALREADY_ADMITTED')
  verdict = trustedVerifier~verifyArchitectureServiceGate( -
    projectId, gate['serviceId'], gateId, gate['evidenceAuthority'], -
    .JSON~toJSON(candidateReceipt))
  if \verdict~isA(.Directory) then -
    raise syntax 93.900 array('ARCH_READINESS_VERDICT_SHAPE')
  if verdict['accepted'] \== .JSON~true | -
     verdict['projectId'] \== projectId | -
     verdict['serviceId'] \== gate['serviceId'] | -
     verdict['gateId'] \== gateId | -
     verdict['evidenceAuthority'] \== gate['evidenceAuthority'] then -
    raise syntax 93.900 array('ARCH_READINESS_PROOF_DENIED')
  if verdict['proofRef'] == .nil | verdict['evidenceRef'] == .nil then -
    raise syntax 93.900 array('ARCH_READINESS_PROOF_MISSING')
  if verdict['proofRef']~string~strip == '' | -
     verdict['evidenceRef']~string~strip == '' then -
    raise syntax 93.900 array('ARCH_READINESS_PROOF_MISSING')
  /* Only public, attributed references leave this authority boundary. */
  gate['status'] = 'VERIFIED_EVIDENCE'
  gate['proofRef'] = verdict['proofRef']
  gate['evidenceRef'] = verdict['evidenceRef']
  return self~projection

::method projection
  expose projectId gates order
  services = .Directory~new
  allGates = .Array~new
  do i = 1 to order~items
    g = gates[order[i]]
    serviceId = g['serviceId']
    if \services~hasIndex(serviceId) then do
      s = .Directory~new
      s['serviceId'] = serviceId
      s['totalGates'] = 0
      s['verifiedGates'] = 0
      s['status'] = 'DESIGN_REQUIRES_PROOF'
      s['missingGateIds'] = .Array~new
      services[serviceId] = s
    end
    s = services[serviceId]
    s['totalGates'] = s['totalGates'] + 1
    if g['status'] == 'VERIFIED_EVIDENCE' then -
      s['verifiedGates'] = s['verifiedGates'] + 1
    else s['missingGateIds']~append(g['gateId'])
    allGates~append(g)
  end
  names = services~allIndexes
  total = 0
  completed = 0
  do n over names
    s = services[n]
    total = total + 1
    if s['verifiedGates'] == s['totalGates'] & s['totalGates'] > 0 then do
      s['status'] = 'EVIDENCE_COMPLETE_OPERATOR_REVIEW_REQUIRED'
      completed = completed + 1
    end
  end
  p = .Directory~new
  p['schema'] = 'alchemy.architecture.service-readiness/0.1'
  p['projectId'] = projectId
  p['services'] = services
  p['gates'] = allGates
  p['serviceCount'] = total
  p['evidenceCompleteServiceCount'] = completed
  p['status'] = 'DESIGN_ONLY_NO_LIVE_ACTIVATION'
  p['buildLock'] = .nil
  p['deploymentReceipt'] = .nil
  p['activationRequested'] = .JSON~false
  p['executable'] = .JSON~false
  return .JSON~fromJSON(.JSON~toJSON(p))

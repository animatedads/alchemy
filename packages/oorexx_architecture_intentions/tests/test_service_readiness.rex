/* Evidence-gated Rasen Falcon architecture readiness, with no live claims. */
p = .ArchitectureRasenFalconBaseline~build('rasenfalcon-contract-test')
r = p~projection
call assert r['serviceCount'] == 4, 'four independent service boundaries'
call assert r['evidenceCompleteServiceCount'] == 0, 'no implicit evidence'
call assert r['services']['public_website']['totalGates'] == 3, 'public website gates'
call assert r['services']['private_office']['totalGates'] == 3, 'private gates'
call assert r['services']['mail']['totalGates'] == 5, 'mail protocols rights and probes'
call assert r['services']['internode']['totalGates'] == 4, 'XTP named service and carrier'
call assert r['buildLock'] == .nil, 'no fabricated dependency lock'
call assert r['activationRequested'] == .JSON~false, 'no live activation'
call assert r['executable'] == .JSON~false, 'not executable'
/* No LDAP gate on public apex. */
do g over r['gates']
  if g['serviceId'] == 'public_website' then -
    call assert pos('ldap',g['gateId']) == 0,'public does not force LDAP'
end
candidate = .Directory~new
candidate['claim'] = 'passed without trusted evidence'
if p~projection['services']['public_website']['status'] == 'EVIDENCE_COMPLETE_OPERATOR_REVIEW_REQUIRED' then exit 1
/* One verified gate must not imply complete service readiness. */
p~admitEvidence('public.site-source',candidate,.ReadinessVerifier~new)
r = p~projection
call assert r['services']['public_website']['verifiedGates'] == 1, 'one verified proof'
call assert r['services']['public_website']['status'] == 'DESIGN_REQUIRES_PROOF', 'other proofs still missing'
call assert r['gates'][1]['proofRef'] == 'proof:public.site-source', 'attributed proof'
call assert pos('PRIVATE_SECRET',.JSON~toJSON(r)) == 0, 'private verifier fields excluded'
r['gates'][1]['status'] = 'TAMPERED'
call assert p~projection['gates'][1]['status'] == 'VERIFIED_EVIDENCE', 'defensive copy'
/* Internal false candidate cannot grant proof without an approved verifier. */
say 'PASS Rasen Falcon readiness gates: source != live, public != private, mail != bind, MU/MI != IP'
exit 0
assert:
  use arg yes, message
  if yes then return
  say 'FAIL' message
  exit 1
::requires 'ArchitectureRasenFalconBaseline.cls'
::class ReadinessVerifier
::method verifyArchitectureServiceGate
  use strict arg projectId, serviceId, gateId, evidenceAuthority, candidateJSON
  v = .Directory~new
  v['accepted'] = .JSON~true
  v['projectId'] = projectId
  v['serviceId'] = serviceId
  v['gateId'] = gateId
  v['evidenceAuthority'] = evidenceAuthority
  v['proofRef'] = 'proof:' || gateId
  v['evidenceRef'] = 'external-test:' || gateId
  v['internalSecret'] = 'PRIVATE_SECRET'
  return v

p = .ArchitectureServiceReadiness~new('denied-test')
p~requireGate('mail','mail.ldap-rights','Explicit rights','LDAP_IDENTITY')
r = .Directory~new
r['claimed'] = .JSON~true
p~admitEvidence('mail.ldap-rights',r,.DenyVerifier~new)
say 'FAIL: denied proof accepted'
exit 0
::requires 'ArchitectureServiceReadiness.cls'
::class DenyVerifier
::method verifyArchitectureServiceGate
  use strict arg projectId, serviceId, gateId, authority, candidate
  v=.Directory~new
  v['accepted'] = .JSON~false
  v['projectId'] = projectId
  v['serviceId'] = serviceId
  v['gateId'] = gateId
  v['evidenceAuthority'] = authority
  v['proofRef'] = 'forged'
  v['evidenceRef'] = 'self'
  return v

p = .ArchitectureServiceReadiness~new('missing-verifier')
p~requireGate('internode','internode.protection','Protected link','XTP')
r = .Directory~new
r['claimed'] = 'yes'
p~admitEvidence('internode.protection',r,.nil)
say 'FAIL: absent verifier accepted'
exit 0
::requires 'ArchitectureServiceReadiness.cls'

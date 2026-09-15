now = .DateTime~new
release = .InstitutionalPolicyRelease~new('CUSTOMER-CARE-POLICY','4.2',now,.nil,'POLICY_ENGINEERING','OPERATIONS_BOARD','4.1',.nil,'sha256:example-policy-artifact')~seal
say 'policy=' release~policyId || '@' || release~version
say 'execution=' release~executionModel
say 'approvedBy=' release~approvedBy
say 'identity:'
say release~semanticIdentity
::requires 'InstitutionalPolicy.cls'

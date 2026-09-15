p=.FederationBankIntermediaryPolicyFixtures~standardPolicy
now=.DateTime~new
release=.RIDInstitutionalPolicyBridge~release(p,now - .TimeSpan~new(0,0,0,0,60))
.RIDTestSupport~assertEq(p~policyId,release~policyId)
.RIDTestSupport~assertEq(p~semanticIdentity,release~payloadIdentity)
cat=.InstitutionalPolicyCatalog~new
.RIDTestSupport~ok(cat~publish(release))
r=.RIDInstitutionalPolicyBridge~resolvePayload(cat,p~policyId,now)
.RIDTestSupport~ok(r)
.RIDTestSupport~assertEq(p~semanticIdentity,r~value~semanticIdentity)
say "PASS Institutional Policy bridge"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "FederationBankIntermediaryPolicyFixtures.cls"
::requires "RIDInstitutionalPolicyBridge.cls"
::requires "TestSupport.cls"

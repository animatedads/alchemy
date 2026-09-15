/* Prove Legal Effect remains domain-owned while an actually compiler-certified
   LegalRuleGeneration can be promoted as an institutional deployment artefact. */
fixture = .DemoLegalRules~new
gen = fixture~legalGeneration
call assertTrue gen~publicationEligible,'legal compiler-certified generation publishable in its own domain'
now = .DateTime~new
release = .InstitutionalPolicyRelease~new('LEGAL-DEPLOYMENT','12.0',now,.nil,'LEGAL_COMPILER','LEGAL_APPROVER','',gen,gen~semanticIdentity)~seal
call assertTrue release~payload == gen,'rich LegalRuleGeneration retained'
call assertEqual gen~semanticIdentity,release~payloadIdentity,'exact legal semantic identity retained'
call assertTrue release~publicationEligible,'institutional release also publishable'

catalog = .InstitutionalPolicyCatalog~new
call assertTrue catalog~publish(release)~ok,'certified legal generation publishes through common lifecycle'
call assertTrue catalog~resolve('LEGAL-DEPLOYMENT',now)~value~payload == gen,'resolved release retains exact legal generation object'

say 'PASS test_legal_release_bridge'
exit 0
assertTrue: procedure
  use arg value,label
  if value = .false then do; say 'FAIL:' label; exit 1; end
  return
assertEqual: procedure
  use arg expected,actual,label
  if expected <> actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
::requires 'InstitutionalPolicy.cls'
::requires 'DemoLegalRules_v2.cls'

ring=.CryptoMacKeyRing~new; ring~addKey('gov-alchemy','00112233445566778899aabbccddeeff')
sealer=.AlchemyMacSealer~new(ring); authority=.AlchemyCapabilityAuthority~new(ring)
s=.GovernanceFixture~study('ALCH')
b=.BrandInterventionGovernanceEvidenceBinding~new('B-ALCH',s,'2026-08-24',2,'PRIVATE-CLOCK-AUTH'); b~seal
rules=.GovernanceFixture~rules
r=.BrandInterventionGovernanceEngine~new~recommend(b,rules,sealer,authority)~value
call assertTrue r~isA(.AlchemyObject),'recommendation inherits AlchemyObject'
cap=authority~issue('tenant',r~alchemyObjectId,'SEALEDINTROSPECTION','INTROSPECT:CUSTOMER'); env=r~sealedIntrospection('CUSTOMER',cap); call assertTrue sealer~verify(env),'introspection verifies'
state=env~payload['state']
call assertTrue state~hasIndex('DISPOSITION'),'disposition visible'
call assertTrue state~hasIndex('EVIDENCESTATUS'),'evidence status visible'
call assertTrue state~hasIndex('APPLIEDEXPOSUREPCT'),'denominator-derived exposure visible'
call assertFalse state~hasIndex('BINDING'),'full evidence object remains internal'
call assertFalse state~hasIndex('EVIDENCEPOINTS'),'case refs remain internal'
say 'PASS test_alchemy_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'TestGovernanceFixtures.cls'
::requires 'BrandInterventionGovernance.cls'
::requires 'AlchemySecurity.cls'

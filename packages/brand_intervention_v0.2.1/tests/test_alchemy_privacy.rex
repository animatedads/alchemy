ring=.CryptoMacKeyRing~new; ring~addKey('intervention-alchemy','00112233445566778899aabbccddeeff')
sealer=.AlchemyMacSealer~new(ring); authority=.AlchemyCapabilityAuthority~new(ring)
c=.BrandInterventionContext~new('safe','BRAND_JOURNEY:J7','2026-08-23T12:00:00Z','SUPPORT','UNRESOLVED',.true,'FRUSTRATED',60,.false,sealer,authority); c~addFinding('CUSTOMER_REPEAT_BURDEN'); c~addBrandFunction('PROMOTIONAL_WORK'); c~addEvidencePoint('BRAND_JOURNEY:ASSESSMENT:A'); c~seal
call assertTrue c~isA(.AlchemyObject),'context inherits AlchemyObject'
cap=authority~issue('tenant',c~alchemyObjectId,'SEALEDINTROSPECTION','INTROSPECT:CUSTOMER'); env=c~sealedIntrospection('CUSTOMER',cap); call assertTrue sealer~verify(env),'introspection verifies'
state=env~payload['state']; call assertTrue state~hasIndex('ASSESSEDSENTIMENT'),'assessed sentiment visible'; call assertTrue state~hasIndex('BRANDFUNCTIONS'),'brand function visible'; call assertFalse state~hasIndex('JOURNEYPOINT'),'upstream evidence ref internal'
/* Free prose/customer data cannot enter evidence point field. */
c2=.BrandInterventionContext~new('safe2','BRAND_JOURNEY:J8','2026-08-23T12:00:00Z','SUPPORT'); call assertFalse c2~addEvidencePoint('Barbie Example at 12 Private Road'),'unsafe prose rejected'
say 'PASS test_alchemy_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandIntervention.cls'
::requires 'AlchemySecurity.cls'

ring=.CryptoMacKeyRing~new; ring~addKey('population-alchemy','00112233445566778899aabbccddeeff')
sealer=.AlchemyMacSealer~new(ring); authority=.AlchemyCapabilityAuthority~new(ring)
o=.BrandJourneyPopulationObservation~new('safe-o','BRAND_JOURNEY:safe-j','2026-08-23T10:00:00Z','SUPPORT_TO_BILLING','ABANDONMENT',.true,30,'JV3','JT1','PROC','MODEL',sealer,authority); o~addExposure('CUSTOMER_REPEAT_BURDEN'); o~setMateriality(90,2400000); call assertFalse o~addEvidencePoint('Barbie Example at 12 Private Road'),'free prose cannot hide in evidence point'; o~addEvidencePoint('BRAND_JOURNEY:ASSESSMENT:safe'); o~seal
call assertTrue o~isA(.AlchemyObject),'observation inherits AlchemyObject'
cap=authority~issue('tenant',o~alchemyObjectId,'SEALEDINTROSPECTION','INTROSPECT:CUSTOMER'); env=o~sealedIntrospection('CUSTOMER',cap); call assertTrue sealer~verify(env),'customer introspection verifies'
state=env~payload['state']; call assertTrue state~hasIndex('CLASSIFICATION'),'classification visible'; call assertTrue state~hasIndex('EXPOSURES'),'privacy-safe exposure visible'; call assertFalse state~hasIndex('COMMERCIALVALUEATRISK'),'internal commercial value hidden'
text=o~canonicalText; call assertTrue text~pos('CUSTOMER_REPEAT_BURDEN')>0,'semantic residue retained'; call assertEqual 0,text~pos('2400000'),'commercial value absent from customer canonical observation'
say 'PASS test_alchemy_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e\==a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'BrandJourneyPopulation.cls'
::requires 'AlchemySecurity.cls'

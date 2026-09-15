ring=.CryptoMacKeyRing~new; ring~addKey('eff-alchemy','00112233445566778899aabbccddeeff')
sealer=.AlchemyMacSealer~new(ring); authority=.AlchemyCapabilityAuthority~new(ring)
a=.BrandInterventionEffectivenessAggregate~new('safe','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-21',21,2000,1000,30,1000,80,86400,'OBSERVATIONAL','PRIVATE-ASSIGNMENT-AUTH','JCLASS','JTAX','PROC','MODEL',sealer,authority); a~addSupportPoint('BRAND_INTERVENTION:OUTCOME:O1'); a~seal
call assertTrue a~isA(.AlchemyObject),'aggregate inherits AlchemyObject'
cap=authority~issue('tenant',a~alchemyObjectId,'SEALEDINTROSPECTION','INTROSPECT:CUSTOMER'); env=a~sealedIntrospection('CUSTOMER',cap); call assertTrue sealer~verify(env),'introspection verifies'
state=env~payload['state']; call assertTrue state~hasIndex('ELIGIBLECOUNT'),'denominator visible'; call assertTrue state~hasIndex('ASSIGNMENTMETHOD'),'study design visible'; call assertFalse state~hasIndex('ASSIGNMENTAUTHORITYID'),'assignment authority remains internal'; call assertFalse state~hasIndex('SUPPORTPOINTS'),'case evidence refs remain internal'
say 'PASS test_alchemy_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'
::requires 'AlchemySecurity.cls'

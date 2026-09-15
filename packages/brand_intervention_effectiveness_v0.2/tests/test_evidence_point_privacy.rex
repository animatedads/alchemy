a=.BrandInterventionEffectivenessAggregate~new('p','SERVICE_RECOVERY_GUIDANCE','CANCELLATION','DECREASE','PRIMARY','SUPPORT','2026-08-01','2026-08-21',21,2000,1000,30,1000,80)
call assertFalse a~addSupportPoint('Barbie Example at 12 Private Road'),'free prose/customer data rejected from evidence-point channel'
call assertTrue a~addSupportPoint('BRAND_INTERVENTION:OUTCOME:O1'),'opaque stable point accepted'
a~seal
say 'PASS test_evidence_point_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInterventionEffectiveness.cls'

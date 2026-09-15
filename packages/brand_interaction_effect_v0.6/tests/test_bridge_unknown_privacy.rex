parse arg interactionRoot
if interactionRoot='' then do; say 'SKIP interaction root'; exit 0; end
/* UNKNOWN content may contain plausible semantic metadata.  The bridge must
   fail closed and not turn transformation into a privacy downgrade. */
m=.table~new; m['PRIMARY_PURPOSE']='SALESPROP'; m['ROLES']='SALESPROP,CUSTOMER_REFERENCE'
e=.InteractionEvent~new('u1','AGENT_UTTERANCE',.nil,'CHAT','chat.out','OUTBOUND')
e~addContent(.InteractionContentElement~new('seg-u','UTTERANCE_SEGMENT','private generated wording','UNKNOWN','','RETAIN','MODEL_GENERATED','','',100,m))
e~seal
r=.BrandInteractionEventBridge~fromEvent(e); call assertTrue r~ok,'bridge runs'
o=r~value
call assertFalse o~hasPurpose('SALESPROP'),'unknown segment metadata dropped'
call assertFalse o~hasPurpose('CUSTOMER_REFERENCE'),'unknown roles dropped'
say 'PASS test_bridge_unknown_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'
::requires 'InteractionEvent.cls'

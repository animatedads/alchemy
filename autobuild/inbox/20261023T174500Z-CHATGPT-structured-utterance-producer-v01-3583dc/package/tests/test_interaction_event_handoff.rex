p=.StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-EVENT-1','UTT-EVENT-1','AGENT','CHAT','CUSTOMER-TURN-1','ORCHESTRATOR','APP','PROVIDER:INV:5','MODEL:5','RESPONSE:PLAN:5')
ctx=.StructuredUtteranceSegment~new('ctx','recovery context','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
ctx~addLineage(.UtteranceLineageEdge~new('le1','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER:FACT:RECOVERY','CUSTOMER_SENSITIVE'));plan~addSegment(ctx)
sale=.StructuredUtteranceSegment~new('sale','Would you like an extra bag?','SALESPROP','NONE','DERIVED_NONCUSTOMER','', 'RETAIN',d2c(10));plan~addSegment(sale)
act=.UtteranceCommunicativeAct~new('a1','SALESPROP');act~addSegmentId('sale');plan~addAct(act)
use=.UtteranceInformationUseEdge~new('ue1','ctx','le1','a1','JUSTIFICATION','SUPPORTIVE_CONTEXT');plan~addInformationUse(use)
intent=.UtteranceGenerationIntent~new('i1','a1','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE');intent~addInformationUseId('ue1');plan~addGenerationIntent(intent)
call assertTrue plan~seal~ok,'plan seals'
pr=p~produce(plan);call assertTrue pr~ok,'producer succeeds'
br=.StructuredUtteranceInteractionBridge~toEvent(pr~value~utterance,'EVENT-PRODUCER-1','TEST.PRE_FLATTENING')
call assertTrue br~ok,'Structured Utterance -> Interaction Event bridge succeeds'
e=br~value
call assertEqual 1,e~informationUses~items,'native information use crosses handoff'
call assertEqual 'COMMERCIAL_PERSUASION',e~informationUses[1]~effectiveUse,'realised use survives'
call assertEqual 1,e~generationIntents~items,'generation intent crosses handoff'
call assertEqual 'OFFER_EXTRA_BAG',e~generationIntents[1]~intendedAct,'pre-flattening intent survives'
call assertTrue e~derivedFindings~items >= 1,'derived structured evidence survives'
say 'PASS test_interaction_event_handoff'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'
::requires 'StructuredUtteranceInteractionBridge.cls'

ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('bridge-v02','AGENT','CHAT','customer-risk',ctx)
u~addCorrelation('journey-v02')
s=.StructuredUtteranceSegment~new('s1','whatever helps the recovery process','SALESPROP','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
s~addLineage(.UtteranceLineageEdge~new('le1','DERIVED_FROM_CUSTOMER_FACT','PROMPT:fact:recovery','CUSTOMER_SENSITIVE'))
call assertTrue s~seal~ok,'segment seals';u~addSegment(s)
a=.UtteranceCommunicativeAct~new('a1','SALESPROP');a~addSegmentId('s1');call assertTrue a~seal~ok,'act seals';u~addAct(a)
ue=.UtteranceInformationUseEdge~new('ue1','s1','le1','a1','JUSTIFICATION','SALES_JUSTIFICATION');ue~seal;u~addInformationUse(ue)
i=.UtteranceGenerationIntent~new('i1','a1','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE');i~addInformationUseId('ue1');i~seal;u~addGenerationIntent(i)
call assertTrue u~seal~ok,'utterance seals'
br=.StructuredUtteranceInteractionBridge~toEvent(u,'event-v02','TEST.POST_RENDER')
call assertTrue br~ok,'bridge succeeds';e=br~value
call assertTrue hasToken(e~tags,'STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'finding tag exported'
call assertTrue hasToken(e~tags,'STRUCTURED_INTENT/OFFER_EXTRA_BAG'),'intent tag exported'
meta=e~content[1]~metadata
call assertTrue meta['INFORMATION_USES']~pos('EFFECTIVE=COMMERCIAL_PERSUASION')>0,'effective use metadata exported'
call assertTrue meta['GENERATION_INTENTS']~pos('OFFER_EXTRA_BAG')>0,'intent metadata exported'
lib=.InteractionCaptureLibrary~new;call assertTrue lib~captureEvent(e)~ok,'event captured'
pr=lib~projectEvent('event-v02');call assertTrue pr~ok,'projection succeeds'
text='';do ce over pr~value~content;text||='|'||ce~value;end
call assertTrue text~pos('recovery process')=0,'sensitive sales rationale removed from analytic projection'
call assertTrue text~pos('[CUSTOMER_SENSITIVE_CONTEXT]')>0,'abstraction survives'
say 'PASS test_interaction_bridge_v02'
exit 0
hasToken: procedure; use arg arr,w; do x over arr; if x=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtteranceInteractionBridge.cls'

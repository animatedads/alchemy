ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('bridge-v03','AGENT','CHAT','customer-risk',ctx)
u~addCorrelation('journey-v03')
context=.StructuredUtteranceSegment~new('ctx1','supporting recovery','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
context~addLineage(.UtteranceLineageEdge~new('le1','DERIVED_FROM_CUSTOMER_FACT','PROMPT:fact:recovery','CUSTOMER_SENSITIVE'))
call assertTrue context~seal~ok,'context segment seals';u~addSegment(context)
sale=.StructuredUtteranceSegment~new('s1','Would you like to add an extra bag?','SALESPROP','NONE','PUBLIC','','RETAIN')
call assertTrue sale~seal~ok,'sale segment seals';u~addSegment(sale)
a=.UtteranceCommunicativeAct~new('a1','SALESPROP');a~addSegmentId('s1');call assertTrue a~seal~ok,'act seals';u~addAct(a)
ue=.UtteranceInformationUseEdge~new('ue1','ctx1','le1','a1','JUSTIFICATION','SUPPORTIVE_CONTEXT','MODEL','GROK',98);ue~seal;u~addInformationUse(ue)
i=.UtteranceGenerationIntent~new('i1','a1','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE','MODEL','GROK',97);i~addInformationUseId('ue1');i~seal;u~addGenerationIntent(i)
call assertTrue u~seal~ok,'utterance seals'
br=.StructuredUtteranceInteractionBridge~toEvent(u,'event-v03','TEST.POST_RENDER')
call assertTrue br~ok,'bridge succeeds';e=br~value
call assertEqual 1,e~informationUses~items,'native information use exported'
call assertEqual 'CUSTOMER_SENSITIVE',e~informationUses[1]~sourcePrivacyClass,'native source privacy exported'
call assertEqual 'COMMERCIAL_PERSUASION',e~informationUses[1]~effectiveUse,'native effective use exported'
call assertEqual 'JUSTIFICATION',e~informationUses[1]~relationRole,'native relation exported'
call assertEqual 1,e~generationIntents~items,'native generation intent exported'
call assertEqual 'OFFER_EXTRA_BAG',e~generationIntents[1]~intendedAct,'native intended act exported'
call assertEqual 2,e~derivedFindings~items,'native findings exported'
call assertTrue hasFinding(e~derivedFindings,'SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'native repurposing finding exported'
call assertTrue hasFinding(e~derivedFindings,'DECLARED_INFORMATION_USE_MISMATCH'),'native declared-use mismatch exported'
call assertTrue hasToken(e~tags,'STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'compatibility finding tag retained'
lib=.InteractionCaptureLibrary~new;call assertTrue lib~captureEvent(e)~ok,'event captured'
pr=lib~projectEvent('event-v03');call assertTrue pr~ok,'projection succeeds';p=pr~value
call assertEqual 1,p~informationUses~items,'projected native use evidence survives'
call assertEqual 1,p~generationIntents~items,'projected native intent survives'
call assertEqual 2,p~derivedFindings~items,'projected native findings survive'
text='';do ce over p~content;text||='|'||ce~value;end
call assertTrue text~pos('supporting recovery')=0,'raw sensitive source prose removed from projection'
call assertTrue text~pos('[CUSTOMER_SENSITIVE_CONTEXT]')>0,'sensitive context abstraction survives'
call assertTrue text~pos('Would you like to add an extra bag?')>0,'generic sale survives projection'
say 'PASS test_interaction_bridge_v03'
exit 0
hasToken: procedure; use arg arr,w; do x over arr; if x=w then return .true; end; return .false
hasFinding: procedure; use arg arr,w; do x over arr; if x~code=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceInteractionBridge.cls'

e=.InteractionEvent~new('event-native','AGENT_UTTERANCE',.nil,'CHAT','TEST.POST_RENDER','OUTBOUND')
use=.InteractionInformationUseEvidence~new('use-1','ctx1','prompt:fact:recovery','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_SENSITIVE','act-1','SALESPROP','JUSTIFICATION','SUPPORTIVE_CONTEXT','COMMERCIAL_PERSUASION','MODEL','GROK',97)
call assertTrue e~addInformationUse(use),'native information use attaches'
call assertTrue use~sealed,'information use seals on attachment'
call assertEqual 'COMMERCIAL_PERSUASION',e~informationUses[1]~effectiveUse,'effective use retained'
call assertEqual 'CUSTOMER_SENSITIVE',e~informationUses[1]~sourcePrivacyClass,'privacy floor retained'
intent=.InteractionGenerationIntentEvidence~new('intent-1','act-1','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE','MODEL','GROK','',96)
call assertTrue intent~addInformationUseRef('use-1'),'intent use ref attaches'
call assertTrue e~addGenerationIntent(intent),'native generation intent attaches'
call assertTrue intent~sealed,'intent seals on attachment'
call assertTrue \intent~addInformationUseRef('use-2'),'sealed intent rejects mutation'
f=.InteractionDerivedFinding~new('finding-1','SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING','STRUCTURED_UTTERANCE','SU-ANALYZER',95)
call assertTrue f~addEvidenceRef('use-1'),'finding evidence ref attaches'
call assertTrue e~addDerivedFinding(f),'native finding attaches'
call assertTrue f~sealed,'finding seals on attachment'
call assertEqual 'INTERACTION_INFORMATION_USE:USE-1',use~pointId,'use point stable'
call assertEqual 'INTERACTION_GENERATION_INTENT:INTENT-1',intent~pointId,'intent point stable'
call assertEqual 'INTERACTION_DERIVED_FINDING:FINDING-1',f~pointId,'finding point stable'
e~seal
call assertTrue \e~addDerivedFinding(.InteractionDerivedFinding~new('finding-2','SHOULD_NOT_ATTACH')),'sealed event rejects native evidence'
lib=.InteractionCaptureLibrary~new
call assertTrue lib~captureEvent(e)~ok,'event captures'
pr=lib~projectEvent('event-native')
call assertTrue pr~ok,'projection succeeds';p=pr~value
call assertEqual 1,p~informationUses~items,'projected use evidence survives'
call assertEqual 1,p~generationIntents~items,'projected intent survives'
call assertEqual 1,p~derivedFindings~items,'projected finding survives'
call assertEqual '',p~informationUses[1]~sourceRef,'customer-sensitive source ref removed'
call assertEqual 'CUSTOMER_SENSITIVE',p~informationUses[1]~sourcePrivacyClass,'privacy class survives projection'
call assertEqual 'COMMERCIAL_PERSUASION',p~informationUses[1]~effectiveUse,'safe use semantics survive projection'
call assertTrue expectSyntaxProse(),'prose cannot hide in native token field'
say 'PASS test_native_structured_evidence'
exit 0
expectSyntaxProse: procedure
  signal on syntax name caught
  x=.InteractionInformationUseEvidence~new('use-bad','ctx','Barbie Example at 12 Private Road','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_SENSITIVE','act','SALESPROP','JUSTIFICATION','SUPPORTIVE_CONTEXT','COMMERCIAL_PERSUASION')
  return .false
caught:
  return .true
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'InteractionEvent.cls'

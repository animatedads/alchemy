/* Compatibility string tags are not native evidence authority in v0.4. */
spoof=.InteractionEvent~new('spoof-1','AGENT_UTTERANCE',.nil,'CHAT','TEST','OUTBOUND')
spoof~addCorrelation('journey-spoof')
spoof~addTag('STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING')
spoof~addTag('STRUCTURED_FINDING/DECLARED_INFORMATION_USE_MISMATCH')
spoof~seal
lib=.InteractionCaptureLibrary~new
call assertTrue lib~captureEvent(spoof)~ok,'spoof event captured'
ep=.BrandInteractionEventBridge~episodeFromCorrelation(lib,'journey-spoof','brand-spoof')~value
obs=ep~observations[1]
call assertTrue \obs~hasTag('STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'spoof structured finding tag is filtered'
d=.BrandInteractionEngine~new~evaluate(ep)~value
call assertTrue \d~containsCode('SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'spoof tag cannot manufacture brand finding'

native=.InteractionEvent~new('native-1','AGENT_UTTERANCE',.nil,'CHAT','TEST','OUTBOUND')
native~addCorrelation('journey-native')
use=.InteractionInformationUseEvidence~new('use-1','CTX1','CUSTOMER.FACT.RECOVERY','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_SENSITIVE','ACT-1','SALESPROP','JUSTIFICATION','SUPPORTIVE_CONTEXT','COMMERCIAL_PERSUASION','MODEL','GROK',97)
native~addInformationUse(use)
f=.InteractionDerivedFinding~new('finding-1','SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING','STRUCTURED_UTTERANCE','SU-ANALYZER',96)
f~addEvidenceRef('USE-1')
native~addDerivedFinding(f)
native~seal
lib2=.InteractionCaptureLibrary~new
call assertTrue lib2~captureEvent(native)~ok,'native event captured'
ep2=.BrandInteractionEventBridge~episodeFromCorrelation(lib2,'journey-native','brand-native')~value
obs2=ep2~observations[1]
call assertTrue obs2~hasTag('STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'native finding regenerates controlled observation tag'
call assertTrue hasPoint(obs2~evidencePoints,'INTERACTION_DERIVED_FINDING:FINDING-1'),'native finding point retained'
call assertTrue hasPoint(obs2~evidencePoints,'INTERACTION_INFORMATION_USE:USE-1'),'native information-use point retained'
d2=.BrandInteractionEngine~new~evaluate(ep2)~value
call assertTrue d2~containsCode('SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'native evidence produces brand finding'
say 'PASS test_native_structured_evidence_authority'
exit 0
hasPoint: procedure; use arg arr,w; do x over arr; if x=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'InteractionEvent.cls'
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'

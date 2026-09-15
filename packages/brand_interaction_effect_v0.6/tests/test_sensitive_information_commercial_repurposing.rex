/* End-to-end: Structured Utterance v0.2 preserves a customer-sensitive
   information-use edge, Interaction Event carries only privacy-bounded content
   plus controlled finding tags, and Brand Interaction Effect consumes the tag
   without re-parsing the customer's raw text. */
ctx=.BrandExperienceContext~serviceAsSales
ctx~addDomain('SECURITY'); ctx~addOpportunity('REPUTATIONAL_RISK')
u=.StructuredUtterance~new('grok-sensitive-sale','AGENT','CHAT','customer-risk',ctx)
u~addContextTag('SECURITY_SENSITIVE_SERVICE_INTERACTION'); u~addCorrelation('journey-sensitive-sale')

w=.StructuredUtteranceSegment~new('warn','I cannot advise you on how to do anything illegal.','WARNLAW')
w~addRole('REFUSE_ILLEGAL_ASSISTANCE'); call assertTrue w~seal~ok,'warning seals'; u~addSegment(w)
wa=.UtteranceCommunicativeAct~new('act-warn','WARNLAW');wa~addSegmentId('warn');call assertTrue wa~seal~ok,'warning act seals';u~addAct(wa)

s=.StructuredUtteranceSegment~new('sale','whatever helps the recovery process','SALESPROP','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY',d2c(10))
le=.UtteranceLineageEdge~new('le-sale','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_PROMPT:fact:substance-use-recovery','CUSTOMER_SENSITIVE')
s~addLineage(le);call assertTrue s~seal~ok,'sensitive sales segment seals';u~addSegment(s)
sa=.UtteranceCommunicativeAct~new('act-sale','SALESPROP');sa~addSegmentId('sale');call assertTrue sa~seal~ok,'sale act seals';u~addAct(sa)
ue=.UtteranceInformationUseEdge~new('use-sale','sale','le-sale','act-sale','JUSTIFICATION','SUPPORTIVE_CONTEXT');ue~seal;u~addInformationUse(ue)
intent=.UtteranceGenerationIntent~new('intent-sale','act-sale','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE');intent~addInformationUseId('use-sale');intent~seal;u~addGenerationIntent(intent)
call assertTrue u~seal~ok,'structured utterance seals'

br=.StructuredUtteranceInteractionBridge~toEvent(u,'event-sensitive-sale','SHANNON.POST_RENDER')
call assertTrue br~ok,'structured->interaction bridge succeeds'
e=br~value
call assertTrue hasToken(e~tags,'STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'interaction carries sensitive commercial repurposing point'
call assertTrue hasToken(e~tags,'STRUCTURED_FINDING/DECLARED_INFORMATION_USE_MISMATCH'),'interaction carries declared-use mismatch point'

lib=.InteractionCaptureLibrary~new;call assertTrue lib~captureEvent(e)~ok,'interaction captured'
projected=lib~projectEvent('event-sensitive-sale');call assertTrue projected~ok,'deidentified event projection succeeds'
text='';do ce over projected~value~content;text||='|'||ce~value;end
call assertTrue text~pos('recovery process')=0,'brand path does not need raw sensitive sales wording'

ep=.BrandInteractionEventBridge~episodeFromCorrelation(lib,'journey-sensitive-sale','brand-sensitive-sale')~value
engine=.BrandInteractionEngine~new
decisionResult=engine~evaluate(ep);call assertTrue decisionResult~ok,'brand evaluation succeeds';d=decisionResult~value
call assertTrue d~containsCode('SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'brand finding consumes structured evidence'
call assertTrue d~containsCode('DECLARED_INFORMATION_USE_MISMATCH'),'brand finding exposes declared/effective mismatch'
call assertEqual 'HOLD',d~disposition,'high-signal sensitive commercial use reaches hold'
call assertTrue .BrandInteractionExplainer~concise(d)~pos('Customer-sensitive information')>0,'concise explanation uses structured finding'
call assertTrue engine~isA(.AlchemyObject),'brand engine inherits AlchemyObject'
call assertTrue engine~checkSurfaceContract~ok,'brand engine Alchemy method surface contract passes'
call assertTrue engine~alchemyMetrics['use_count']>=1,'brand evaluation recorded inherited lifecycle telemetry'

say 'PASS test_sensitive_information_commercial_repurposing'
exit 0
hasToken: procedure; use arg arr,w; do x over arr; if x=w then return .true; end; return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'
::requires 'StructuredUtteranceInteractionBridge.cls'
::requires 'InteractionEvent.cls'
::requires 'BrandInteractionEffect.cls'
::requires 'BrandInteractionEventBridge.cls'

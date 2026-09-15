ctx = .BrandExperienceContext~serviceAsSales
u = .StructuredUtterance~new('bridge-u1','AGENT','CHAT','customer-msg-1',ctx)
u~addCorrelation('journey-b1')
s1 = .StructuredUtteranceSegment~new('s1','Would ','SALESPROP')
call assertTrue s1~seal~ok, 'prefix seals'; u~addSegment(s1)
s2 = .StructuredUtteranceSegment~new('s2','Barbie','SALESPROP','CUSTNAME','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY')
s2~addLineage(.UtteranceLineageEdge~new('le2','COPIED_FROM_CUSTOMER','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC'))
call assertTrue s2~seal~ok, 'name seals'; u~addSegment(s2)
s3 = .StructuredUtteranceSegment~new('s3',' like an extra bag?','SALESPROP')
call assertTrue s3~seal~ok, 'suffix seals'; u~addSegment(s3)
call assertTrue u~seal~ok, 'utterance seals'

br = .StructuredUtteranceInteractionBridge~toEvent(u,'event-u1','SHANNON.POST_RENDER')
call assertTrue br~ok, 'bridge creates event'
e = br~value
call assertTrue e~sealed, 'interaction event sealed'
call assertEqual 'AGENT_UTTERANCE', e~eventKind, 'event kind'
call assertTrue hasToken(e~tags,'EXPLICIT_SALES_PROPOSITION'), 'explicit sales tag retained'
call assertTrue hasToken(e~tags,'BRAND_FUNCTION/PROMOTIONAL_WORK'), 'brand promotional tag retained'
call assertEqual 3, e~content~items, 'segments preserved as event content elements'

lib = .InteractionCaptureLibrary~new
call assertTrue lib~captureEvent(e)~ok, 'bridged event captured'
pr = lib~projectEvent('event-u1')
call assertTrue pr~ok, 'interaction projection succeeds'
text = ''
do ce over pr~value~content; text ||= '|' || ce~value; end
call assertTrue text~pos('Barbie') = 0, 'interaction deidentification removes name'
call assertTrue text~pos('[CUSTOMER_RELATED_PERSON]') > 0, 'interaction event receives structured abstraction'

say 'PASS test_interaction_bridge'
exit 0
hasToken: procedure
  use arg arr,wanted
  do x over arr; if x = wanted then return .true; end
  return .false
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceInteractionBridge.cls'

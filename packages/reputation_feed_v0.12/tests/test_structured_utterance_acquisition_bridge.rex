ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('su-1','AGENT','CHAT','customer-request',ctx)
u~addCorrelation('journey-100')
u~addContextTag('UNRESOLVED_SERVICE_FAILURE')
secret=.StructuredUtteranceSegment~new('seg-secret','Barbie has a medical issue','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
secret~addLineage(.UtteranceLineageEdge~new('lineage-secret','DERIVED_FROM_CUSTOMER_FACT','PROMPT:secret','CUSTOMER_SENSITIVE'))
call assertTrue secret~seal~ok,'secret segment seals'; u~addSegment(secret)
sale=.StructuredUtteranceSegment~new('seg-sale','Would you like an extra bag?','SALESPROP','NONE','PUBLIC','','RETAIN')
call assertTrue sale~seal~ok,'sale segment seals'; u~addSegment(sale)
act=.UtteranceCommunicativeAct~new('act-sale','SALESPROP'); act~addSegmentId('seg-sale'); call assertTrue act~seal~ok,'act seals'; u~addAct(act)
useEdge=.UtteranceInformationUseEdge~new('use-secret-sale','seg-secret','lineage-secret','act-sale','JUSTIFICATION','SUPPORTIVE_CONTEXT','MODEL','GROK',98); useEdge~seal; u~addInformationUse(useEdge)
intent=.UtteranceGenerationIntent~new('intent-sale','act-sale','OFFER_EXTRA_BAG','SUPPORTIVE_COMMERCIAL','EXTRA_BAG_PURCHASE','MODEL','GROK',97); intent~addInformationUseId('use-secret-sale'); intent~seal; u~addGenerationIntent(intent)
call assertTrue u~seal~ok,'utterance seals'

bridge=.ReputationFeedStructuredUtteranceBridge~new
packet=bridge~evidenceFromUtterance('packet-su-1','AGENT-CHAT',u,.DateTime~new,'GB')
call assertTrue packet~sealed,'packet sealed'
call assertEqual 'STRUCTURED_UTTERANCE',packet~sourceKind,'source kind retained'
call assertEqual 'STRUCTURED_UTTERANCE:su-1',packet~sourcePointId,'stable utterance point retained'
call assertEqual 2,packet~contentItems~items,'segments remain separate rich evidence items'
call assertTrue containsToken(packet~semanticTokens,'PURPOSE/SALESPROP'),'sale purpose retained structurally'
call assertTrue containsToken(packet~semanticTokens,'INFORMATION_USE/COMMERCIAL_PERSUASION'),'effective information use retained'
call assertTrue containsToken(packet~semanticTokens,'STRUCTURED_FINDING/SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'),'derived finding retained as evidence token'
canonical=packet~canonicalText
call assertNotContains canonical,'Barbie has a medical issue','raw sensitive text must not cross bridge'
call assertNotContains canonical,'PROMPT:secret','raw lineage source reference must not cross bridge'
call assertContains canonical,'[CUSTOMER_SENSITIVE_CONTEXT]','safe abstraction retained'

say 'PASS test_structured_utterance_acquisition_bridge tokens='packet~semanticTokens~items
exit 0
containsToken: procedure
  use arg arr,wanted
  do v over arr; if v= wanted then return .true; end
  return .false
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg text,needle,label; if pos(needle,text)=0 then do; say 'FAIL:' label; exit 1; end; return
assertNotContains: procedure; use arg text,needle,label; if pos(needle,text)>0 then do; say 'FAIL:' label; exit 1; end; return
::requires 'ReputationFeedStructuredUtteranceBridge.cls'

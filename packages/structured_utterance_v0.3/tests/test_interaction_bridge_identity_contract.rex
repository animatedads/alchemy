u=.StructuredUtterance~new('bridge-id-contract')
s=.StructuredUtteranceSegment~new('segment with space','hello','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[SENSITIVE]','ABSTRACT_ONLY')
s~addLineage(.UtteranceLineageEdge~new('lineage with space','DERIVED_FROM_CUSTOMER_FACT','PROMPT:FACT','CUSTOMER_SENSITIVE'))
call assertTrue s~seal~ok,'segment seals';u~addSegment(s)
a=.UtteranceCommunicativeAct~new('act with space','SALESPROP');a~addSegmentId('segment with space');call assertTrue a~seal~ok,'act seals';u~addAct(a)
ue=.UtteranceInformationUseEdge~new('use with space','segment with space','lineage with space','act with space','JUSTIFICATION','SUPPORTIVE_CONTEXT');ue~seal;u~addInformationUse(ue)
i=.UtteranceGenerationIntent~new('intent with space','act with space','OFFER_EXTRA_BAG');i~addInformationUseId('use with space');i~seal;u~addGenerationIntent(i)
call assertTrue u~seal~ok,'standalone utterance accepts legacy free-form ids'
r=.StructuredUtteranceInteractionBridge~toEvent(u,'event-id-contract','TEST')
call assertTrue \r~ok,'bridge rejects non-token native identity without raising syntax'
call assertEqual 'INTERACTION_NATIVE_TOKEN_INCOMPATIBLE',r~code,'compatibility failure is explicit'
say 'PASS test_interaction_bridge_identity_contract'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtteranceInteractionBridge.cls'

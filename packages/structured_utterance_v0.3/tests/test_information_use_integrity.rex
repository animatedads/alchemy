/* Information-use edges cannot float free of their segment, lineage source or
   target communicative act. */
u=.StructuredUtterance~new('integrity-1')
s=.StructuredUtteranceSegment~new('s1','recovery context','SALESPROP','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[SENSITIVE]','ABSTRACT_ONLY')
s~addLineage(.UtteranceLineageEdge~new('le1','DERIVED_FROM_CUSTOMER_FACT','PROMPT:fact:recovery','CUSTOMER_SENSITIVE'))
call assertTrue s~seal~ok,'segment seals'; u~addSegment(s)
a=.UtteranceCommunicativeAct~new('a1','SALESPROP'); a~addSegmentId('s1'); call assertTrue a~seal~ok,'act seals'; u~addAct(a)
ue=.UtteranceInformationUseEdge~new('ue1','s1','missing-lineage','a1','JUSTIFICATION','SALES_JUSTIFICATION'); ue~seal; u~addInformationUse(ue)
r=u~seal
call assertFalse r~ok,'missing lineage rejected'
call assertEqual 'UTTERANCE_INFORMATION_USE_LINEAGE_MISSING',r~code,'correct integrity error'

say 'PASS test_information_use_integrity'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'

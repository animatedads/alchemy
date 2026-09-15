/* Literal copying is not required for privacy lineage. */
u = .StructuredUtterance~new('lineage-1')

s1 = .StructuredUtteranceSegment~new('s1','your daughter','INFORMATION','CUSTREF','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY')
e1 = .UtteranceLineageEdge~new('e1','REFERENCES_CUSTOMER_ENTITY','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC')
s1~addLineage(e1)
call assertTrue s1~seal~ok, 'derived entity reference seals'
u~addSegment(s1)

s2 = .StructuredUtteranceSegment~new('s2',' has a substance-use problem','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE',' [CUSTOMER_SENSITIVE_INFORMATION]','ABSTRACT_ONLY')
e2 = .UtteranceLineageEdge~new('e2','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER_PROMPT:fact:substance-use','CUSTOMER_SENSITIVE')
s2~addLineage(e2)
call assertTrue s2~seal~ok, 'sensitive derived fact seals'
u~addSegment(s2)
call assertTrue u~seal~ok, 'utterance seals'

safe = .StructuredUtteranceRenderer~renderDeidentified(u)
call assertTrue safe~ok, 'projection renders'
call assertTrue safe~value~pos('daughter') = 0, 'derived relationship wording removed'
call assertTrue safe~value~pos('substance-use') = 0, 'derived sensitive wording removed'
call assertTrue safe~value~pos('[CUSTOMER_RELATED_PERSON]') > 0, 'entity abstraction retained'
call assertTrue safe~value~pos('[CUSTOMER_SENSITIVE_INFORMATION]') > 0, 'sensitive abstraction retained'

/* The model cannot mark customer-derived output as PUBLIC. */
bad = .StructuredUtteranceSegment~new('bad','Barbie','INFORMATION','CUSTNAME','PUBLIC')
bad~addLineage(.UtteranceLineageEdge~new('bad-e','COPIED_FROM_CUSTOMER','CUSTOMER_PROMPT:person:1','CUSTOMER_SPECIFIC'))
br = bad~seal
call assertFalse br~ok, 'privacy floor blocks model underclassification'
call assertEqual 'SEGMENT_CUSTOMER_ROLE_PRIVACY_TOO_LOW', br~code, 'customer data role blocks public classification first'

/* A privacy engine may attest a genuinely safe abstraction and lower the floor. */
abs = .StructuredUtteranceSegment~new('abs','customer reported repeated equipment failure','INFORMATION','NONE','DERIVED_NONCUSTOMER')
abs~addLineage(.UtteranceLineageEdge~new('abs-e','DERIVED_SAFE_ABSTRACTION','CUSTOMER_PROMPT:fact:router-history','CUSTOMER_SENSITIVE','DERIVED_NONCUSTOMER','PRIVACY_ENGINE','privacy-v1'))
call assertTrue abs~seal~ok, 'authorised safe abstraction can downgrade privacy floor'

/* The model cannot claim the same downgrade itself. */
notabs = .StructuredUtteranceSegment~new('notabs','customer reported repeated equipment failure','INFORMATION','NONE','DERIVED_NONCUSTOMER')
notabs~addLineage(.UtteranceLineageEdge~new('notabs-e','DERIVED_SAFE_ABSTRACTION','CUSTOMER_PROMPT:fact:router-history','CUSTOMER_SENSITIVE','DERIVED_NONCUSTOMER','MODEL','llm'))
nr = notabs~seal
call assertFalse nr~ok, 'model self-authorised downgrade refused'
call assertEqual 'LINEAGE_PRIVACY_DOWNGRADE_UNAUTHORISED', nr~code, 'correct downgrade error'

say 'PASS test_lineage_privacy'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
assertFalse: procedure; use arg v,l; if v then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'StructuredUtterance.cls'

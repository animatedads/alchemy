p = .StructuredUtteranceProducer~new
plan=.StructuredUtteranceGenerationPlan~new('PLAN-LINEAGE-1','UTT-LINEAGE-1')
/* Different linguistic renderings may reference the same customer entity. */
s1=.StructuredUtteranceSegment~new('s1','Barbie','INFORMATION','CUSTNAME','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY')
s1~addLineage(.UtteranceLineageEdge~new('e1','REFERENCES_CUSTOMER_ENTITY','CUSTOMER:PERSON:17','CUSTOMER_SPECIFIC'))
plan~addSegment(s1)
s2=.StructuredUtteranceSegment~new('s2','your daughter','INFORMATION','CUSTREF','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY',' ')
s2~addLineage(.UtteranceLineageEdge~new('e2','REFERENCES_CUSTOMER_ENTITY','CUSTOMER:PERSON:17','CUSTOMER_SPECIFIC'))
plan~addSegment(s2)
s3=.StructuredUtteranceSegment~new('s3','the passenger with the substance-use problem','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_INFORMATION]','ABSTRACT_ONLY',' ')
s3~addLineage(.UtteranceLineageEdge~new('e3','REFERENCES_CUSTOMER_ENTITY','CUSTOMER:PERSON:17','CUSTOMER_SPECIFIC','CUSTOMER_SPECIFIC'))
s3~addLineage(.UtteranceLineageEdge~new('e4','DERIVED_FROM_CUSTOMER_FACT','CUSTOMER:FACT:SUBSTANCE-USE','CUSTOMER_SENSITIVE'))
plan~addSegment(s3)
act=.UtteranceCommunicativeAct~new('a1','INFORMATION');act~addSegmentId('s1');act~addSegmentId('s2');act~addSegmentId('s3');plan~addAct(act)
intent=.UtteranceGenerationIntent~new('i1','a1','REFERENCE_CUSTOMER_CONTEXT','NEUTRAL','CONTEXT_CONTINUITY');plan~addGenerationIntent(intent)
call assertTrue plan~seal~ok,'lineage plan seals'
r=p~produce(plan);call assertTrue r~ok,'lineage plan produces'
safe=r~value~deidentifiedText
call assertTrue safe~pos('Barbie')=0,'name absent'
call assertTrue safe~pos('your daughter')=0,'relationship wording absent'
call assertTrue safe~pos('substance-use')=0,'sensitive derived wording absent'
call assertTrue r~value~utterance~segmentById('s1')~lineage[1]~sourceRef='CUSTOMER:PERSON:17','name lineage points to entity'
call assertTrue r~value~utterance~segmentById('s2')~lineage[1]~sourceRef='CUSTOMER:PERSON:17','paraphrase lineage points to same entity'
call assertTrue r~value~utterance~segmentById('s3')~lineage[2]~sourceRef='CUSTOMER:FACT:SUBSTANCE-USE','derived phrase points to sensitive fact'
say 'PASS test_customer_reference_lineage'
exit 0
assertTrue: procedure; use arg v,l; if \v then do; say 'FAIL:' l; exit 1; end; return
::requires 'StructuredUtteranceProducer.cls'

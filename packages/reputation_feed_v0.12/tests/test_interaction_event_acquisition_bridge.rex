now=.DateTime~new
lib=.InteractionCaptureLibrary~new
actor=.InteractionReference~new('AGENT','agent-42','AGENT','ORGANISATION','SYSTEM')
subject=.InteractionReference~new('CUSTOMER','customer-very-secret','CUSTOMER','CUSTOMER_SPECIFIC','SYSTEM')
e=.InteractionEvent~new('ie-1','AGENT_UTTERANCE',actor,'CHAT','CRM.CHAT.POST','OUTBOUND',now,now,subject)
e~addCorrelation('journey-100')
e~addTag('STRUCTURED_UTTERANCE')
e~addContent(.InteractionContentElement~new('ce-public','UTTERANCE_SEGMENT','We are sorry about the failed delivery','ORGANISATION','','RETAIN','AGENT_OUTPUT','INTERACTION_EVENT:ie-1/SEGMENT/public','',96))
e~addContent(.InteractionContentElement~new('ce-secret','UTTERANCE_SEGMENT','Barbie Secret Name','CUSTOMER_SPECIFIC','[CUSTOMER_RELATED_PERSON]','ABSTRACT_ONLY','AGENT_OUTPUT','INTERACTION_EVENT:ie-1/SEGMENT/secret','',99))
e~addEvidence(.InteractionEvidenceAnchor~new('utterance-1','STRUCTURED_UTTERANCE','STRUCTURED_UTTERANCE:utterance-1',now,100))
e~seal
call assertTrue lib~captureEvent(e)~ok,'event captured'
ass=.InteractionAssessmentFactory~style('assess-1','ie-1','STYLE-ASSESSOR','model-x',87)
ass~addDimension('SASS',91)
ass~addDetailElement(.InteractionContentElement~new('detail-secret','ASSESSMENT_DETAIL','customer-very-secret complained','CUSTOMER_SPECIFIC','[CUSTOMER_COMPLAINT]','ABSTRACT_ONLY','MODEL_DERIVED','ASSESSMENT:assess-1','',80))
ass~seal
call assertTrue lib~attachAssessment(ass)~ok,'assessment attached'
next=.InteractionEvent~new('ie-2','CANCELLATION',actor,'BILLING','CRM.CANCEL','INBOUND',now,now,subject)
next~addContent(.InteractionContentElement~new('ce-next','STATE','CANCELLED','ORGANISATION','','RETAIN','SYSTEM','INTERACTION_EVENT:ie-2','',100)); next~seal
call assertTrue lib~captureEvent(next)~ok,'next event captured'
call assertTrue lib~markCandidateTrigger('link-1','ie-1','ie-2',72,'journey-assessor')~ok,'candidate link attached'

bridge=.ReputationFeedInteractionEventBridge~new
packet=bridge~evidenceFromLibrary('packet-ie-1','CRM-CHAT',lib,'ie-1','GB')
call assertTrue packet~sealed,'packet sealed'
call assertEqual 'INTERACTION_EVENT',packet~sourceKind,'source kind retained'
call assertEqual 'INTERACTION_EVENT:ie-1',packet~sourcePointId,'stable source point retained'
call assertEqual 'DEIDENTIFIED_ANALYTIC',packet~privacyProjectionMode,'privacy projection fixed to deidentified mode'
call assertEqual 1,packet~assessments~items,'assessment retained as assessment evidence'
call assertEqual 'COMMUNICATION_STYLE',packet~assessments[1]~assessmentType,'assessment type retained'
call assertEqual '91',packet~assessments[1]~dimensions['SASS'],'controlled dimension retained'
call assertEqual 1,packet~relationships~items,'candidate relationship retained'
call assertEqual 'CANDIDATE_NOT_PROVEN',packet~relationships[1]~causalStatus,'candidate causal status does not become fact'
call assertTrue packet~contentItems~items >= 3,'projected actor/subject/content retained as rich items'
canonical=packet~canonicalText
call assertNotContains canonical,'Barbie Secret Name','raw customer content must not cross bridge'
call assertNotContains canonical,'customer-very-secret','raw customer reference must not cross bridge'
call assertContains canonical,'[CUSTOMER_RELATED_PERSON]','customer abstraction retained'
call assertContains canonical,'[CUSTOMER_COMPLAINT]','assessment detail abstraction retained'

say 'PASS test_interaction_event_acquisition_bridge items='packet~contentItems~items 'assessments='packet~assessments~items
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
assertContains: procedure; use arg text,needle,label; if pos(needle,text)=0 then do; say 'FAIL:' label; exit 1; end; return
assertNotContains: procedure; use arg text,needle,label; if pos(needle,text)>0 then do; say 'FAIL:' label; exit 1; end; return
::requires 'ReputationFeedInteractionEventBridge.cls'

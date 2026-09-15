now=.DateTime~new

/* Structured utterance representation of one outbound action. */
ctx=.BrandExperienceContext~serviceAsSales
u=.StructuredUtterance~new('SU-DEMO-42','AGENT','CHAT','CUSTOMER-REQUEST',ctx)
u~addCorrelation('JOURNEY-DEMO-42')
sensitive=.StructuredUtteranceSegment~new('SEG-CONTEXT','Barbie has a medical issue','INFORMATION','CUSTSENSITIVE','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY')
sensitive~addLineage(.UtteranceLineageEdge~new('LIN-1','DERIVED_FROM_CUSTOMER_FACT','PROMPT:PRIVATE','CUSTOMER_SENSITIVE'))
sensitive~seal; u~addSegment(sensitive)
sale=.StructuredUtteranceSegment~new('SEG-SALE','Would you like an extra bag?','SALESPROP','NONE','PUBLIC','','RETAIN')
sale~seal; u~addSegment(sale)
act=.UtteranceCommunicativeAct~new('ACT-SALE','SALESPROP'); act~addSegmentId('SEG-SALE'); act~seal; u~addAct(act)
useEdge=.UtteranceInformationUseEdge~new('USE-1','SEG-CONTEXT','LIN-1','ACT-SALE','JUSTIFICATION','SUPPORTIVE_CONTEXT','MODEL','DEMO',97); useEdge~seal; u~addInformationUse(useEdge)
u~seal
suPacket=.ReputationFeedStructuredUtteranceBridge~new~evidenceFromUtterance('PACKET-SU','AGENT-CHAT',u,now,'GB')

/* Interaction Event representation of the same underlying action. */
lib=.InteractionCaptureLibrary~new
e=.InteractionEvent~new('IE-DEMO-42','AGENT_UTTERANCE',.nil,'CHAT','CRM.POST','OUTBOUND',now,now,.nil)
e~addCorrelation('JOURNEY-DEMO-42')
e~addContent(.InteractionContentElement~new('IE-CONTEXT','UTTERANCE_SEGMENT','Barbie has a medical issue','CUSTOMER_SENSITIVE','[CUSTOMER_SENSITIVE_CONTEXT]','ABSTRACT_ONLY','AGENT_OUTPUT','INTERACTION_EVENT:IE-DEMO-42/SEGMENT/1','',97))
e~addContent(.InteractionContentElement~new('IE-SALE','UTTERANCE_SEGMENT','Would you like an extra bag?','ORGANISATION','','RETAIN','AGENT_OUTPUT','INTERACTION_EVENT:IE-DEMO-42/SEGMENT/2','',97))
e~seal; lib~captureEvent(e)
iePacket=.ReputationFeedInteractionEventBridge~new~evidenceFromLibrary('PACKET-IE','CRM-CHAT',lib,'IE-DEMO-42','GB')

claimBridge=.ReputationFeedInteractionClaimBridge~new
suSpec=.ReputationInteractionClaimSpec~new('CLAIM-SU','REP-SU','COMMUNICATION_ACTION','CONVERSATION:DEMO-42','Structured representation','CONVERSATION:DEMO-42',92)
suSpec~addConcept('SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'); suSpec~seal
ieSpec=.ReputationInteractionClaimSpec~new('CLAIM-IE','REP-IE','COMMUNICATION_ACTION','CONVERSATION:DEMO-42','Interaction representation','CONVERSATION:DEMO-42',90)
ieSpec~addConcept('SENSITIVE_INFORMATION_COMMERCIAL_REPURPOSING'); ieSpec~seal
suClaim=claimBridge~claimFromEvidence(suSpec,suPacket)
ieClaim=claimBridge~claimFromEvidence(ieSpec,iePacket)

policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)
h=.ReputationEventHypothesis~new('H-DEMO-42','COMMUNICATION_ACTION'); h~addClaim(suClaim); h~addClaim(ieClaim); h~seal
a=h~corroboration(policy)

say 'feed_api=' .ReputationFeedBuild~API_VERSION
say 'structured_packet='suPacket~packetId 'privacy='suPacket~privacyProjectionMode 'items='suPacket~contentItems~items
say 'interaction_packet='iePacket~packetId 'privacy='iePacket~privacyProjectionMode 'items='iePacket~contentItems~items
say 'same_assertion_root=' (suClaim~corroborationFamilyId = ieClaim~corroborationFamilyId)
say 'representation_families='a~publicationFamilyCount
say 'assertion_families='a~assertionFamilyCount
say 'status='a~status
combined=suPacket~canonicalText || iePacket~canonicalText
say 'raw_sensitive_present=' (pos('Barbie has a medical issue',combined)>0)
say 'safe_abstraction_present=' (pos('[CUSTOMER_SENSITIVE_CONTEXT]',combined)>0)
say 'structured_to_interaction_adjacent_bridge=NOT_USED'
exit 0

::requires 'ReputationFeedInteractionEventBridge.cls'
::requires 'ReputationFeedStructuredUtteranceBridge.cls'

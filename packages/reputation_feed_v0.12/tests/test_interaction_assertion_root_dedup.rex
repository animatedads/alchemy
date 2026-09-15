now=.DateTime~new
p1=.ReputationInteractionEvidencePacket~new('packet-event','CRM','CRM-CHAT','ie-100','INTERACTION_EVENT:ie-100','CHAT','CRM.POST','OUTBOUND',now,now,'GB')
p1~addContentItem(.ReputationInteractionEvidenceItem~new('i1','UTTERANCE_SEGMENT','apology','','ABSTRACTED','INTERACTION_EVENT',95,'INTERACTION_EVENT:ie-100'))
p1~seal
p2=.ReputationInteractionEvidencePacket~new('packet-utterance','AGENT','AGENT-CHAT','su-100','STRUCTURED_UTTERANCE:su-100','CHAT','','OUTBOUND',now,now,'GB')
p2~addContentItem(.ReputationInteractionEvidenceItem~new('i2','UTTERANCE_SEGMENT','apology','','ABSTRACTED','STRUCTURED_UTTERANCE',95,'STRUCTURED_UTTERANCE:su-100'))
p2~seal
bridge=.ReputationFeedInteractionClaimBridge~new
s1=.ReputationInteractionClaimSpec~new('claim-event','FAMILY-CRM','COMMUNICATION_ACTION','CONVERSATION:100','Agent action','CONVERSATION:100',92)
s1~addConcept('COMMERCIAL_PRESSURE_COLLISION'); s1~seal
s2=.ReputationInteractionClaimSpec~new('claim-utterance','FAMILY-AGENT','COMMUNICATION_ACTION','CONVERSATION:100','Same agent action','CONVERSATION:100',94)
s2~addConcept('COMMERCIAL_PRESSURE_COLLISION'); s2~seal
c1=bridge~claimFromEvidence(s1,p1)
c2=bridge~claimFromEvidence(s2,p2)
call assertEqual 'ASSERTION:CONVERSATION:100',c1~corroborationFamilyId,'explicit interaction assertion root retained'
call assertEqual c1~corroborationFamilyId,c2~corroborationFamilyId,'two representations of one interaction share corroboration root'
h=.ReputationEventHypothesis~new('h-same','COMMUNICATION_ACTION'); h~addClaim(c1); h~addClaim(c2); h~seal
policy=.ReputationCorroborationPolicy~new(2,70,1,120,.true)
a=h~corroboration(policy)
call assertEqual 2,a~publicationFamilyCount,'two representation families retained'
call assertEqual 1,a~assertionFamilyCount,'same underlying interaction counts once'
call assertEqual 'CORROBORATING',a~status,'dual representation cannot self-corroborate'

p3=.ReputationInteractionEvidencePacket~new('packet-independent','CRM','CRM-CHAT','ie-200','INTERACTION_EVENT:ie-200','CHAT','CRM.POST','OUTBOUND',now,now,'GB')
p3~addContentItem(.ReputationInteractionEvidenceItem~new('i3','UTTERANCE_SEGMENT','similar action','','ABSTRACTED','INTERACTION_EVENT',90,'INTERACTION_EVENT:ie-200')); p3~seal
s3=.ReputationInteractionClaimSpec~new('claim-independent','FAMILY-CRM-2','COMMUNICATION_ACTION','CONVERSATION:200','Independent action','CONVERSATION:200',90)
s3~addConcept('COMMERCIAL_PRESSURE_COLLISION'); s3~seal
c3=bridge~claimFromEvidence(s3,p3)
h2=.ReputationEventHypothesis~new('h-independent','COMMUNICATION_ACTION'); h2~addClaim(c1); h2~addClaim(c2); h2~addClaim(c3); h2~seal
a2=h2~corroboration(policy)
call assertEqual 2,a2~assertionFamilyCount,'independent interaction adds a second assertion root'
call assertEqual 'CORROBORATED',a2~status,'independent interactions can corroborate a pattern'
call assertEqual 92,c1~confidence,'bridge uses explicit claim confidence rather than assessor scores'

say 'PASS test_interaction_assertion_root_dedup families='a2~assertionFamilyCount
exit 0
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationFeedInteractionEvidence.cls'

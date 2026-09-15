now=.DateTime~new
source=.ReputationSourceIdentity~new('NEWS-A','NEWS','News A','GROUP-A','OWNER-A','GB','EDITORIAL_REPORTING','feed-a')~seal
envelope=.ReputationRawEnvelope~new('ENV-A',source,now,now,'TEXT/HTML','https://example.invalid/a','EN','sha256:a')
envelope~addField('TITLE','Aircraft returned after cabin event')
envelope~addField('OBSERVED_GEOGRAPHY','GB')
envelope~addSegment('HEADLINE','Aircraft returned after cabin event')
envelope~addSegment('BODY','The operator said the aircraft returned safely after a cabin opening event.')
envelope~addSegment('BODY','No cause has yet been established.')
envelope~seal
acquired=.ReputationNewsPublicationAdapter~new~adapt(envelope)
call assertTrue acquired~accepted,'news acquisition accepted'
handoff=acquired~librarianHandoff
finding=.ReputationLibrarianFinding~new('FIND-A',handoff~handoffId,'AIRCRAFT_SAFETY_INCIDENT','Cabin event',now,84,'ASSERTS')
finding~addParagraphIndex(2)
finding~setEventKey('INCIDENT-2026-001')
finding~addSubject('MANUFACTURER','BOEING',90)
finding~addConcept('CABIN_OPENING')
finding~addAffectedGeography('GB')
finding~seal
bridge=.ReputationLibrarianClaimBridge~new
claim=bridge~claimFromFinding('CLAIM-A','FAMILY-A',handoff,finding)
call assertTrue claim~sealed,'bridge produces sealed Feed claim'
call assertEqual 'DOC-ENV-A',claim~articleId,'document provenance retained as claim article/document id'
call assertEqual 'NEWS-A',claim~sourceId,'source identity retained'
call assertEqual 'https://example.invalid/a',claim~citation,'source locator retained'
call assertEqual 'INCIDENT-2026-001',claim~eventKey,'Librarian normalized event key retained'
call assertEqual 'MANUFACTURER|BOEING',claim~subjectKeys[1],'Librarian subject retained'
call assertEqual 'CABIN_OPENING',claim~concepts[1],'Librarian concept retained'
call assertEqual 'GB',claim~affectedGeographies[1],'affected geography retained'
call assertEqual 1,bridge~alchemyMetrics['use_count'],'bridge use recorded through Alchemy base'

/* A second independently lineaged finding corroborates; repeated variants in
   FAMILY-A would still count as one family downstream. */
sourceB=.ReputationSourceIdentity~new('NEWS-B','NEWS','News B','GROUP-B','OWNER-B','GB','EDITORIAL_REPORTING','feed-b')~seal
envelopeB=.ReputationRawEnvelope~new('ENV-B',sourceB,now,now,'TEXT/HTML','https://example.invalid/b','EN','sha256:b')
envelopeB~addField('TITLE','Second report of cabin event')
envelopeB~addSegment('BODY','A separate newsroom reports the same cabin event.')
envelopeB~seal
handoffB=.ReputationNewsPublicationAdapter~new~adapt(envelopeB)~librarianHandoff
findingB=.ReputationLibrarianFinding~new('FIND-B',handoffB~handoffId,'AIRCRAFT_SAFETY_INCIDENT','Cabin event',now,88,'ASSERTS')
findingB~addParagraphIndex(1); findingB~setEventKey('INCIDENT-2026-001'); findingB~addSubject('MANUFACTURER','BOEING'); findingB~addConcept('CABIN_OPENING'); findingB~addAffectedGeography('GB'); findingB~seal
claimB=bridge~claimFromFinding('CLAIM-B','FAMILY-B',handoffB,findingB)
clusters=.ReputationEventClusterEngine~new~cluster(.array~of(claim,claimB),.ReputationCorroborationPolicy~new(2,70,1,120,.true))
call assertEqual 1,clusters~hypotheses~items,'claims cluster into one event hypothesis'
assessment=clusters~hypotheses[1]~corroboration(.ReputationCorroborationPolicy~new(2,70))
call assertEqual 'CORROBORATED',assessment~status,'two independent Librarian lineages corroborate'
call assertEqual 2,assessment~independentFamilyCount,'lineage family count retained'

say 'PASS test_librarian_claim_bridge api=' .ReputationFeedBuild~API_VERSION
exit 0
assertTrue: procedure; use arg v,l; if v \== .true then do; say 'FAIL:' l; exit 1; end; return
assertEqual: procedure; use arg e,a,l; if e \== a then do; say 'FAIL:' l 'expected='e 'actual='a; exit 1; end; return
::requires 'ReputationAcquisition.cls'

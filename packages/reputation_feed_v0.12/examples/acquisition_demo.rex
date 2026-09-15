now=.DateTime~new
source=.ReputationSourceIdentity~new('NEWS-GLA','NEWS','Glasgow Daily','GROUP-A','OWNER-A','GB-SCT','EDITORIAL_REPORTING','news-feed')~seal
envelope=.ReputationRawEnvelope~new('ENV-DEMO',source,now,now,'TEXT/HTML','https://example.invalid/demo','EN','sha256:demo')
envelope~addField('TITLE','Cabin event reported')
envelope~addSegment('HEADLINE','Cabin event reported')
envelope~addSegment('BODY','The operator says an aircraft returned safely after a cabin event.')
envelope~seal
acquired=.ReputationNewsPublicationAdapter~new~adapt(envelope)
handoff=acquired~librarianHandoff
finding=.ReputationLibrarianFinding~new('FIND-DEMO',handoff~handoffId,'AIRCRAFT_SAFETY_INCIDENT','Cabin event',now,86,'ASSERTS')
finding~addParagraphIndex(2)
finding~setEventKey('DEMO-EVENT-1')
finding~addSubject('MANUFACTURER','BOEING')
finding~addConcept('CABIN_OPENING')
finding~addAffectedGeography('GB')
finding~seal
claim=.ReputationLibrarianClaimBridge~new~claimFromFinding('CLAIM-DEMO','FAMILY-DEMO',handoff,finding)
say 'feed_api=' .ReputationFeedBuild~API_VERSION
say 'source=' source~sourceId 'kind='source~sourceKind 'role='source~evidentialRole
say 'document=' acquired~document~documentId 'paragraphs='handoff~paragraphCount 'corpus='handoff~corpora[1]
say 'article=' acquired~feedArticle~articleId 'reach_known=' (acquired~feedArticle~surfaces[1]~reachEvidence \== .nil)
say 'claim=' claim~claimId 'event_key='claim~eventKey 'source='claim~sourceId
say 'authority_boundary=CLAIM_ONLY'
exit 0
::requires 'ReputationAcquisition.cls'

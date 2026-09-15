codec = .ReputationFeedQueuePersistenceSupport~newCodec
factoryAdoption=.AlchemyAdoptionVerifier~verify(.ReputationFeedQueuePayloadFactory~new('CLAIM'),'STANDARD')
call true factoryAdoption~ok,'persistence restore factory adopts Alchemy v0.8'
call eq 0,factoryAdoption~warnings~items,'persistence restore factory adoption warnings'
now = .DateTime~new

source = .ReputationSourceIdentity~new('SRC-NEWS','NEWS','News','PUB','OWNER','GB','EDITORIAL_REPORTING','endpoint')
source~seal
raw = .ReputationRawEnvelope~new('ENV-PERSIST',source,now,now,'TEXT/PLAIN','https://example.test/a','EN','abcd')
raw~addSegment('HEADLINE','Door event')
raw~addSegment('BODY','Synthetic durable evidence')
raw~addField('WIRE_SERVICE','NONE')
raw~seal
call roundTrip raw, codec, 'REPUTATIONRAWENVELOPE', raw~canonicalText, 'raw'

claim = .ReputationFeedClaim~new('CLAIM-PERSIST','ART-1','PUB-FAM','AVIATION_INCIDENT','Synthetic',now,now,'GB',83,'ASSERTS','ACTIVE','SRC-NEWS','cite')
claim~setEventKey('EVENT-1')
claim~setSourceAuthentication('VERIFIED','AUTH-1',.false,'HIST-1')
claim~addAssertionOrigin('ASSERT-ROOT-1','SRC-NEWS','DERIVED_FROM','LIN-1','wire origin')
claim~addSubject('MANUFACTURER','BOEING',91)
claim~addConcept('CABIN_OPENING')
claim~addAffectedGeography('GB')
claim~seal
call roundTrip claim, codec, 'REPUTATIONFEEDCLAIM', claim~canonicalText, 'claim'
claimState=claim~queuePersistentState
call false claimState~hasIndex('alchemyContext'), 'persistence state excludes Alchemy context'
call false claimState~hasIndex('sealer'), 'persistence state excludes sealer'
call false claimState~hasIndex('authority'), 'persistence state excludes authority'
encodedClaim=codec~encode(claim)
call true decodeFailsUnregistered(encodedClaim), 'unregistered codec fails closed for Feed persistent type'

hyp = .ReputationEventHypothesis~new('HYP-PERSIST','AVIATION_INCIDENT')
hyp~addClaim(claim)
hyp~seal
enc=codec~encode(hyp)
restored=codec~decode(enc)
call eq 'REPUTATIONEVENTHYPOTHESIS',restored~class~id,'hypothesis class'
call eq hyp~canonicalText,restored~canonicalText,'hypothesis canonical'
call eq 1,restored~claimCount,'hypothesis claim count'
call eq 'REPUTATIONFEEDCLAIM',restored~claims[1]~class~id,'nested claim class'
call eq claim~canonicalText,restored~claims[1]~canonicalText,'nested claim canonical'

corr=.ReputationFeedCorrection~new('CORR-PERSIST','CLAIM-PERSIST','RETRACTION','',now,'SRC-NEWS',100,'withdrawn')
corr~seal
call roundTrip corr, codec, 'REPUTATIONFEEDCORRECTION', corr~canonicalText, 'correction'

match=.ReputationWatchMatch~new('WATCH-1','HYP-PERSIST',.true,90,.true,1,2,1)
enc=codec~encode(match)
restored=codec~decode(enc)
call eq 'REPUTATIONWATCHMATCH',restored~class~id,'watch class'
call eq 'WATCH-1',restored~watchSetId,'watch id'
call true restored~matched,'watch matched'
call eq 90,restored~score,'watch score'
call true restored~eventTypeMatch,'watch event match'
call eq 2,restored~conceptMatchCount,'watch concept count'

packet=.ReputationInteractionEvidencePacket~new('PACKET-PERSIST','INTERACTION_EVENT','CRM-CHAT','IE-1','INTERACTION_EVENT:IE-1','CHAT','CRM.POST','OUTBOUND',now,now,'GB')
packet~addContentItem(.ReputationInteractionEvidenceItem~new('ITEM-1','UTTERANCE_SEGMENT','[CUSTOMER_RELATED_PERSON]','CUSTOMER_SPECIFIC','ABSTRACTED','AGENT_OUTPUT',96,'INTERACTION_EVENT:IE-1'))
ae=.ReputationInteractionAssessmentEvidence~new('ASSESS-1','COMMUNICATION_STYLE','PROFILE','MODEL','STYLE','MODEL-X',87)
ae~putDimension('SASS',91)
ae~addDetail(.ReputationInteractionEvidenceItem~new('DETAIL-1','ASSESSMENT_DETAIL','[CUSTOMER_COMPLAINT]','CUSTOMER_SPECIFIC','ABSTRACTED','MODEL_DERIVED',80,'INTERACTION_EVENT:IE-1'))
packet~addAssessment(ae)
packet~addRelationship(.ReputationInteractionRelationshipEvidence~new('REL-1','CANDIDATE_TRIGGER','INTERACTION_EVENT:IE-1','INTERACTION_EVENT:IE-2','CANDIDATE_NOT_PROVEN',72,'journey'))
packet~addSemanticToken('PURPOSE/APOLOGY')
packet~addCorrelation('JOURNEY-1')
packet~addSourceEvidenceRef('STRUCTURED_UTTERANCE:SU-1')
packet~seal
call roundTrip packet, codec, 'REPUTATIONINTERACTIONEVIDENCEPACKET', packet~canonicalText, 'interaction evidence'
call eq 'reputation.feed.interaction-evidence/1',packet~queuePersistentType,'interaction evidence persistence identity'

trace=.ReputationFeedDecisionTrace~new('TRACE-CODEC',.nil,'HYP-PERSIST','CODEC_TEST')~seal
call roundTrip trace, codec, 'REPUTATIONFEEDDECISIONTRACE', trace~canonicalText, 'decision trace'
call eq 'reputation.feed.decision-trace/1',trace~queuePersistentType,'decision trace persistence identity'

say 'PASS test_queue_persistence_codec types=7 nested_claim=1 interaction_evidence=1 decision_trace=1' 
exit 0

roundTrip: procedure
  use arg object, codec, classId, canonical, label
  encoded=codec~encode(object)
  restored=codec~decode(encoded)
  call eq classId,restored~class~id,label 'class'
  call eq canonical,restored~canonicalText,label 'canonical'
  return

eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return
true: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return


false: procedure
  use arg value,label
  if value then do; say 'FAIL:' label; exit 1; end
  return

decodeFailsUnregistered: procedure
  use arg encoded
  fresh=.QueueGraphPayloadCodec~new
  signal on syntax name expectedFailure
  ignore=fresh~decode(encoded)
  signal off syntax
  return .false
expectedFailure:
  signal off syntax
  return .true

::requires 'ReputationFeedQueuePersistence.cls'
::requires 'AlchemyAdoption.cls'

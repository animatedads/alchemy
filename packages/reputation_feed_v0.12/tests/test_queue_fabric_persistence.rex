stamp=.DateTime~new~microseconds
root='./tmp_reputation_feed_queue_' || stamp
codec1=.ReputationFeedQueuePersistenceSupport~newCodec
manager=.ObjectQueueManager~new(root,codec1,'admin')
call must manager~createQueue('REP.RAW','PERMANENT','REP',20,'admin'),'create raw queue'
call must manager~createQueue('REP.CLAIM','PERMANENT','REP',20,'admin'),'create claim queue'
call must manager~createQueue('REP.HYP','PERMANENT','REP',20,'admin'),'create hypothesis queue'
call must manager~createQueue('REP.CORR','PERMANENT','REP',20,'admin'),'create correction queue'
call must manager~createQueue('REP.ALERT','PERMANENT','REP',20,'admin'),'create alert queue'
call must manager~createQueue('REP.INT','PERMANENT','REP',20,'admin'),'create interaction queue'
call must manager~createQueue('REP.DEC','PERMANENT','REP',20,'admin'),'create decision trace queue'
topics=.QueueTopicFabric~new(manager)
call must topics~defineTopic('REPUTATION_FEED','reputation/feed','PERMANENT','REP','admin'),'define permanent feed topic'
call must topics~subscribe('REP.RAW.SUB','REPUTATION_FEED','raw/#','REP.RAW','PERMANENT','admin'),'subscribe raw'
call must topics~subscribe('REP.CLAIM.SUB','REPUTATION_FEED','claims/#','REP.CLAIM','PERMANENT','admin'),'subscribe claim'
call must topics~subscribe('REP.HYP.SUB','REPUTATION_FEED','hypotheses/#','REP.HYP','PERMANENT','admin'),'subscribe hypothesis'
call must topics~subscribe('REP.CORR.SUB','REPUTATION_FEED','corrections/#','REP.CORR','PERMANENT','admin'),'subscribe correction'
call must topics~subscribe('REP.ALERT.SUB','REPUTATION_FEED','alerts/#','REP.ALERT','PERMANENT','admin'),'subscribe alert'
call must topics~subscribe('REP.INT.SUB','REPUTATION_FEED','interactions/#','REP.INT','PERMANENT','admin'),'subscribe interaction'
call must topics~subscribe('REP.DEC.SUB','REPUTATION_FEED','decisions/#','REP.DEC','PERMANENT','admin'),'subscribe decision trace'
bridge=.ReputationFeedQueueBridge~new(topics,'REPUTATION_FEED','admin')

now=.DateTime~new
source=.ReputationSourceIdentity~new('SRC-NEWS','NEWS','News','PUB','OWNER','GB','EDITORIAL_REPORTING','endpoint')
source~seal
raw=.ReputationRawEnvelope~new('ENV-PERSIST',source,now,now,'TEXT/PLAIN','https://example.test/a','EN','abcd')
raw~addSegment('HEADLINE','Door event')
raw~addSegment('BODY','Synthetic durable evidence')
raw~addField('WIRE_SERVICE','NONE')
raw~seal
claim=.ReputationFeedClaim~new('CLAIM-PERSIST','ART-1','PUB-FAM','AVIATION_INCIDENT','Synthetic',now,now,'GB',83,'ASSERTS','ACTIVE','SRC-NEWS','cite')
claim~setEventKey('EVENT-1')
claim~setSourceAuthentication('VERIFIED','AUTH-1',.false,'HIST-1')
claim~addAssertionOrigin('ASSERT-ROOT-1','SRC-NEWS','DERIVED_FROM','LIN-1','wire origin')
claim~addSubject('MANUFACTURER','BOEING',91)
claim~addConcept('CABIN_OPENING')
claim~addAffectedGeography('GB')
claim~seal
hyp=.ReputationEventHypothesis~new('HYP-PERSIST','AVIATION_INCIDENT')
hyp~addClaim(claim)
hyp~seal
corr=.ReputationFeedCorrection~new('CORR-PERSIST','CLAIM-PERSIST','RETRACTION','',now,'SRC-NEWS',100,'withdrawn')
corr~seal
match=.ReputationWatchMatch~new('WATCH-1','HYP-PERSIST',.true,90,.true,1,2,1)

interaction=.ReputationInteractionEvidencePacket~new('PACKET-PERSIST','INTERACTION_EVENT','CRM-CHAT','IE-1','INTERACTION_EVENT:IE-1','CHAT','CRM.POST','OUTBOUND',now,now,'GB')
interaction~addContentItem(.ReputationInteractionEvidenceItem~new('ITEM-1','UTTERANCE_SEGMENT','[CUSTOMER_RELATED_PERSON]','CUSTOMER_SPECIFIC','ABSTRACTED','AGENT_OUTPUT',96,'INTERACTION_EVENT:IE-1'))
ae=.ReputationInteractionAssessmentEvidence~new('ASSESS-1','COMMUNICATION_STYLE','PROFILE','MODEL','STYLE','MODEL-X',87)
ae~putDimension('SASS',91); interaction~addAssessment(ae)
interaction~addRelationship(.ReputationInteractionRelationshipEvidence~new('REL-1','CANDIDATE_TRIGGER','INTERACTION_EVENT:IE-1','INTERACTION_EVENT:IE-2','CANDIDATE_NOT_PROVEN',72,'journey'))
interaction~addSemanticToken('PURPOSE/APOLOGY'); interaction~addCorrelation('JOURNEY-1'); interaction~seal
trace=.ReputationFeedDecisionTrace~new('TRACE-PERSIST',.nil,'HYP-PERSIST','PERSISTENCE_TEST')~seal

persistent=.table~new; persistent['persistent']=.true
retained=.table~new; retained['persistent']=.true; retained['retain']=.true
call must bridge~publishRaw(raw,persistent),'publish durable raw'
call must bridge~publishClaim(claim,retained),'publish durable retained claim'
call must bridge~publishHypothesis(hyp,persistent),'publish durable hypothesis'
call must bridge~publishCorrection(corr,persistent),'publish durable correction'
call must bridge~publishWatchMatch(match,persistent),'publish durable alert'
call must bridge~publishInteractionEvidence(interaction,persistent),'publish durable interaction evidence'
call must bridge~publishDecisionTrace(trace,persistent),'publish durable decision trace'
call eq 1,manager~depth('REP.RAW','admin')~value['ready'],'raw depth before restart'
call eq 1,manager~depth('REP.CLAIM','admin')~value['ready'],'claim depth before restart'
call eq 1,topics~retainedPublications~items,'retained before restart'

/* Critical ordering: Feed types are registered on a fresh codec BEFORE manager recovery. */
codec2=.ReputationFeedQueuePersistenceSupport~newCodec
manager2=.ObjectQueueManager~new(root,codec2,'admin')
topics2=.QueueTopicFabric~new(manager2)
call true topics2~topic('REPUTATION_FEED') \== .nil,'topic recovered'
call true topics2~subscription('REP.CLAIM.SUB') \== .nil,'subscription recovered'
call eq 1,topics2~retainedPublications~items,'retained publication recovered'
ret=topics2~retainedPublications[1]
call eq 'REPUTATIONFEEDCLAIM',ret~payload~class~id,'retained claim class'
call eq claim~canonicalText,ret~payload~canonicalText,'retained claim canonical'
call eq 'CLAIM_NOT_FACT',ret~headers['reputation.feed.authority_boundary'],'retained claim boundary header recovered'

raw2=manager2~browse('REP.RAW','admin')~value~payload
claim2=manager2~browse('REP.CLAIM','admin')~value~payload
hyp2=manager2~browse('REP.HYP','admin')~value~payload
corr2=manager2~browse('REP.CORR','admin')~value~payload
match2=manager2~browse('REP.ALERT','admin')~value~payload
interactionPkg=manager2~browse('REP.INT','admin')~value
interaction2=interactionPkg~payload
decisionPkg=manager2~browse('REP.DEC','admin')~value
trace2=decisionPkg~payload
call eq 'REPUTATIONRAWENVELOPE',raw2~class~id,'raw class after restart'
call eq raw~canonicalText,raw2~canonicalText,'raw canonical after restart'
call eq claim~canonicalText,claim2~canonicalText,'claim canonical after restart'
call true claim2 \== claim,'claim was reconstructed rather than retained by live identity'
claimPkg=manager2~browse('REP.CLAIM','admin')~value
call eq 'CLAIM_NOT_FACT',claimPkg~headers['reputation.feed.authority_boundary'],'claim boundary header after restart'
call eq 'OOREXX_OBJECT_GRAPH',claimPkg~headers['reputation.feed.payload_encoding'],'claim encoding header after restart'
call eq hyp~canonicalText,hyp2~canonicalText,'hypothesis canonical after restart'
call eq 'REPUTATIONFEEDCLAIM',hyp2~claims[1]~class~id,'nested claim class after restart'
call eq claim~canonicalText,hyp2~claims[1]~canonicalText,'nested claim canonical after restart'
call eq corr~canonicalText,corr2~canonicalText,'correction canonical after restart'
call eq 'REPUTATIONWATCHMATCH',match2~class~id,'watch class after restart'
call true match2~matched,'watch matched after restart'
call eq 90,match2~score,'watch score after restart'
call eq 'REPUTATIONINTERACTIONEVIDENCEPACKET',interaction2~class~id,'interaction evidence class after restart'
call eq interaction~canonicalText,interaction2~canonicalText,'interaction evidence canonical after restart'
call true interaction2 \== interaction,'interaction evidence reconstructed rather than retained by live identity'
call eq 'PRIVACY_PROJECTED_INTERACTION_EVIDENCE_NOT_DISPOSITION',interactionPkg~headers['reputation.feed.authority_boundary'],'interaction authority boundary after restart'
call eq 'REPUTATIONFEEDDECISIONTRACE',trace2~class~id,'decision trace class after restart'
call eq trace~canonicalText,trace2~canonicalText,'decision trace canonical after restart'
call true trace2 \== trace,'decision trace reconstructed rather than retained by live identity'
call eq 'GOVERNED_DECISION_AUDIT_NOT_DISPOSITION',decisionPkg~headers['reputation.feed.authority_boundary'],'decision authority boundary after restart'

call eq 'reputation.feed.raw-envelope/1',raw2~queuePersistentType,'raw persistence identity lock'
call eq 'reputation.feed.claim/1',claim2~queuePersistentType,'claim persistence identity lock'
call eq 'reputation.feed.event-hypothesis/1',hyp2~queuePersistentType,'hypothesis persistence identity lock'
call eq 'reputation.feed.correction/1',corr2~queuePersistentType,'correction persistence identity lock'
call eq 'reputation.feed.watch-match/1',match2~queuePersistentType,'watch persistence identity lock'
call eq 'reputation.feed.interaction-evidence/1',interaction2~queuePersistentType,'interaction evidence persistence identity lock'
call eq 'reputation.feed.decision-trace/1',trace2~queuePersistentType,'decision trace persistence identity lock'
call eq .ReputationFeedQueuePersistentType~RAW_ENVELOPE,raw2~queuePersistentType,'registered raw type matches object contract'
call eq .ReputationFeedQueuePersistentType~CLAIM,claim2~queuePersistentType,'registered claim type matches object contract'
call eq .ReputationFeedQueuePersistentType~EVENT_HYPOTHESIS,hyp2~queuePersistentType,'registered hypothesis type matches object contract'
call eq .ReputationFeedQueuePersistentType~CORRECTION,corr2~queuePersistentType,'registered correction type matches object contract'
call eq .ReputationFeedQueuePersistentType~WATCH_MATCH,match2~queuePersistentType,'registered watch type matches object contract'
call eq .ReputationFeedQueuePersistentType~INTERACTION_EVIDENCE,interaction2~queuePersistentType,'registered interaction evidence type matches object contract'
call eq .ReputationFeedQueuePersistentType~DECISION_TRACE,trace2~queuePersistentType,'registered decision trace type matches object contract'

say 'PASS test_queue_fabric_persistence restart=1 retained=1 types=7 rich_objects=preserved interaction=1 decision_trace=1'
exit 0

must: procedure
  use arg op,label
  if \op~ok then do; say 'FAIL:' label op~code op~detail; exit 1; end
  return
true: procedure
  use arg value,label
  if \value then do; say 'FAIL:' label; exit 1; end
  return
eq: procedure
  use arg expected,actual,label
  if expected \== actual then do; say 'FAIL:' label 'expected='expected 'actual='actual; exit 1; end
  return

::requires 'ReputationFeedQueueBridge.cls'

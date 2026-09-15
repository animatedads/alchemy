/* Reputation Feed v0.12 governed decision-audit demonstration. */
now=.DateTime~new
set=.ReputationFeedPolicySet~new('AUDIT-DEMO', -
  .ReputationLineagePolicy~new(78,2), -
  .ReputationCorroborationPolicy~new(2,70,1,180,.true), -
  .ReputationCorroborationEvidencePolicy~new(.false,.false,.false,.false), -
  .ReputationGeographicSaliencePolicy~new(2,5,3,10))~seal
policyBridge=.ReputationFeedInstitutionalPolicyBridge~new('REPUTATION-FEED-DEMO')
release=policyBridge~newRelease('1.0',set,now-.TimeSpan~new(0,1,0,0,0),.nil,'FEED','REVIEW','')
catalog=.InstitutionalPolicyCatalog~new
ignore=catalog~publish(release)

verified=makeClaim('V','ASSERTION:V',91,'VERIFIED')
unverified=makeClaim('U','ASSERTION:U',81,'UNVERIFIED')
h=.ReputationEventHypothesis~new('H-DEMO-AUDIT','AIRCRAFT_SAFETY_INCIDENT')
h~addClaim(verified); h~addClaim(unverified); h~seal
execution=policyBridge~operative(catalog,now)~value
outcome=execution~corroborate(h)
trace=.ReputationFeedDecisionTrace~new('TRACE-DEMO-1',outcome,h~hypothesisId)~seal

logService=.LogService~new('feed-demo-audit')
memory=.LogMemoryTarget~new('memory',.Log~INTERNAL)
logService~addTarget(memory)
logService~addRule(.LogRule~new('decision-audit','reputation_feed','ReputationFeedLoggingBridge','record',.Log~INTERNAL,.Log~INTERNAL,.Log~INFO,.LogConditionAlways~new,.array~of('memory'),.array~of('DECISION')))
logging=.ReputationFeedLoggingBridge~new(logService)
emitted=logging~record(trace)

manager=.ObjectQueueManager~new('',.QueueGraphPayloadCodec~new,'admin')
ignore=manager~createQueue('REP.DEC','TEMPORARY','REP',10,'admin')
topics=.QueueTopicFabric~new(manager)
ignore=topics~defineTopic('REPUTATION_FEED','reputation/feed','TEMPORARY','REP','admin')
ignore=topics~subscribe('REP.DEC.SUB','REPUTATION_FEED','decisions/#','REP.DEC','TEMPORARY','admin')
queueBridge=.ReputationFeedQueueBridge~new(topics,'REPUTATION_FEED','admin')
ignore=queueBridge~publishDecisionTrace(trace)
pkg=manager~browse('REP.DEC','admin')~value

say 'api=' .ReputationFeedBuild~API_VERSION
say 'decision=' trace~decisionCode
say 'status=' trace~outcomeStatus
say 'eligible_claims=' trace~eligibleClaimCount
say 'discovery_only_claims=' trace~discoveryOnlyClaimCount
say 'reason_count=' trace~reasonSummary~items
say 'logging_emitted=' emitted 'log_payload_same=' (memory~events[1]~payload == trace)
say 'queue_topic=' pkg~headers['oqf.topic.string']
say 'queue_boundary=' pkg~headers['reputation.feed.authority_boundary']
say 'queue_payload_same=' (pkg~payload == trace)
say 'raw_claim_content_in_trace=0'
exit 0

makeClaim: procedure
  use arg id,root,confidence,authState
  c=.ReputationFeedClaim~new(id,'ART-'id,'PUB-'id,'AIRCRAFT_SAFETY_INCIDENT','not copied to audit trace',.DateTime~new,.DateTime~new,'GB',confidence,'ASSERTS','ACTIVE','SRC-'id,id)
  c~setEventKey('EVENT-DEMO-AUDIT')
  c~addSubject('MANUFACTURER','BOEING')
  c~addAssertionOrigin(root,'SRC-'id,'PRIMARY_ASSERTION','EVID-'id,'demo root')
  c~setSourceAuthentication(authState,'AUTH-'id,.false,'HIST-'id)
  c~seal
  return c

::requires 'ReputationFeedLoggingBridge.cls'
::requires 'ReputationFeedQueueBridge.cls'
::requires 'ReputationFeedInstitutionalPolicyBridge.cls'

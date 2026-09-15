manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
call must manager~createQueue("REP.RAW", "TEMPORARY", "REP", 20, "admin"), "create raw queue"
call must manager~createQueue("REP.CLAIM", "TEMPORARY", "REP", 20, "admin"), "create claim queue"
call must manager~createQueue("REP.HYP", "TEMPORARY", "REP", 20, "admin"), "create hypothesis queue"
call must manager~createQueue("REP.CORR", "TEMPORARY", "REP", 20, "admin"), "create correction queue"
call must manager~createQueue("REP.ALERT", "TEMPORARY", "REP", 20, "admin"), "create alert queue"
call must manager~createQueue("REP.INT", "TEMPORARY", "REP", 20, "admin"), "create interaction queue"
call must manager~createQueue("REP.DEC", "TEMPORARY", "REP", 20, "admin"), "create decision trace queue"

topics = .QueueTopicFabric~new(manager)
call must topics~defineTopic("REPUTATION_FEED", "reputation/feed", "TEMPORARY", "REP", "admin"), "define feed topic"
call must topics~subscribe("REP.RAW.SUB", "REPUTATION_FEED", "raw/#", "REP.RAW", "TEMPORARY", "admin"), "subscribe raw"
call must topics~subscribe("REP.CLAIM.SUB", "REPUTATION_FEED", "claims/#", "REP.CLAIM", "TEMPORARY", "admin"), "subscribe claim"
call must topics~subscribe("REP.HYP.SUB", "REPUTATION_FEED", "hypotheses/#", "REP.HYP", "TEMPORARY", "admin"), "subscribe hypothesis"
call must topics~subscribe("REP.CORR.SUB", "REPUTATION_FEED", "corrections/#", "REP.CORR", "TEMPORARY", "admin"), "subscribe correction"
call must topics~subscribe("REP.ALERT.SUB", "REPUTATION_FEED", "alerts/#", "REP.ALERT", "TEMPORARY", "admin"), "subscribe alert"
call must topics~subscribe("REP.INT.SUB", "REPUTATION_FEED", "interactions/#", "REP.INT", "TEMPORARY", "admin"), "subscribe interaction"
call must topics~subscribe("REP.DEC.SUB", "REPUTATION_FEED", "decisions/#", "REP.DEC", "TEMPORARY", "admin"), "subscribe decision trace"

bridge = .ReputationFeedQueueBridge~new(topics, "REPUTATION_FEED", "admin")
call must bridge~validateTopology, "validate topology"

now = .DateTime~new
source = .ReputationSourceIdentity~new("SRC/NEWS+1", "NEWS", "News One", "GROUP", "OWNER", "GB", "EDITORIAL_REPORTING", "ep")
source~seal
envelope = .ReputationRawEnvelope~new("ENV-1", source, now, now, "TEXT/PLAIN", "https://news.example/a", "EN", "abcd")
envelope~addSegment("HEADLINE", "Synthetic test")
envelope~seal
rawResult = bridge~publishRaw(envelope)
call must rawResult, "publish raw"
rawPackage = manager~browse("REP.RAW", "admin")
call must rawPackage, "browse raw"
call same envelope, rawPackage~value~payload, "raw payload remains same object"
call eq "RAW", rawPackage~value~headers["reputation.feed.kind"], "raw kind header"
call eq "reputation.feed/0.12", rawPackage~value~headers["reputation.feed.api"], "feed API header"
call eq "RAW_EVIDENCE_ONLY", rawPackage~value~headers["reputation.feed.authority_boundary"], "raw boundary header"
call eq "reputation/feed/raw/news/src_news_1/env-1", rawPackage~value~headers["oqf.topic.string"], "raw deterministic topic"

claim = .ReputationFeedClaim~new("CLAIM-1", "ARTICLE-1", "FAMILY-1", "AVIATION_INCIDENT", "Synthetic claim", now, now, "GB", 81, "ASSERTS", "ACTIVE", "SRC/NEWS+1", "https://news.example/a")
claim~addSubject("MANUFACTURER", "BOEING", 90)
claim~addConcept("CABIN_OPENING")
claim~addAffectedGeography("GB")
claim~seal
claimResult = bridge~publishClaim(claim)
call must claimResult, "publish claim"
claimPackage = manager~browse("REP.CLAIM", "admin")
call must claimPackage, "browse claim"
call same claim, claimPackage~value~payload, "claim payload remains same object"
call eq "CLAIM_NOT_FACT", claimPackage~value~headers["reputation.feed.authority_boundary"], "claim boundary"

hypothesis = .ReputationEventHypothesis~new("HYP-1", "AVIATION_INCIDENT")
hypothesis~addClaim(claim)
hypothesis~seal
hypResult = bridge~publishHypothesis(hypothesis)
call must hypResult, "publish hypothesis"
hypPackage = manager~browse("REP.HYP", "admin")
call must hypPackage, "browse hypothesis"
call same hypothesis, hypPackage~value~payload, "hypothesis payload remains same object"
call eq "HYPOTHESIS_NOT_EVENT", hypPackage~value~headers["reputation.feed.authority_boundary"], "hypothesis boundary"

correction = .ReputationFeedCorrection~new("CORR-1", "CLAIM-1", "RETRACTION", "", now, "SRC/NEWS+1", 100, "Synthetic retraction")
correction~seal
corrResult = bridge~publishCorrection(correction)
call must corrResult, "publish correction"
corrPackage = manager~browse("REP.CORR", "admin")
call must corrPackage, "browse correction"
call same correction, corrPackage~value~payload, "correction payload remains same object"
call eq "HISTORY_SUPERSESSION_EVIDENCE", corrPackage~value~headers["reputation.feed.authority_boundary"], "correction boundary"

match = .ReputationWatchMatch~new("WATCH-1", "HYP-1", .true, 90, .true, 1, 1, 1)
alertResult = bridge~publishWatchMatch(match)
call must alertResult, "publish alert"
alertPackage = manager~browse("REP.ALERT", "admin")
call must alertPackage, "browse alert"
call same match, alertPackage~value~payload, "alert payload remains same object"
call eq "WATCH_SIGNAL_NOT_DISPOSITION", alertPackage~value~headers["reputation.feed.authority_boundary"], "alert boundary"

packet=.ReputationInteractionEvidencePacket~new('PACKET-1','INTERACTION_EVENT','CRM-CHAT','IE-1','INTERACTION_EVENT:IE-1','CHAT','CRM.POST','OUTBOUND',now,now,'GB')
packet~addContentItem(.ReputationInteractionEvidenceItem~new('INT-ITEM-1','UTTERANCE_SEGMENT','deidentified','ORGANISATION','RAW','AGENT_OUTPUT',90,'INTERACTION_EVENT:IE-1'))
packet~seal
intResult=bridge~publishInteractionEvidence(packet)
call must intResult,'publish interaction evidence'
intPackage=manager~browse('REP.INT','admin')
call must intPackage,'browse interaction evidence'
call same packet,intPackage~value~payload,'interaction evidence remains same object'
call eq 'INTERACTION_EVIDENCE',intPackage~value~headers['reputation.feed.kind'],'interaction kind header'
call eq 'PRIVACY_PROJECTED_INTERACTION_EVIDENCE_NOT_DISPOSITION',intPackage~value~headers['reputation.feed.authority_boundary'],'interaction boundary'
call eq 'reputation/feed/interactions/interaction_event/crm-chat/packet-1',intPackage~value~headers['oqf.topic.string'],'interaction deterministic topic'

trace=.ReputationFeedDecisionTrace~new('TRACE-QUEUE',.nil,'HYP-1','QUEUE_TEST')~seal
decResult=bridge~publishDecisionTrace(trace)
call must decResult,'publish decision trace'
decPackage=manager~browse('REP.DEC','admin')
call must decPackage,'browse decision trace'
call same trace,decPackage~value~payload,'decision trace remains same object'
call eq 'DECISION_TRACE',decPackage~value~headers['reputation.feed.kind'],'decision kind header'
call eq 'GOVERNED_DECISION_AUDIT_NOT_DISPOSITION',decPackage~value~headers['reputation.feed.authority_boundary'],'decision boundary'
call eq 'reputation/feed/decisions/unknown/unknown/trace-queue',decPackage~value~headers['oqf.topic.string'],'decision deterministic topic'
call true manager~payloadCodec~canEncode(trace),'bridge registered decision trace persistence type'

unsealed = .ReputationFeedClaim~new("CLAIM-UNSEALED", "A", "F", "AVIATION_INCIDENT")
rejected = bridge~publishClaim(unsealed)
call false rejected~ok, "unsealed claim rejected"
call eq "REPUTATION_FEED_PAYLOAD_UNSEALED", rejected~code, "unsealed rejection code"

badManager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
badTopics = .QueueTopicFabric~new(badManager)
call must badTopics~defineTopic("REPUTATION_FEED", "wrong/root", "TEMPORARY", "REP", "admin"), "define wrong topic"
badBridge = .ReputationFeedQueueBridge~new(badTopics, "REPUTATION_FEED", "admin")
bad = badBridge~publishRaw(envelope)
call false bad~ok, "wrong topic root rejected"
call eq "REPUTATION_FEED_TOPIC_CONTRACT_MISMATCH", bad~code, "wrong root code"


persistOptions = .table~new
persistOptions["persistent"] = .true
persistLive = bridge~publishClaim(claim, persistOptions)
call must persistLive, "persistent-capable claim passes explicit restore contract on temporary fabric"
call true manager~payloadCodec~canEncode(claim), "bridge registered claim persistence type"
call eq "reputation.feed.claim/1", claim~queuePersistentType, "claim persistence identity"

adoption = .AlchemyAdoptionVerifier~verify(bridge, "STANDARD")
call true adoption~ok, "queue bridge adopts Alchemy v0.8"
call eq "0.8", adoption~evidence["base_version"], "queue bridge base version"
call eq "INIT", adoption~evidence["construction_provenance"]["entrypoint"], "queue bridge preferred base construction"
call eq 0, adoption~warnings~items, "queue bridge adoption warnings"

say "PASS test_queue_fabric_bridge payload_identity=7 authority_boundary=preserved persistence=registered decision_trace=1"
exit 0

must: procedure
  use arg op, label
  if \op~ok then do; say "FAIL:" label op~code op~detail; exit 1; end
  return
same: procedure
  use arg expected, actual, label
  if expected \== actual then do; say "FAIL:" label; exit 1; end
  return
true: procedure
  use arg value, label
  if \value then do; say "FAIL:" label; exit 1; end
  return
false: procedure
  use arg value, label
  if value then do; say "FAIL:" label; exit 1; end
  return
eq: procedure
  use arg expected, actual, label
  if expected \== actual then do; say "FAIL:" label "expected="expected "actual="actual; exit 1; end
  return

::requires "ReputationFeedQueueBridge.cls"
::requires "AlchemyAdoption.cls"

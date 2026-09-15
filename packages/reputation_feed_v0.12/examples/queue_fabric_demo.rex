manager = .ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
ignore = manager~createQueue("REP.DEMO", "TEMPORARY", "REP", 10, "admin")
topics = .QueueTopicFabric~new(manager)
ignore = topics~defineTopic("REPUTATION_FEED", "reputation/feed", "TEMPORARY", "REP", "admin")
ignore = topics~subscribe("REP.DEMO.SUB", "REPUTATION_FEED", "claims/#", "REP.DEMO", "TEMPORARY", "admin")
bridge = .ReputationFeedQueueBridge~new(topics, "REPUTATION_FEED", "admin")
now = .DateTime~new
claim = .ReputationFeedClaim~new("DEMO-CLAIM", "ARTICLE-1", "FAMILY-1", "AVIATION_INCIDENT", "Synthetic queue demo", now, now, "GB", 82, "ASSERTS", "ACTIVE", "NEWS-1", "demo://claim")
claim~addConcept("CABIN_OPENING")
claim~seal
pub = bridge~publishClaim(claim)
package = manager~browse("REP.DEMO", "admin")~value
say "api=" || package~headers["reputation.feed.api"]
say "topic=" || package~headers["oqf.topic.string"]
say "payload_class=" || package~payload~class~id
say "payload_same_object=" || (package~payload == claim)
say "authority_boundary=" || package~headers["reputation.feed.authority_boundary"]
say "persistent_type=" || claim~queuePersistentType
say "persistent_codec_capable=" || manager~payloadCodec~canEncode(claim)
exit 0
::requires "ReputationFeedQueueBridge.cls"

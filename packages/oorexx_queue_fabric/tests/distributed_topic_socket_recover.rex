parse arg storeRoot
codec = .QueueGraphPayloadCodec~new
ignore = .QueueDistributedTopicSupport~registerTypes(codec)
manager = .ObjectQueueManager~new(storeRoot, codec, "admin")
channels = .QueueChannelFabric~new("QM.B", manager, .QueueInProcessTransport~new, "admin")
topics = .QueueTopicFabric~new(manager, "admin")
remote = .QueueDistributedTopicFabric~new("QM.B", manager, topics, channels, "DT.CTRL", "DT.PUB", "DT.DIST", "admin")
package = manager~browse("B.SUB", "admin")~value
say "depth=" || manager~depth("B.SUB", "admin")~value["ready"] || ";receipts=" || remote~receipts~items || ";order=" || package~payload["order"] || ";step2=" || package~payload["steps"][2]
exit 0
::requires "ObjectQueueDistributedTopics.cls"

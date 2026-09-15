/* Queue-neutral dispatch envelope. Queue Fabric remains transport authority. */
::class JobNodeDispatchEnvelope public
::attribute jobId get
::attribute ownerNodeId get
::attribute executionNodeId get
::attribute placementId get
::attribute placementLease get
::attribute payload get
::method init
  expose jobId ownerNodeId executionNodeId placementId placementLease payload
  use strict arg placementLease, payloadArg
  jobId=placementLease~jobId; ownerNodeId=placementLease~ownerNodeId
  executionNodeId=placementLease~nodeId; placementId=placementLease~placementId
  payload=payloadArg
::method canonicalHeader
  expose jobId ownerNodeId executionNodeId placementId
  return "job="||jobId||";owner="||ownerNodeId||";execution="||executionNodeId||";placement="||placementId
::requires "JobNodeAllocator.cls"

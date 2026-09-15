/* Queue Fabric v0.9-dev4 dispatch adapter.
 * Placement chooses the execution node; Queue Fabric remains transport owner.
 */
::class JobNodeQueueFabricDispatcher public
::method init
  expose manager queueMap
  use arg managerArg
  manager=managerArg
  queueMap=.directory~new
::method bindNodeQueue
  expose queueMap
  use arg nodeId, queueName
  queueMap[nodeId~string~upper]=queueName~string
  return self
::method dispatch
  expose manager queueMap
  use arg envelope, principal="", options=.nil
  if envelope==.nil then return .QueueOperationResult~failure("PLACEMENT_ENVELOPE_REQUIRED")
  lease=envelope~placementLease
  if lease==.nil then return .QueueOperationResult~failure("PLACEMENT_LEASE_REQUIRED")
  if envelope~executionNodeId<>lease~nodeId then return .QueueOperationResult~failure("PLACEMENT_NODE_MISMATCH")
  if envelope~jobId<>lease~jobId then return .QueueOperationResult~failure("PLACEMENT_JOB_MISMATCH")
  q=queueMap[lease~nodeId~string~upper]
  if q==.nil then return .QueueOperationResult~failure("EXECUTION_QUEUE_UNBOUND",lease~nodeId)
  if options==.nil then options=.table~new
  else options=options~copy
  h=options["headers"]
  if h==.nil then h=.table~new
  else h=h~copy
  h["job-node-placement-id"]=lease~placementId
  h["job-node-owner-node-id"]=lease~ownerNodeId
  h["job-node-execution-node-id"]=lease~nodeId
  h["job-node-capability-generation"]=lease~capabilityGeneration
  h["job-node-capacity-observation-generation"]=lease~capacityObservationGeneration
  h["job-node-ownership-epoch"]=lease~ownershipEpoch
  h["job-node-renewal-sequence"]=lease~renewalSequence
  options["headers"]=h
  options["correlationId"]=lease~placementId
  return manager~put(q,envelope,options,principal)

::requires "JobNodeDispatch.cls"
::requires "ObjectQueueFabric.cls"

/* Skeleton: the application owns its stable definition and NEW executor.
 * Real registries/admission/ownership authorities are supplied by deployment. */

now=time('T')*1000
startRequest=.MigratableJobStartRequest~new('start-001','NEW',JOB_ID,DEFINITION_REF,PARTITION_ID,'',now)

plan=placementTool~plan(startRequest,now,'op-plan-001')
if \plan~ok then do
  say 'No eligible node:' plan~code
  exit 2
end
say 'Advisory candidate:' plan~plan~recommendedNodeId

placed=placementTool~allocate(startRequest,now,30000,'op-allocate-001')
if \placed~ok then do
  say 'Placement denied:' placed~code
  exit 3
end
say 'Authoritative placement:' placed~lease~nodeId placed~lease~placementId 'epoch' placed~lease~ownershipEpoch

started=placementTool~start(startRequest,placed~lease,now,'op-start-001')
if \started~ok then do
  say started~code started~detail
  say 'Placement held:' started~placementHeld
  exit 4
end
say 'RUNNING' started~startResult~executionRef

::requires 'MigratableJobManagedPlacement.cls'

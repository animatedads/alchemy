/* RexxOS / Job-to-Node / Memory Fabric projection for media experiments.
 *
 * This adapter creates execution envelopes.  It does not allocate a node,
 * issue or renew a lease, satisfy Memory Fabric horizon demands, or execute
 * media code.  Those authorities remain in their owning components.
 */

::class MediaExperimentFabricEnvelope public
::method init
  expose task memorySession placementRequest
  use strict arg taskArg, memorySessionArg, placementRequestArg
  if \taskArg~isA(.MediaExperimentTask) then raise syntax 93.900 array("MediaExperimentTask required")
  task=taskArg
  memorySession=memorySessionArg
  placementRequest=placementRequestArg
::attribute task get
::attribute memorySession get
::attribute placementRequest get

::class MediaExperimentFabricProjection public
::method project
  use strict arg task, memoryObjectId, memoryEpoch=1, backingRef="", ownerNodeId="", deadlineEpochMs=0, policyTags=.nil, jurisdictions=.nil, legalDomains=.nil, trustDomains=.nil, authorities=.nil, exactRuntimeGeneration=""
  if \task~isA(.MediaExperimentTask) then raise syntax 93.900 array("MediaExperimentTask required")
  session=.MediaMethodologyMemoryFabricSession~new(task~workUnit,memoryObjectId,memoryEpoch,backingRef)
  profile=task~selection~implementationProfile
  jobProjection=.MediaMethodologyJobNodeProjection~new
  request=jobProjection~request(task~workUnit,profile,ownerNodeId,deadlineEpochMs,policyTags,jurisdictions,legalDomains,trustDomains,authorities,exactRuntimeGeneration)
  return .MediaExperimentFabricEnvelope~new(task,session,request)

/* Record facts after the real placement/execution authorities have acted.
 * NODEEVIDENCE is detached RexxOS evidence, not a lease.  PLACEMENTREF is the
 * caller's authoritative placement/lease reference. */
::method recordCompletion
  use strict arg envelope, nodeEvidence, placementRef, outputRef, memoryEpoch, sourceRefs=.nil, supportMapRef=.nil, uncertaintyRef=.nil, metadata=.nil
  if \envelope~isA(.MediaExperimentFabricEnvelope) then raise syntax 93.900 array("MediaExperimentFabricEnvelope required")
  if \nodeEvidence~isA(.MediaRexxOSNodeEvidence) then raise syntax 93.900 array("MediaRexxOSNodeEvidence required")
  task=envelope~task
  selection=task~selection
  profile=selection~implementationProfile
  provenance=.MediaExecutionProvenance~new(task~workUnit~workId,selection~methodologyId,profile~implementationId,nodeEvidence~semanticRef,nodeEvidence~incarnation,placementRef,envelope~memorySession~sparseObject~objectId,memoryEpoch,sourceRefs,outputRef,"COMPLETED")
  provenanceRefs=.Array~of(provenance)
  workIds=.Array~of(task~workUnit~workId)
  candidateId=task~taskId||"#OUTPUT"
  candidate=.MediaExperimentCandidate~new(candidateId,task~experimentId,task~lineageId,selection~methodologyId,profile~implementationId,"SHARD",workIds,outputRef,supportMapRef,uncertaintyRef,provenanceRefs,metadata)
  bundle=.Directory~new
  bundle["PROVENANCE"]=provenance
  bundle["CANDIDATE"]=candidate
  return bundle

::requires "MediaMethodologyExperiments.cls"
::requires "MediaMethodologyMemoryFabric.cls"
::requires "MediaMethodologyJobNode.cls"
::requires "MediaMethodologyRexxOS.cls"

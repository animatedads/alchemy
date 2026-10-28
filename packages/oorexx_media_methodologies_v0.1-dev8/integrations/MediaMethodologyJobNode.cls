/* Optional Job-to-Node projection.
 *
 * This adapter translates provider-declared implementation requirements into
 * the existing Job-to-Node hard-requirement object.  It does not score nodes,
 * allocate, renew, release or issue a lease.  JobNodeAllocator remains the
 * placement/admission authority.
 */
::class MediaMethodologyJobNodeProjection public
::method requirement
  use strict arg profile, jurisdictions=.nil, legalDomains=.nil, trustDomains=.nil, authorities=.nil, exactRuntimeGeneration=""
  if \profile~isA(.MediaImplementationExecutionProfile) then raise syntax 93.900 array("MediaImplementationExecutionProfile required")
  runtimes=.Array~new
  if profile~runtime<>"" then runtimes~append(profile~runtime)
  return .JobNodeRequirement~new(jurisdictions,legalDomains,trustDomains,authorities,profile~requiredAbilities,runtimes,profile~requiredTags,profile~architecture,profile~minimumMemoryMiB,profile~minimumDiskMiB,profile~minimumCpuUnits,profile~minimumFreeMemoryMiB,profile~minimumFreeDiskMiB,profile~minimumAvailableCpuUnits,profile~minimumWluRate,.nil,exactRuntimeGeneration)

::method request
  use strict arg workUnit, profile, ownerNodeId="", deadlineEpochMs=0, policyTags=.nil, jurisdictions=.nil, legalDomains=.nil, trustDomains=.nil, authorities=.nil, exactRuntimeGeneration=""
  req=self~requirement(profile,jurisdictions,legalDomains,trustDomains,authorities,exactRuntimeGeneration)
  jobId="media:"||workUnit~workId||":"||profile~implementationId
  return .JobPlacementRequest~new(jobId,req,ownerNodeId,profile~expectedMicroWlu,profile~minimumWluRate,deadlineEpochMs,policyTags)

::requires "MediaMethodologyExecution.cls"
::requires "JobNodeAllocator.cls"

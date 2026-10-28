/* Non-authoritative projection from a media experiment task into Generalized
 * Compute Intentions.  Planning never becomes placement or execution authority.
 *
 * API: media.methodologies.generalized-compute/0.1
 */

::class MediaComputePlanningWorkload public
::method init
  expose task executionProfile sourceRefs attributes
  use strict arg taskArg,executionProfileArg,sourceRefsArg=.nil,attributesArg=.nil
  task=taskArg
  executionProfile=executionProfileArg
  sourceRefs=.Array~new
  if sourceRefsArg<>.nil then do ref over sourceRefsArg; sourceRefs~append(ref); end
  if attributesArg=.nil then attributesArg=.Directory~new
  attributes=attributesArg
::attribute task get
::attribute executionProfile get
::method sourceRefs
  expose sourceRefs
  return sourceRefs~copy
::method attributes
  expose attributes
  return attributes
::method methodologyId
  expose task
  return task~methodologyId

::class MediaComputePlanningObservation public
::method init
  expose workload route handoff mutationAuthority revalidationRequired
  use strict arg workloadArg,routeArg,handoffArg=.nil
  workload=workloadArg
  route=routeArg
  handoff=handoffArg
  mutationAuthority="NONE"
  revalidationRequired=.true
::attribute workload get
::attribute route get
::attribute handoff get
::attribute mutationAuthority get
::attribute revalidationRequired get
::method ready
  expose route
  if route=.nil then return .false
  return route~state="READY"

::class MediaGeneralizedComputeBridge public
::method workload
  use strict arg task,executionProfile,sourceRefs=.nil,attributes=.nil
  return .MediaComputePlanningWorkload~new(task,executionProfile,sourceRefs,attributes)

::method plan
  use strict arg planner,task,executionProfile,sourceRefs=.nil,context=.nil
  if planner=.nil then raise syntax 93.900 array("Generalized compute planner is required")
  work=self~workload(task,executionProfile,sourceRefs)
  route=planner~planAdmittance(work,context)
  return .MediaComputePlanningObservation~new(work,route)

::method prepare
  use strict arg planner,task,executionProfile,sourceRefs=.nil,context=.nil
  if planner=.nil then raise syntax 93.900 array("Generalized compute planner is required")
  work=self~workload(task,executionProfile,sourceRefs)
  route=planner~planAdmittance(work,context)
  handoff=.nil
  if route~state="READY" then handoff=route~handoff
  observation=.MediaComputePlanningObservation~new(work,route,handoff)
  if handoff<>.nil then do
    if \handoff~revalidationRequired then raise syntax 93.900 array("Generalized compute handoff must require authoritative revalidation")
  end
  return observation

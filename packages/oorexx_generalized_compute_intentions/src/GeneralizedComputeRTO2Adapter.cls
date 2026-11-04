/* Generalized Compute Intentions v0.1-dev8
 * Optional read-only projection from RexxOS RTO2 Grid estate membership.
 *
 * RTO2 owns current MU/MI membership and incarnation evidence.  This adapter
 * exposes current MI members as compute candidates without turning membership
 * into WLU admission, Job-to-Node placement, lease, ACTIVE/SPARE, dispatch or
 * execution authority.  MU members remain estate/control members and are not
 * projected as worker candidates.
 */

::class RexxOSGridComputeResource public
::method init
  expose member
  use strict arg memberArg
  if memberArg == .nil then raise syntax 93.900 array('RTO2 Grid member is required')
  member = memberArg
  if \member~hasMethod('memberKind') | \member~hasMethod('memberId') | -
     \member~hasMethod('incarnation') | \member~hasMethod('semanticRef') then -
      raise syntax 93.900 array('RTO2 Grid member lacks required identity surface')
  if member~memberKind \= 'MI' then raise syntax 93.900 array('Only RTO2 MI members are compute resources')

::attribute member get

::method id
  expose member
  return member~memberId

::method semanticRef
  expose member
  return member~semanticRef

::method incarnation
  expose member
  return member~incarnation

::method managementUnitId
  expose member
  if member~hasMethod('managementUnitId') then return member~managementUnitId
  return ''

::method membershipState
  expose member
  if member~hasMethod('membershipState') then return member~membershipState
  return ''

::class RexxOSGridMemberEligibilityPolicy public
::method assess abstract

::class RexxOSGridComputeProjectionAdapter subclass ComputeIntentionAdapter
::method init
  expose controller eligibilityPolicy
  use strict arg controllerArg, eligibilityPolicyArg
  if controllerArg == .nil then raise syntax 93.900 array('RTO2 Grid estate controller is required')
  if eligibilityPolicyArg == .nil then raise syntax 93.900 array('RTO2 Grid member eligibility policy is required')
  if \controllerArg~hasMethod('estateMembers') then raise syntax 93.900 array('RTO2 Grid controller must expose estateMembers')
  if \eligibilityPolicyArg~hasMethod('assess') then raise syntax 93.900 array('RTO2 Grid eligibility policy must expose assess')
  controller = controllerArg
  eligibilityPolicy = eligibilityPolicyArg

::method discoverCandidates
  expose controller
  use strict arg workload, context=.nil
  out = .array~new
  members = controller~estateMembers
  if members == .nil then return out
  do member over members
    if member == .nil then iterate
    if \member~hasMethod('memberKind') then iterate
    if member~memberKind \= 'MI' then iterate
    out~append(.RexxOSGridComputeResource~new(member))
  end
  return out

::method discoveryEvidence
  expose controller
  use strict arg workload, context=.nil
  if controller~hasMethod('estateSnapshot') then return controller~estateSnapshot
  return .nil

::method assess
  expose eligibilityPolicy
  use strict arg workload, resource, context=.nil
  authority = 'REXXOS_GRID'
  if resource == .nil | \resource~isA(.RexxOSGridComputeResource) then -
      return .IntentionAssessment~new(.false, authority, 'RTO2_MI_RESOURCE_REQUIRED', resource)

  current = self~currentMember(resource)
  if current == .nil then -
      return .IntentionAssessment~new(.false, authority, 'RTO2_MEMBER_ABSENT_OR_REINCARNATED', resource~member)

  assessment = eligibilityPolicy~assess(current, workload, context)
  if assessment == .nil | \assessment~hasMethod('allows') then -
      raise syntax 93.900 array('RTO2 Grid eligibility policy must return an IntentionAssessment-shaped object')
  return assessment

::method currentMember private
  expose controller
  use strict arg resource
  members = controller~estateMembers
  if members == .nil then return .nil
  wantedId = resource~id
  wantedIncarnation = resource~incarnation
  do member over members
    if member == .nil then iterate
    if \member~hasMethod('memberKind') | \member~hasMethod('memberId') | \member~hasMethod('incarnation') then iterate
    if member~memberKind \= 'MI' then iterate
    if member~memberId = wantedId & member~incarnation = wantedIncarnation then return member
  end
  return .nil

::requires 'GeneralizedComputeIntentions.cls'

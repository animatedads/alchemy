/* RTO2 Grid -> GCI compute projection.
 * MU membership is not worker capacity.  MI membership is candidate evidence
 * only; eligibility is policy-owned and stale/reincarnated members fail closed.
 */
snapshot=.directory~new
snapshot['grid_id']='ED209'
mu=.FakeGridMember~new('MU-ED209F','MU','1','', 'CURRENT','rexxos://ED209/mu/MU-ED209F')
mi1=.FakeGridMember~new('MN1-ED209F','MI','17','MU-ED209F','CURRENT','rexxos://ED209/mu/MU-ED209F/mi/MN1-ED209F')
mi2=.FakeGridMember~new('MN2-ED209F','MI','18','MU-ED209F','STALE','rexxos://ED209/mu/MU-ED209F/mi/MN2-ED209F')
controller=.FakeGridController~new(.array~of(mu,mi1,mi2),snapshot)
projection=.RexxOSGridComputeProjectionAdapter~new(controller,.FakeGridEligibility~new)
allow=.AlwaysAllow~new
planner=.GeneralizedComputeIntentionProvider~new(projection,allow,allow,allow)

route=planner~planAdmittance(.Object~new)
call assertEqual 2,route~candidates~items,'only MI members become compute candidates'
call assertTrue route~candidates[1]~resource~member == mi1,'native MI object retained'
call assertTrue route~discoveryEvidence == snapshot,'native estate snapshot retained'
call assertTrue route~candidates[1]~isAdmissible,'current MI can pass compute evidence'
call assertTrue \route~candidates[2]~isAdmissible,'policy-stale MI remains inadmissible'
call assertEqual 'READY',route~state,'one current MI makes route plan-ready'
call assertEqual 'MN1-ED209F',route~preferredCandidate~resource~id,'current MI preferred'
call assertEqual '17',route~preferredCandidate~resource~incarnation,'incarnation retained'

mi1new=.FakeGridMember~new('MN1-ED209F','MI','18','MU-ED209F','CURRENT','rexxos://ED209/mu/MU-ED209F/mi/MN1-ED209F')
controller~members=.array~of(mu,mi1new)
oldAssessment=projection~assess(.Object~new,route~candidates[1]~resource)
call assertTrue \oldAssessment~allows,'old incarnation fails closed'
call assertEqual 'RTO2_MEMBER_ABSENT_OR_REINCARNATED',oldAssessment~reason,'stale incarnation reason'

route2=planner~planAdmittance(.Object~new)
call assertEqual 1,route2~candidates~items,'membership dynamically rediscovered'
call assertTrue route2~candidates[1]~resource~member == mi1new,'new incarnation object retained'
call assertEqual '18',route2~candidates[1]~resource~incarnation,'new incarnation visible'

say 'PASS RTO2 Grid MI compute projection preserves membership authority boundary'
exit 0

assertEqual: procedure
  use strict arg expected,actual,label
  if expected \= actual then raise syntax 93.900 array('assertEqual failed:' label 'expected='expected 'actual='actual)
  return
assertTrue: procedure
  use strict arg value,label
  if value \== .true then raise syntax 93.900 array('assertTrue failed:' label)
  return

::class FakeGridMember
::method init
  expose memberId memberKind incarnation managementUnitId membershipState semanticRef
  use strict arg memberId,memberKind,incarnation,managementUnitId,membershipState,semanticRef
::attribute memberId get
::attribute memberKind get
::attribute incarnation get
::attribute managementUnitId get
::attribute membershipState get
::attribute semanticRef get

::class FakeGridController
::method init
  expose members snapshot
  use strict arg members,snapshot
::attribute members
::method estateMembers
  expose members
  return members
::method estateSnapshot
  expose snapshot
  return snapshot

::class FakeGridEligibility subclass RexxOSGridMemberEligibilityPolicy
::method assess
  use strict arg member,workload,context=.nil
  if member~membershipState = 'CURRENT' then -
      return .IntentionAssessment~new(.true,'REXXOS_GRID','RTO2_MI_CURRENT',member)
  return .IntentionAssessment~new(.false,'REXXOS_GRID','RTO2_MI_NOT_CURRENT',member)

::class AlwaysAllow
::method assess
  use arg workload,resource,context=.nil
  return .IntentionAssessment~new(.true,'test-authority','ALLOW',resource)

::requires '../src/GeneralizedComputeRTO2Adapter.cls'

/* Read-only RexxOS Grid evidence adapter for media execution planning.
 *
 * RexxOS estate membership is discovery/evidence.  This object does not infer
 * capacity from the profile, mutate membership, or choose a placement.
 */
::class MediaRexxOSNodeEvidence public
::method init
  expose semanticRef incarnation memberId managementUnitId membershipState profile
  use strict arg estateMember
  if \estateMember~isA(.RexxOSGridEstateMember) then raise syntax 93.900 array("RexxOSGridEstateMember required")
  if estateMember~memberKind<>"MI" then raise syntax 93.900 array("Media execution node evidence requires an MI member")
  semanticRef=estateMember~semanticRef
  incarnation=estateMember~incarnation
  memberId=estateMember~memberId
  managementUnitId=estateMember~managementUnitId
  membershipState=estateMember~membershipState
  profile=estateMember~profile
::attribute semanticRef get
::attribute incarnation get
::attribute memberId get
::attribute managementUnitId get
::attribute membershipState get
::method profile
  expose profile
  return .RexxOSGridObjectGraph~copy(profile)

::class MediaRexxOSNodeDiscovery public
::method discover
  use strict arg estateController
  answer=.Array~new
  do member over estateController~estateMembers
    if member~memberKind="MI" then answer~append(.MediaRexxOSNodeEvidence~new(member))
  end
  return answer

::requires "RexxOSGridEstateMember.cls"
::requires "RexxOSGridObjectGraph.cls"

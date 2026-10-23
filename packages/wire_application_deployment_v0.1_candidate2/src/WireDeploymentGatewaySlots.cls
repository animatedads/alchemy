/* WireUIWebAccessPointBinding remains the real bridge. No second manager. */
::class WireDeploymentGatewaySlots public
::method init
  expose slots
  slots=.directory~new
::method generation unguarded
  expose slots
  use strict arg appId
  if \slots~hasIndex(appId) then return ''
  return slots[appId][1]
::method binding unguarded
  expose slots
  use strict arg appId
  if \slots~hasIndex(appId) then return .nil
  return slots[appId][2]
::method publish guarded
  expose slots
  use strict arg appId,generation,binding,expected=''
  if appId=='' | generation=='' | binding==.nil then return .false
  if \binding~hasMethod('BROWSERBOOTSTRAP') | \binding~hasMethod('PROVISION') then return .false
  old=slots[appId]
  if old==.nil then do
    if expected<>'' then return .false
  end
  else do
    if old[1]<>expected | old[1]==generation then return .false
  end
  slots[appId]=.array~of(generation,binding)
  return .true
::method retire guarded
  expose slots
  use strict arg appId,expected
  if \slots~hasIndex(appId) then return .false
  if slots[appId][1]<>expected then return .false
  slots~remove(appId)
  return .true
::method browserBootstrap unguarded
  expose slots
  use strict arg appId,publicGatewayUrl
  if \slots~hasIndex(appId) then return .nil
  return slots[appId][2]~browserBootstrap(publicGatewayUrl)

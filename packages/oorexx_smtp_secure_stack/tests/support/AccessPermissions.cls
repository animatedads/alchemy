/* Test-only API-shape fixture for oorexx_access_permissions_v0.2. */
::class AccessControlRequest public
::attribute requestId get
::attribute principalId get
::attribute domainId get
::attribute action get
::method init
  expose requestId principalId domainId action attributes sealed
  use strict arg requestIdArg,principalIdArg,domainIdArg,actionArg,intendedAt
  requestId=requestIdArg; principalId=principalIdArg; domainId=domainIdArg; action=actionArg; attributes=.directory~new; sealed=.false
::method putAttribute
  expose attributes
  use strict arg name,value
  attributes[name]=value; return self
::method attribute
  expose attributes
  use strict arg name
  return attributes[name]
::method seal
  expose sealed
  sealed=.true; return self

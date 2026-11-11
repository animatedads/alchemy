/* A fail-closed, renderer-neutral committed-definition barrier.
 * Revision is an exact opaque token: do not parse, increment or infer ordering.
 * The authoritative publisher updates this gate on commit or revocation.
 * Resync is delegated to an explicitly supplied semantic target.
 */
::class WireDefinitionGate public
::method init
  expose identities resyncTarget
  use strict arg resyncTarget = .nil
  identities = .directory~new
::method publish
  expose identities
  use strict arg definitionId, definitionVersion, renderedRevision
  if definitionId == "" | definitionVersion == .nil | renderedRevision == .nil then raise syntax 88.900 array("WIRE_DEFINITION_PUBLICATION_INVALID")
  identities[definitionId] = .array~of(definitionVersion, renderedRevision)
::method revoke
  expose identities
  use strict arg definitionId
  if identities~hasIndex(definitionId) then identities~remove(definitionId)
::method authorize
  expose identities
  use strict arg event
  id = event~definitionId
  if id == .nil then return .false
  if \identities~hasIndex(id) then return .false
  expected = identities[id]
  if event~definitionVersion \== expected[1] then return .false
  if event~renderedRevision \== expected[2] then return .false
  return .true
::method requestResync
  expose resyncTarget
  use strict arg event
  if resyncTarget \== .nil then resyncTarget~requestResync(event~definitionId, event~workspaceContext)
  return .true

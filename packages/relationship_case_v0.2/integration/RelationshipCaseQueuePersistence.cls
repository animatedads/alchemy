/* Queue Fabric persistence registration for Relationship Case v0.2.
 * The core model implements a neutral queuePersistentType/state/restore
 * protocol but does not require Queue Fabric.  This adapter owns the Queue
 * Fabric dependency and restore factories.
 */
::class RelationshipCaseElementQueueFactory public
::method newBlank
  return .RelationshipCaseElement~new("RESTORE", "REFERENCE", "RESTORE", "RESTORE", "RESTORE", "RESTORE", "REFERENCE", .DateTime~new, "INTERNAL")

::class RelationshipCaseEventQueueFactory public
::method newBlank
  return .RelationshipCaseEvent~new("RESTORE", "RESTORE", "RESTORE", "RESTORE", "SYSTEM", .DateTime~new)~seal

::class RelationshipCaseQueueFactory public
::method newBlank
  return .RelationshipCase~new("RESTORE", "RESTORE", "RESTORE", .DateTime~new, "NORMAL", "INTERNAL")

::class RelationshipCaseQueuePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec == .nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  registry = codec~typeRegistry
  ignore = registry~register("relationship.case.element/1", .RelationshipCaseElementQueueFactory~new)
  ignore = registry~register("relationship.case.event/1", .RelationshipCaseEventQueueFactory~new)
  ignore = registry~register("relationship.case.case/1", .RelationshipCaseQueueFactory~new)
  return .true
::method newCodec class
  codec = .QueueGraphPayloadCodec~new
  ignore = self~registerTypes(codec)
  return codec

::requires "RelationshipCase.cls"
::requires "ObjectQueueFabric.cls"

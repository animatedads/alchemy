/* Queue Fabric graph-codec registration for Relationship CRM domain objects. */
::class CRMPolicyEvidenceFactory public
::method newBlank; return .RelationshipCRMPolicyEvidence~new("","","","")
::class CRMEventFactory public
::method newBlank; return .RelationshipCRMEvent~new("","","","","","",.DateTime~new)
::class CRMRelationshipFactory public
::method newBlank; return .RelationshipRecord~new("RESTORE","RESTORE","RESTORE")
::class CRMInteractionFactory public
::method newBlank; return .RelationshipInteractionRef~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",.DateTime~new)
::class CRMCommunicationFactory public
::method newBlank; return .RelationshipCommunication~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class CRMPromiseFactory public
::method newBlank; return .RelationshipPromise~new("RESTORE","RESTORE","RESTORE",.DateTime~new,"RESTORE","RESTORE")
::class CRMTaskFactory public
::method newBlank; return .RelationshipTask~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE",.DateTime~new)
::class CRMComplaintFactory public
::method newBlank; return .ComplaintRecord~new("RESTORE","RESTORE","RESTORE",.DateTime~new)
::class CRMServiceProfileFactory public
::method newBlank; return .RelationshipServiceProfile~new("RESTORE","RESTORE","RESTORE","RESTORE","RESTORE")
::class CRMProjectionFactory public
::method newBlank; return .RelationshipCRMProjection~new(.RelationshipRecord~new("RESTORE","RESTORE","RESTORE"),"RESTORE",.false)

::class RelationshipCRMQueuePersistenceSupport public
::method registerTypes class
  use arg codec
  if codec==.nil | \codec~hasMethod("TYPEREGISTRY") then return .false
  r=codec~typeRegistry
  ignore=r~register("relationship.crm.policy.evidence/1",.CRMPolicyEvidenceFactory~new)
  ignore=r~register("relationship.crm.event/1",.CRMEventFactory~new)
  ignore=r~register("relationship.crm.relationship/1",.CRMRelationshipFactory~new)
  ignore=r~register("relationship.crm.interaction/1",.CRMInteractionFactory~new)
  ignore=r~register("relationship.crm.communication/1",.CRMCommunicationFactory~new)
  ignore=r~register("relationship.crm.promise/1",.CRMPromiseFactory~new)
  ignore=r~register("relationship.crm.task/1",.CRMTaskFactory~new)
  ignore=r~register("relationship.crm.complaint/1",.CRMComplaintFactory~new)
  ignore=r~register("relationship.crm.service.profile/1",.CRMServiceProfileFactory~new)
  ignore=r~register("relationship.crm.projection/1",.CRMProjectionFactory~new)
  return .true
::method newCodec class
  codec=.QueueGraphPayloadCodec~new
  ignore=self~registerTypes(codec)
  return codec
::requires "RelationshipCRM.cls"
::requires "ObjectQueueFabric.cls"

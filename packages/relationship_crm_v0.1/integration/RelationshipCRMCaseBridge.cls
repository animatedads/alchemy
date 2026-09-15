/* Optional bridge: CRM retains relationship authority; Case gets opaque references. */
::class RelationshipCRMCaseBridge public
::method complaintElement class
  use arg elementId, crmSystem, complaint, recordedAt=.nil
  if recordedAt==.nil then recordedAt=.DateTime~new
  if complaint==.nil | \complaint~isA(.ComplaintRecord) then return .RelationshipCRMResult~failure("CRM_COMPLAINT_REQUIRED")
  e=.RelationshipCaseElement~new(elementId,"COMPLAINT","CRM_COMPLAINT_RECORD","CRM_COMPLAINT_RECORD",crmSystem,"COMPLAINT:"||complaint~complaintId,"CRM_REFERENCE",recordedAt,complaint~visibilityClass)~seal
  return .RelationshipCRMResult~success(e)
::method interactionElement class
  use arg elementId, crmSystem, interaction, recordedAt=.nil
  if recordedAt==.nil then recordedAt=.DateTime~new
  if interaction==.nil | \interaction~isA(.RelationshipInteractionRef) then return .RelationshipCRMResult~failure("CRM_INTERACTION_REQUIRED")
  e=.RelationshipCaseElement~new(elementId,"INTERACTION",interaction~semanticKind,"ORIGINATING_INTERACTION",crmSystem,"INTERACTION:"||interaction~interactionId,"CRM_INTERACTION_REFERENCE",recordedAt,interaction~visibilityClass)~seal
  return .RelationshipCRMResult~success(e)
::requires "RelationshipCRM.cls"
::requires "RelationshipCase.cls"

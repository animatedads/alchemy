/* Optional bridge from an already-authoritative Relationship Adapter
 * translation into Staff Channel orchestration.  It carries the relationship
 * authority forward; it does not replace Staff Authority. */
::class FederationBankRelationshipStaffChannelBridge public
::method requestFromTranslation class
  use arg requestId,workId,translation,staffContext
  if translation==.nil | \translation~hasMethod("OUTCOME") then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_TRANSLATION_REQUIRED")
  if staffContext==.nil | \staffContext~isA(.FederationBankStaffContextSnapshot) | \staffContext~sealed then return .FederationBankStaffChannelResult~failure("STAFF_CONTEXT_REQUIRED")
  evidence=.FederationBankStaffChannelRelationshipEvidence~fromTranslation(translation)
  if \evidence~ok then return evidence
  session=staffContext~session; staffId=staffContext~principal~staffId; command=.nil; atTime=.DateTime~new
  if translation~outcome="SUBMIT_BANK_COMMAND" then do
    bankCommand=translation~bankCommand
    if bankCommand==.nil then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_TRANSLATED_COMMAND_REQUIRED")
    if bankCommand~channel<>"STAFF" then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_COMMAND_NOT_STAFF_CHANNEL",bankCommand~channel)
    if bankCommand~actorId<>staffId then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_STAFF_ACTOR_MISMATCH")
    command=.FederationBankStaffChannelCommandSnapshot~fromCommand(bankCommand); atTime=bankCommand~requestedAt
  end
  else if translation~outcome="NO_BANK_ACTION" then do
    if translation~decision==.nil then return .FederationBankStaffChannelResult~failure("RELATIONSHIP_DECISION_REQUIRED")
    atTime=translation~decision~decidedAt
  end
  else return .FederationBankStaffChannelResult~failure("RELATIONSHIP_TRANSLATION_OUTCOME_UNSUPPORTED",translation~outcome)
  r=.FederationBankStaffChannelRequest~new(requestId,workId,"RELATIONSHIP_DECISION",staffId,session~sessionId,session~branchId,session~deskId,command,evidence~value,atTime)~seal
  return .FederationBankStaffChannelResult~success(r)
::requires "FederationBankStaffChannel.cls"
::requires "FederationBankRelationshipAdapter.cls"

/* Optional bridge: relationship/case authority and staff employment authority
 * are independent prerequisites.  This helper converts an already-translated
 * relationship bank command into the exact StaffActionIntent to be evaluated;
 * it does not treat relationship authority as staff authority. */
::class FederationBankRelationshipStaffAuthorityBridge public
::method actionFromTranslation class
  use arg actionId,translation,staffContext
  if translation==.nil | \translation~hasMethod("OUTCOME") then return .FederationBankStaffAuthorityResult~failure("RELATIONSHIP_TRANSLATION_REQUIRED")
  if translation~outcome<>"SUBMIT_BANK_COMMAND" | translation~bankCommand==.nil then return .FederationBankStaffAuthorityResult~failure("RELATIONSHIP_BANK_COMMAND_REQUIRED")
  if staffContext==.nil | \staffContext~isA(.FederationBankStaffContextSnapshot) | \staffContext~sealed then return .FederationBankStaffAuthorityResult~failure("STAFF_CONTEXT_REQUIRED")
  command=translation~bankCommand; session=staffContext~session
  if command~channel<>"STAFF" then return .FederationBankStaffAuthorityResult~failure("RELATIONSHIP_COMMAND_NOT_STAFF_CHANNEL",command~channel)
  if command~actorId<>staffContext~principal~staffId then return .FederationBankStaffAuthorityResult~failure("RELATIONSHIP_STAFF_ACTOR_MISMATCH")
  caseId=""; if command~details~hasIndex("relationshipCaseId") then caseId=command~details["relationshipCaseId"]~string
  action=.FederationBankStaffActionIntent~new(actionId,command~commandId,command~idempotencyKey,command~actorId,session~sessionId,command~operation,command~customerId,command~sourceAccountId,command~targetAccountId,command~currency,command~amountMinor,session~branchId,session~deskId,caseId,command~requestedAt,command~details)~seal
  return .FederationBankStaffAuthorityResult~success(action)
::requires "FederationBankStaffAuthority.cls"

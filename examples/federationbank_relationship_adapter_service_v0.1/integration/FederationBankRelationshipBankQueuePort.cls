/* Only Account/Payments ingress is exposed. There is intentionally no path to
 * FB.LEDGER.COMMANDS. */
::class FederationBankRelationshipBankQueuePort subclass FederationBankRelationshipBankPort public
::method init
  expose runtime
  use arg backendRuntimeArg
  runtime=backendRuntimeArg
::method submit
  expose runtime
  use arg command
  if command==.nil then return .FederationBankRelationshipServiceResult~failure("BANK_COMMAND_REQUIRED")
  select
    when command~operation="OPEN_ACCOUNT" then r=runtime~submitOpenAccount(command)
    when command~operation="ADD_BENEFICIARY" | command~operation="AMEND_BENEFICIARY" | command~operation="SUSPEND_BENEFICIARY" then r=runtime~submitAccountCommand(command)
    when command~operation="TRANSFER" | command~operation="FX_CONVERT" then r=runtime~submitTransfer(command)
    when command~operation="PLACE_HOLD" | command~operation="RELEASE_HOLD" then r=runtime~submitHold(command)
    otherwise return .FederationBankRelationshipServiceResult~failure("BANK_OPERATION_ROUTE_UNSUPPORTED",command~operation)
  end
  if r~ok then return .FederationBankRelationshipServiceResult~success(r~value)
  return .FederationBankRelationshipServiceResult~failure(r~code,r~detail)
::requires "FederationBankRelationshipAdapterService.cls"
::requires "FederationBankServices.cls"

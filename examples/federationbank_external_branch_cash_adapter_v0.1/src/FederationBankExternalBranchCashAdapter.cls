/* FederationBank External Cash -> Branch Cash Adapter v0.1
 * Narrow physical-custody bridge. External Cash owns shipment authority;
 * Branch Cash owns the actual vault. The adapter cannot invent vault dual control.
 */
::class FederationBankExternalBranchCashAdapterBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.external.branch.cash.adapter/0.1"

::class FederationBankExternalBranchCashControlRegistry public
::method init
  expose controls
  controls=.directory~new
::method put
  expose controls
  use arg shipmentId,control
  controls[shipmentId~string]=control; return control
::method control
  expose controls
  use arg shipmentId
  if controls~hasIndex(shipmentId~string) then return controls[shipmentId~string]
  return .nil

::class FederationBankExternalBranchCashVaultPort subclass FederationBankExternalCashVaultPort public
::method init
  expose branchCashService controlRegistry branchPolicy
  use arg branchCashServiceArg,controlRegistryArg,branchPolicyArg=.nil
  branchCashService=branchCashServiceArg; controlRegistry=controlRegistryArg; if branchPolicyArg==.nil then branchPolicy=.FederationBankBranchCashFixturePolicy~new; else branchPolicy=branchPolicyArg
  if branchCashService==.nil | controlRegistry==.nil then raise syntax 88.990 array("branch cash service and external control registry required")
::method branchBundle private
  use arg extBundle
  d=.directory~new; do k over extBundle~denominations; d[k]=extBundle~denominations[k]; end; return .FederationBankBranchCashBundle~new(extBundle~currency,d)
::method instruction private
  use arg shipment,authority
  if authority==.nil | \authority~isA(.FederationBankExternalCashAuthorityEnvelope) then return .FederationBankExternalCashServiceResult~failure("EXTERNAL_CASH_AUTHORITY_REQUIRED")
  if \authority~matchesShipment(shipment) then return .FederationBankExternalCashServiceResult~failure("EXTERNAL_CASH_AUTHORITY_MISMATCH")
  i=.FederationBankBranchCashExternalInstruction~new(shipment~shipmentId,shipment~branchId,shipment~direction,shipment~vaultId,shipment~bundle~totalMinor,shipment~bundle~currency,authority~semanticIdentity,shipment~manifestRef,shipment~sealId,shipment~requestedByStaffId)
  return .FederationBankExternalCashServiceResult~success(i)
::method control private
  expose controlRegistry
  use arg instruction,authority
  c=controlRegistry~control(instruction~shipmentId); if c==.nil then return .FederationBankExternalCashServiceResult~failure("VAULT_EXTERNAL_CONTROL_REQUIRED")
  if c~instructionIdentity<>instruction~semanticIdentity then return .FederationBankExternalCashServiceResult~failure("VAULT_EXTERNAL_CONTROL_MISMATCH")
  if c~externalAuthorityRef<>authority~semanticIdentity then return .FederationBankExternalCashServiceResult~failure("VAULT_EXTERNAL_AUTHORITY_MISMATCH")
  return .FederationBankExternalCashServiceResult~success(c)
::method vault private
  expose branchCashService
  use arg shipment
  v=branchCashService~state~vault(shipment~vaultId); if v==.nil then return .FederationBankExternalCashServiceResult~failure("BRANCH_VAULT_NOT_FOUND")
  if v~branchId<>shipment~branchId | v~currency<>shipment~bundle~currency then return .FederationBankExternalCashServiceResult~failure("BRANCH_VAULT_SCOPE_MISMATCH")
  return .FederationBankExternalCashServiceResult~success(v)
::method apply private
  expose branchPolicy
  use arg shipment,authority,receipt=.nil
  ir=self~instruction(shipment,authority); if \ir~ok then return ir; i=ir~value
  cr=self~control(i,authority); if \cr~ok then return cr
  if shipment~direction="INBOUND" then if receipt==.nil | \receipt~matchesShipment(shipment) then return .FederationBankExternalCashServiceResult~failure("RECEIPT_MISMATCH")
  vr=self~vault(shipment); if \vr~ok then return vr; v=vr~value
  r=v~applyExternalCash(i,self~branchBundle(shipment~bundle),cr~value,branchPolicy)
  if \r~ok then return .FederationBankExternalCashServiceResult~failure("BRANCH_CASH_"||r~code,r~detail,r~value)
  return .FederationBankExternalCashServiceResult~success(v)
::method releaseOutbound
  use arg shipment,authority
  if shipment~direction<>"OUTBOUND" then return .FederationBankExternalCashServiceResult~failure("OUTBOUND_SHIPMENT_REQUIRED")
  return self~apply(shipment,authority)
::method acceptInbound
  use arg shipment,authority,receipt
  if shipment~direction<>"INBOUND" then return .FederationBankExternalCashServiceResult~failure("INBOUND_SHIPMENT_REQUIRED")
  return self~apply(shipment,authority,receipt)
::requires "FederationBankExternalCashService.cls"
::requires "FederationBankBranchCashService.cls"

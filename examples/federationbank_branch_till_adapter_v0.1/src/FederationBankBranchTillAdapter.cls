/* FederationBank Branch Cash <-> Teller Till Adapter v0.1
 * Exact-authority physical endpoint bridge. Branch Cash owns transfer authority;
 * Teller Till owns drawer custody and physical acceptance/release.
 */
::class FederationBankBranchTillAdapterBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.branch.till.adapter/0.1"

::class FederationBankBranchTillAdapter public
::method init
  expose till context checkerStaffId checkerAuthorityRef policy
  use arg tillArg,contextArg,checkerStaffIdArg,checkerAuthorityRefArg,policyArg=.nil
  till=tillArg; context=contextArg; checkerStaffId=checkerStaffIdArg~string; checkerAuthorityRef=checkerAuthorityRefArg~string
  if policyArg==.nil then policy=.FederationBankTillPolicy~new; else policy=policyArg
  if till==.nil | context==.nil | checkerStaffId="" | checkerAuthorityRef="" then raise syntax 88.990 array("till adapter identity required")
::method validate private
  expose till context checkerStaffId
  use arg transfer,authority
  if transfer==.nil then return .FBBranchCashResult~failure("TRANSFER_REQUIRED")
  if authority==.nil | \authority~isA(.FederationBankBranchCashAuthorityEnvelope) then return .FBBranchCashResult~failure("BRANCH_CASH_AUTHORITY_REQUIRED")
  if \authority~matchesTransfer(transfer) then return .FBBranchCashResult~failure("BRANCH_CASH_AUTHORITY_MISMATCH")
  if transfer~branchId<>till~branchId | context~branchId<>till~branchId then return .FBBranchCashResult~failure("BRANCH_MISMATCH")
  if transfer~bundle~currency<>till~currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  if checkerStaffId=context~staffId | checkerStaffId=transfer~requestedByStaffId then return .FBBranchCashResult~failure("SEPARATION_OF_DUTIES")
  return .FBBranchCashResult~success(authority)
::method instruction private
  use arg transfer,authority
  return .FederationBankTillInternalCashInstruction~new(transfer~transferId,transfer~branchId,transfer~sourceKind,transfer~sourceId,transfer~destinationKind,transfer~destinationId,transfer~bundle~totalMinor,transfer~bundle~currency,authority~semanticIdentity,transfer~requestedByStaffId)
::method bundle private
  use arg transfer
  return .FederationBankCashBundle~new(transfer~bundle~currency,transfer~bundle~denominations)
::method approval private
  expose checkerStaffId checkerAuthorityRef
  use arg instruction
  return .FederationBankTillInternalCashApproval~new("TILLAPR:"||instruction~transferId,instruction~semanticIdentity,checkerStaffId,checkerAuthorityRef)
::method release
  expose till context policy
  use arg transfer,authority
  v=self~validate(transfer,authority); if \v~ok then return v
  if transfer~sourceKind<>"TILL" | transfer~sourceId<>till~tillId then return .FBBranchCashResult~failure("SOURCE_ENDPOINT_MISMATCH")
  i=self~instruction(transfer,authority); b=self~bundle(transfer); a=self~approval(i)
  r=till~applyInternalCash(i,b,context,a,policy)
  if \r~ok then return .FBBranchCashResult~failure(r~code,r~detail)
  return .FBBranchCashResult~success(transfer)
::method accept
  expose till context policy
  use arg transfer,authority
  v=self~validate(transfer,authority); if \v~ok then return v
  if transfer~destinationKind<>"TILL" | transfer~destinationId<>till~tillId then return .FBBranchCashResult~failure("DESTINATION_ENDPOINT_MISMATCH")
  i=self~instruction(transfer,authority); b=self~bundle(transfer); a=self~approval(i)
  r=till~applyInternalCash(i,b,context,a,policy)
  if \r~ok then return .FBBranchCashResult~failure(r~code,r~detail)
  return .FBBranchCashResult~success(transfer)
::method snapshot
  expose till
  return .FederationBankBranchCashEndpointSnapshot~new("TILL",till~tillId,till~branchId,till~currency,till~expectedMinor,till~countedMinor,till~discrepancyMinor)

::requires "FederationBankBranchCash.cls"
::requires "FederationBankTellerTill.cls"

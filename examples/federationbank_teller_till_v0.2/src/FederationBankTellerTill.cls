/* FederationBank Teller Till v0.2 - physical cash custody domain. */
::class FederationBankTellerTillBuild public
::constant VERSION "0.2"
::constant API_VERSION "federationbank.teller.till/0.2"

::class FBTillUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyDir class
  use arg d
  x=.directory~new
  if d==.nil then return x
  do k over d; x[k]=d[k]; end
  return x
::method now class
  return .DateTime~new

::class FBTillResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBTillUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankCashBundle public
::attribute currency get
::attribute denominations get
::attribute totalMinor get
::method init
  expose currency denominations totalMinor
  use arg currencyArg,denominationsArg
  currency=.FBTillUtil~token(currencyArg); denominations=.FBTillUtil~copyDir(denominationsArg); totalMinor=0
  if currency="" then raise syntax 88.901 array("currency required")
  do denom over denominations
    d=denom+0; n=denominations[denom]+0
    if d<=0 | n<0 then raise syntax 88.901 array("invalid denomination")
    totalMinor+=d*n
  end
::method count
  expose denominations
  use arg denomination
  if denominations~hasIndex(denomination~string) then return denominations[denomination~string]+0
  return 0
::method copy
  expose currency denominations
  return self~new(currency,denominations)

::class FederationBankTillCustodyContext public
::attribute tillId get
::attribute branchId get
::attribute staffId get
::attribute sessionId get
::attribute workstationId get
::attribute custodyRef get
::attribute openedAt get
::method init
  expose tillId branchId staffId sessionId workstationId custodyRef openedAt
  use arg tillIdArg,branchIdArg,staffIdArg,sessionIdArg,workstationIdArg,custodyRefArg,openedAtArg=.nil
  tillId=tillIdArg~string; branchId=branchIdArg~string; staffId=staffIdArg~string; sessionId=sessionIdArg~string; workstationId=workstationIdArg~string; custodyRef=custodyRefArg~string
  if openedAtArg==.nil then openedAt=.DateTime~new; else openedAt=openedAtArg
  if tillId="" | branchId="" | staffId="" | sessionId="" | custodyRef="" then raise syntax 88.902 array("custody identity required")

::class FederationBankTillPolicyDecision public
::attribute allow get
::attribute code get
::attribute checkerRequired get
::attribute maxMinor get
::method init
  expose allow code checkerRequired maxMinor
  use arg allowArg,codeArg,checkerRequiredArg=.false,maxMinorArg=0
  allow=allowArg; code=.FBTillUtil~token(codeArg); checkerRequired=checkerRequiredArg; maxMinor=maxMinorArg+0

::class FederationBankTillPolicy public
::method decide
  use arg operation,amountMinor,context,till
  op=.FBTillUtil~token(operation)
  amount=amountMinor+0
  if context==.nil then return .FederationBankTillPolicyDecision~new(.false,"CUSTODY_REQUIRED")
  if till==.nil then return .FederationBankTillPolicyDecision~new(.false,"TILL_REQUIRED")
  if context~tillId<>till~tillId then return .FederationBankTillPolicyDecision~new(.false,"CUSTODY_TILL_MISMATCH")
  select
    when op="OPEN" then return .FederationBankTillPolicyDecision~new(.true,"ALLOW_OPEN",.true,0)
    when op="CASH_IN" then do
      if amount>1000000 then return .FederationBankTillPolicyDecision~new(.true,"ALLOW_CASH_IN_CHECKER",.true,1000000)
      return .FederationBankTillPolicyDecision~new(.true,"ALLOW_CASH_IN",.false,1000000)
    end
    when op="CASH_OUT" then do
      if amount>500000 then return .FederationBankTillPolicyDecision~new(.true,"ALLOW_CASH_OUT_CHECKER",.true,500000)
      return .FederationBankTillPolicyDecision~new(.true,"ALLOW_CASH_OUT",.false,500000)
    end
    when op="TRANSFER_CASH" then return .FederationBankTillPolicyDecision~new(.true,"ALLOW_TRANSFER",.true,0)
    when op="CLOSE" then return .FederationBankTillPolicyDecision~new(.true,"ALLOW_CLOSE",.true,0)
    otherwise return .FederationBankTillPolicyDecision~new(.false,"OPERATION_NOT_ALLOWED")
  end

::class FederationBankTillApproval public
::attribute approvalId get
::attribute actionId get
::attribute approverStaffId get
::attribute actionIdentity get
::attribute approvedAt get
::method init
  expose approvalId actionId approverStaffId actionIdentity approvedAt
  use arg approvalIdArg,actionIdArg,approverStaffIdArg,actionIdentityArg,approvedAtArg=.nil
  approvalId=approvalIdArg~string; actionId=actionIdArg~string; approverStaffId=approverStaffIdArg~string; actionIdentity=actionIdentityArg~string
  if approvedAtArg==.nil then approvedAt=.DateTime~new; else approvedAt=approvedAtArg

::class FederationBankTillAction public
::attribute actionId get
::attribute operation get
::attribute amountMinor get
::attribute currency get
::attribute staffId get
::attribute customerId get
::attribute accountId get
::attribute bankingCommandId get
::attribute createdAt get
::method init
  expose actionId operation amountMinor currency staffId customerId accountId bankingCommandId createdAt
  use arg actionIdArg,operationArg,amountMinorArg,currencyArg,staffIdArg,customerIdArg="",accountIdArg="",bankingCommandIdArg="",createdAtArg=.nil
  actionId=actionIdArg~string; operation=.FBTillUtil~token(operationArg); amountMinor=amountMinorArg+0; currency=.FBTillUtil~token(currencyArg); staffId=staffIdArg~string; customerId=customerIdArg~string; accountId=accountIdArg~string; bankingCommandId=bankingCommandIdArg~string
  if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg
  if actionId="" | operation="" | currency="" | staffId="" then raise syntax 88.903 array("action identity required")
::method semanticIdentity
  expose actionId operation amountMinor currency staffId customerId accountId bankingCommandId
  return actionId||"|"||operation||"|"||amountMinor||"|"||currency||"|"||staffId||"|"||customerId||"|"||accountId||"|"||bankingCommandId


::class FederationBankTillInternalCashInstruction public
::attribute transferId get
::attribute branchId get
::attribute sourceKind get
::attribute sourceId get
::attribute destinationKind get
::attribute destinationId get
::attribute amountMinor get
::attribute currency get
::attribute branchCashAuthorityRef get
::attribute requestedByStaffId get
::attribute createdAt get
::method init
  expose transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency branchCashAuthorityRef requestedByStaffId createdAt
  use arg transferIdArg,branchIdArg,sourceKindArg,sourceIdArg,destinationKindArg,destinationIdArg,amountMinorArg,currencyArg,branchCashAuthorityRefArg,requestedByStaffIdArg,createdAtArg=.nil
  transferId=transferIdArg~string; branchId=branchIdArg~string; sourceKind=.FBTillUtil~token(sourceKindArg); sourceId=sourceIdArg~string; destinationKind=.FBTillUtil~token(destinationKindArg); destinationId=destinationIdArg~string; amountMinor=amountMinorArg+0; currency=.FBTillUtil~token(currencyArg); branchCashAuthorityRef=branchCashAuthorityRefArg~string; requestedByStaffId=requestedByStaffIdArg~string
  if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg
  if transferId="" | branchId="" | sourceKind="" | sourceId="" | destinationKind="" | destinationId="" | amountMinor<0 | currency="" | branchCashAuthorityRef="" | requestedByStaffId="" then raise syntax 88.904 array("internal cash instruction identity required")
  if sourceKind<>"VAULT" & sourceKind<>"TILL" then raise syntax 88.904 array("unsupported internal source")
  if destinationKind<>"VAULT" & destinationKind<>"TILL" then raise syntax 88.904 array("unsupported internal destination")
::method semanticIdentity
  expose transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency branchCashAuthorityRef requestedByStaffId
  return "TILLINTERNALCASH/1|"||transferId||"|"||branchId||"|"||sourceKind||":"||sourceId||"|"||destinationKind||":"||destinationId||"|"||amountMinor||"|"||currency||"|"||branchCashAuthorityRef||"|"||requestedByStaffId

::class FederationBankTillInternalCashApproval public
::attribute approvalId get
::attribute instructionIdentity get
::attribute approverStaffId get
::attribute authorityRef get
::method init
  expose approvalId instructionIdentity approverStaffId authorityRef
  use arg approvalIdArg,instructionIdentityArg,approverStaffIdArg,authorityRefArg
  approvalId=approvalIdArg~string; instructionIdentity=instructionIdentityArg~string; approverStaffId=approverStaffIdArg~string; authorityRef=authorityRefArg~string
  if approvalId="" | instructionIdentity="" | approverStaffId="" | authorityRef="" then raise syntax 88.905 array("internal cash approval identity required")

::class FederationBankTellerTill public
::attribute tillId get
::attribute branchId get
::attribute currency get
::attribute status get
::attribute custodianStaffId get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::attribute openedAt get
::attribute closedAt get
::method init
  expose tillId branchId currency status custodianStaffId expectedMinor countedMinor discrepancyMinor openedAt closedAt journal internalTransfers
  use arg tillIdArg,branchIdArg,currencyArg
  tillId=tillIdArg~string; branchId=branchIdArg~string; currency=.FBTillUtil~token(currencyArg); status="CLOSED"; custodianStaffId=""; expectedMinor=0; countedMinor=0; discrepancyMinor=0; openedAt=.nil; closedAt=.nil; journal=.array~new; internalTransfers=.directory~new
::method journal
  expose journal
  out=.array~new; do e over journal; out~append(e); end; return out
::method open
  expose status custodianStaffId expectedMinor countedMinor discrepancyMinor openedAt closedAt journal currency
  use arg context,openingBundle,approval=.nil,policy=.nil
  if policy==.nil then policy=.FederationBankTillPolicy~new
  if status<>"CLOSED" then return .FBTillResult~failure("TILL_NOT_CLOSED")
  d=policy~decide("OPEN",openingBundle~totalMinor,context,self); if \d~allow then return .FBTillResult~failure(d~code)
  if d~checkerRequired & approval==.nil then return .FBTillResult~failure("CHECKER_REQUIRED")
  if context~staffId=approval~approverStaffId then return .FBTillResult~failure("SEPARATION_OF_DUTIES")
  if openingBundle~currency<>currency then return .FBTillResult~failure("CURRENCY_MISMATCH")
  status="OPEN"; custodianStaffId=context~staffId; expectedMinor=openingBundle~totalMinor; countedMinor=expectedMinor; discrepancyMinor=0; openedAt=.DateTime~new; closedAt=.nil; journal~append("OPEN:"||expectedMinor)
  return .FBTillResult~success(self)
::method applyCash
  expose status custodianStaffId expectedMinor journal currency
  use arg action,bundle,context,approval=.nil,policy=.nil
  if policy==.nil then policy=.FederationBankTillPolicy~new
  if status<>"OPEN" then return .FBTillResult~failure("TILL_NOT_OPEN")
  if context~staffId<>custodianStaffId then return .FBTillResult~failure("NOT_CUSTODIAN")
  if action~staffId<>custodianStaffId then return .FBTillResult~failure("ACTION_STAFF_MISMATCH")
  if bundle~currency<>currency | action~currency<>currency then return .FBTillResult~failure("CURRENCY_MISMATCH")
  if action~amountMinor<>bundle~totalMinor then return .FBTillResult~failure("COUNT_AMOUNT_MISMATCH")
  d=policy~decide(action~operation,action~amountMinor,context,self); if \d~allow then return .FBTillResult~failure(d~code)
  if d~checkerRequired then do
    if approval==.nil then return .FBTillResult~failure("CHECKER_REQUIRED")
    if approval~actionIdentity<>action~semanticIdentity then return .FBTillResult~failure("APPROVAL_ACTION_MISMATCH")
    if approval~approverStaffId=action~staffId then return .FBTillResult~failure("SEPARATION_OF_DUTIES")
  end
  select
    when action~operation="CASH_IN" then expectedMinor+=action~amountMinor
    when action~operation="CASH_OUT" then do
      if expectedMinor<action~amountMinor then return .FBTillResult~failure("INSUFFICIENT_PHYSICAL_CASH")
      expectedMinor-=action~amountMinor
    end
    otherwise return .FBTillResult~failure("CASH_OPERATION_REQUIRED")
  end
  journal~append(action~operation||":"||action~actionId||":"||action~amountMinor)
  return .FBTillResult~success(expectedMinor)
::method applyInternalCash
  expose status custodianStaffId expectedMinor journal currency branchId tillId internalTransfers
  use arg instruction,bundle,context,approval=.nil,policy=.nil
  if policy==.nil then policy=.FederationBankTillPolicy~new
  if status<>"OPEN" then return .FBTillResult~failure("TILL_NOT_OPEN")
  if context==.nil | context~staffId<>custodianStaffId | context~tillId<>tillId | context~branchId<>branchId then return .FBTillResult~failure("NOT_CUSTODIAN")
  if instruction==.nil then return .FBTillResult~failure("INTERNAL_INSTRUCTION_REQUIRED")
  if instruction~branchId<>branchId then return .FBTillResult~failure("BRANCH_MISMATCH")
  if instruction~currency<>currency | bundle~currency<>currency then return .FBTillResult~failure("CURRENCY_MISMATCH")
  if instruction~amountMinor<>bundle~totalMinor then return .FBTillResult~failure("COUNT_AMOUNT_MISMATCH")
  if instruction~branchCashAuthorityRef="" then return .FBTillResult~failure("BRANCH_CASH_AUTHORITY_REQUIRED")
  ident=instruction~semanticIdentity
  if internalTransfers~hasIndex(instruction~transferId) then do
    if internalTransfers[instruction~transferId]=ident then return .FBTillResult~success(expectedMinor,"IDEMPOTENT_INTERNAL_TRANSFER")
    return .FBTillResult~failure("INTERNAL_TRANSFER_ID_CONFLICT")
  end
  direction=""
  if instruction~sourceKind="TILL" & instruction~sourceId=tillId then direction="OUT"
  if instruction~destinationKind="TILL" & instruction~destinationId=tillId then do
    if direction<>"" then return .FBTillResult~failure("INTERNAL_TRANSFER_SELF_REFERENCE")
    direction="IN"
  end
  if direction="" then return .FBTillResult~failure("INTERNAL_TRANSFER_TILL_MISMATCH")
  d=policy~decide("TRANSFER_CASH",instruction~amountMinor,context,self); if \d~allow then return .FBTillResult~failure(d~code)
  if approval==.nil then return .FBTillResult~failure("CHECKER_REQUIRED")
  if approval~instructionIdentity<>ident then return .FBTillResult~failure("APPROVAL_ACTION_MISMATCH")
  if approval~approverStaffId=custodianStaffId | approval~approverStaffId=instruction~requestedByStaffId then return .FBTillResult~failure("SEPARATION_OF_DUTIES")
  if direction="OUT" then do
    if expectedMinor<instruction~amountMinor then return .FBTillResult~failure("INSUFFICIENT_PHYSICAL_CASH")
    expectedMinor-=instruction~amountMinor; journal~append("INTERNAL_CASH_OUT:"||instruction~transferId||":"||instruction~amountMinor||":"||instruction~branchCashAuthorityRef)
  end
  else do
    expectedMinor+=instruction~amountMinor; journal~append("INTERNAL_CASH_IN:"||instruction~transferId||":"||instruction~amountMinor||":"||instruction~branchCashAuthorityRef)
  end
  internalTransfers[instruction~transferId]=ident
  return .FBTillResult~success(expectedMinor)
::method internalTransferIdentity
  expose internalTransfers
  use arg transferId
  if internalTransfers~hasIndex(transferId) then return internalTransfers[transferId]
  return ""
::method countPhysical
  expose status countedMinor discrepancyMinor expectedMinor journal currency
  use arg bundle
  if status<>"OPEN" then return .FBTillResult~failure("TILL_NOT_OPEN")
  if bundle~currency<>currency then return .FBTillResult~failure("CURRENCY_MISMATCH")
  countedMinor=bundle~totalMinor; discrepancyMinor=countedMinor-expectedMinor; journal~append("COUNT:"||countedMinor||":"||discrepancyMinor)
  return .FBTillResult~success(discrepancyMinor)
::method close
  expose status custodianStaffId expectedMinor countedMinor discrepancyMinor closedAt journal
  use arg context,closingBundle,approval=.nil,policy=.nil
  if policy==.nil then policy=.FederationBankTillPolicy~new
  if status<>"OPEN" then return .FBTillResult~failure("TILL_NOT_OPEN")
  if context~staffId<>custodianStaffId then return .FBTillResult~failure("NOT_CUSTODIAN")
  d=policy~decide("CLOSE",expectedMinor,context,self); if \d~allow then return .FBTillResult~failure(d~code)
  if approval==.nil then return .FBTillResult~failure("CHECKER_REQUIRED")
  if approval~approverStaffId=context~staffId then return .FBTillResult~failure("SEPARATION_OF_DUTIES")
  c=self~countPhysical(closingBundle); if \c~ok then return c
  if discrepancyMinor<>0 then return .FBTillResult~failure("TILL_DISCREPANCY_REQUIRES_RESOLUTION",discrepancyMinor)
  status="CLOSED"; closedAt=.DateTime~new; journal~append("CLOSE:"||countedMinor)
  return .FBTillResult~success(self)
::method restoreState
  expose status custodianStaffId expectedMinor countedMinor discrepancyMinor internalTransfers
  use arg statusArg,custodianArg,expectedArg,countedArg,discrepancyArg,internalTransfersArg=.nil
  status=statusArg~string; custodianStaffId=custodianArg~string; expectedMinor=expectedArg+0; countedMinor=countedArg+0; discrepancyMinor=discrepancyArg+0
  if internalTransfersArg==.nil then internalTransfers=.directory~new; else internalTransfers=.FBTillUtil~copyDir(internalTransfersArg)
  return self
::method snapshot
  expose tillId branchId currency status custodianStaffId expectedMinor countedMinor discrepancyMinor internalTransfers
  d=.directory~new; d["tillId"]=tillId; d["branchId"]=branchId; d["currency"]=currency; d["status"]=status; d["custodianStaffId"]=custodianStaffId; d["expectedMinor"]=expectedMinor; d["countedMinor"]=countedMinor; d["discrepancyMinor"]=discrepancyMinor; d["internalTransfers"]=.FBTillUtil~copyDir(internalTransfers); return d

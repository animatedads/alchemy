/* FederationBank Branch Cash v0.3
 * Physical branch vault custody, internal cash transfer authority, and
 * branch-level reconciliation semantics. No Core Banking or customer money
 * authority lives here.
 */
::class FederationBankBranchCashBuild public
::constant VERSION "0.3"
::constant API_VERSION "federationbank.branch.cash/0.3"

::class FBBranchCashUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyDir class
  use arg d
  out=.directory~new
  if d==.nil then return out
  do k over d; out[k]=d[k]; end
  return out
::method copyArray class
  use arg a
  out=.array~new
  if a==.nil then return out
  do x over a; out~append(x); end
  return out
::method dateValue class
  use arg v
  if v==.nil then return .nil
  if v~isA(.DateTime) then return v
  text=v~string
  if text="" then return .nil
  if text~right(1)="Z" then text=text~left(text~length-1)
  return .DateTime~fromIsoDate(text)

::class FBBranchCashResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBBranchCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankBranchCashBundle public
::attribute currency get
::attribute denominations get
::attribute totalMinor get
::method init
  expose currency denominations totalMinor
  use arg currencyArg,denominationsArg
  currency=.FBBranchCashUtil~token(currencyArg); denominations=.FBBranchCashUtil~copyDir(denominationsArg); totalMinor=0
  if currency="" then raise syntax 88.980 array("currency required")
  do denom over denominations
    d=denom+0; n=denominations[denom]+0
    if d<=0 | n<0 then raise syntax 88.980 array("invalid denomination")
    totalMinor+=d*n
  end
::method semanticIdentity
  expose currency denominations totalMinor
  keys=.array~new; do k over denominations; keys~append(k~string); end; keys~sort
  s="CASHBUNDLE/1|"||currency||"|"||totalMinor
  do k over keys; s||="|"||k||"="||denominations[k]; end
  return s
::method queuePersistentType
  return "federationbank.branch.cash.bundle/1"
::method queuePersistentState
  expose currency denominations
  s=.table~new; s["currency"]=currency; s["denominations"]=denominations; return s
::method queueRestoreState
  expose currency denominations totalMinor
  use arg s
  currency=.FBBranchCashUtil~token(s["currency"]); denominations=.FBBranchCashUtil~copyDir(s["denominations"]); totalMinor=0
  do denom over denominations; totalMinor+=(denom+0)*(denominations[denom]+0); end
  return self

::class FederationBankBranchCashControl public
::attribute branchId get
::attribute vaultId get
::attribute primaryStaffId get
::attribute checkerStaffId get
::attribute primarySessionId get
::attribute checkerSessionId get
::attribute controlRef get
::attribute effectiveAt get
::method init
  expose branchId vaultId primaryStaffId checkerStaffId primarySessionId checkerSessionId controlRef effectiveAt
  use arg branchIdArg,vaultIdArg,primaryStaffIdArg,checkerStaffIdArg,controlRefArg,primarySessionIdArg="",checkerSessionIdArg="",effectiveAtArg=.nil
  branchId=branchIdArg~string; vaultId=vaultIdArg~string; primaryStaffId=primaryStaffIdArg~string; checkerStaffId=checkerStaffIdArg~string; controlRef=controlRefArg~string; primarySessionId=primarySessionIdArg~string; checkerSessionId=checkerSessionIdArg~string
  if effectiveAtArg==.nil then effectiveAt=.DateTime~new; else effectiveAt=effectiveAtArg
  if branchId="" | vaultId="" | primaryStaffId="" | checkerStaffId="" | controlRef="" then raise syntax 88.981 array("dual control identity required")
  if primaryStaffId=checkerStaffId then raise syntax 88.981 array("separation of duties required")
::method semanticIdentity
  expose branchId vaultId primaryStaffId checkerStaffId controlRef
  return "BRANCHCASHCONTROL/1|"||branchId||"|"||vaultId||"|"||primaryStaffId||"|"||checkerStaffId||"|"||controlRef

::class FederationBankBranchCashApproval public
::attribute approvalId get
::attribute transferIdentity get
::attribute approverStaffId get
::attribute authorityRef get
::attribute approvedAt get
::method init
  expose approvalId transferIdentity approverStaffId authorityRef approvedAt
  use arg approvalIdArg,transferIdentityArg,approverStaffIdArg,authorityRefArg,approvedAtArg=.nil
  approvalId=approvalIdArg~string; transferIdentity=transferIdentityArg~string; approverStaffId=approverStaffIdArg~string; authorityRef=authorityRefArg~string
  if approvedAtArg==.nil then approvedAt=.DateTime~new; else approvedAt=approvedAtArg
  if approvalId="" | transferIdentity="" | approverStaffId="" | authorityRef="" then raise syntax 88.982 array("approval identity required")
::method queuePersistentType
  return "federationbank.branch.cash.approval/1"
::method queuePersistentState
  expose approvalId transferIdentity approverStaffId authorityRef approvedAt
  s=.table~new; s["approvalId"]=approvalId; s["transferIdentity"]=transferIdentity; s["approverStaffId"]=approverStaffId; s["authorityRef"]=authorityRef; s["approvedAt"]=approvedAt~utcIsoDate; return s
::method queueRestoreState
  expose approvalId transferIdentity approverStaffId authorityRef approvedAt
  use arg s
  approvalId=s["approvalId"]~string; transferIdentity=s["transferIdentity"]~string; approverStaffId=s["approverStaffId"]~string; authorityRef=s["authorityRef"]~string; approvedAt=.FBBranchCashUtil~dateValue(s["approvedAt"]); return self

::class FederationBankBranchCashAuthorityEnvelope public
::attribute authorityId get
::attribute transferIdentity get
::attribute transferId get
::attribute branchId get
::attribute sourceKind get
::attribute sourceId get
::attribute destinationKind get
::attribute destinationId get
::attribute amountMinor get
::attribute currency get
::attribute requestedByStaffId get
::attribute staffAuthorityRef get
::attribute checkerApprovalId get
::attribute checkerStaffId get
::attribute policyCode get
::attribute issuedAt get
::method init
  expose authorityId transferIdentity transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency requestedByStaffId staffAuthorityRef checkerApprovalId checkerStaffId policyCode issuedAt
  use arg authorityIdArg,transferIdentityArg,transferIdArg,branchIdArg,sourceKindArg,sourceIdArg,destinationKindArg,destinationIdArg,amountMinorArg,currencyArg,requestedByStaffIdArg,staffAuthorityRefArg,checkerApprovalIdArg,checkerStaffIdArg,policyCodeArg,issuedAtArg=.nil
  authorityId=authorityIdArg~string; transferIdentity=transferIdentityArg~string; transferId=transferIdArg~string; branchId=branchIdArg~string; sourceKind=.FBBranchCashUtil~token(sourceKindArg); sourceId=sourceIdArg~string; destinationKind=.FBBranchCashUtil~token(destinationKindArg); destinationId=destinationIdArg~string; amountMinor=amountMinorArg+0; currency=.FBBranchCashUtil~token(currencyArg); requestedByStaffId=requestedByStaffIdArg~string; staffAuthorityRef=staffAuthorityRefArg~string; checkerApprovalId=checkerApprovalIdArg~string; checkerStaffId=checkerStaffIdArg~string; policyCode=.FBBranchCashUtil~token(policyCodeArg)
  if issuedAtArg==.nil then issuedAt=.DateTime~new; else issuedAt=issuedAtArg
  if authorityId="" | transferIdentity="" | transferId="" | branchId="" | sourceKind="" | sourceId="" | destinationKind="" | destinationId="" | amountMinor<=0 | currency="" | requestedByStaffId="" | staffAuthorityRef="" | checkerApprovalId="" | checkerStaffId="" | policyCode="" then raise syntax 88.987 array("branch cash authority identity required")
::method matchesTransfer
  expose transferIdentity transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency requestedByStaffId staffAuthorityRef
  use arg transfer
  if transfer==.nil then return .false
  if transferIdentity<>transfer~semanticIdentity then return .false
  if transferId<>transfer~transferId | branchId<>transfer~branchId then return .false
  if sourceKind<>transfer~sourceKind | sourceId<>transfer~sourceId | destinationKind<>transfer~destinationKind | destinationId<>transfer~destinationId then return .false
  if amountMinor<>transfer~bundle~totalMinor | currency<>transfer~bundle~currency then return .false
  if requestedByStaffId<>transfer~requestedByStaffId | staffAuthorityRef<>transfer~staffAuthorityRef then return .false
  return .true
::method semanticIdentity
  expose authorityId transferIdentity transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency requestedByStaffId staffAuthorityRef checkerApprovalId checkerStaffId policyCode
  return "BRANCHCASHAUTHORITY/1|"||authorityId||"|"||transferId||"|"||branchId||"|"||sourceKind||":"||sourceId||"|"||destinationKind||":"||destinationId||"|"||amountMinor||"|"||currency||"|"||requestedByStaffId||"|"||staffAuthorityRef||"|"||checkerApprovalId||"|"||checkerStaffId||"|"||policyCode||"|"||transferIdentity
::method queuePersistentType
  return "federationbank.branch.cash.authority/1"
::method queuePersistentState
  expose authorityId transferIdentity transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency requestedByStaffId staffAuthorityRef checkerApprovalId checkerStaffId policyCode issuedAt
  s=.table~new; s["authorityId"]=authorityId; s["transferIdentity"]=transferIdentity; s["transferId"]=transferId; s["branchId"]=branchId; s["sourceKind"]=sourceKind; s["sourceId"]=sourceId; s["destinationKind"]=destinationKind; s["destinationId"]=destinationId; s["amountMinor"]=amountMinor~string; s["currency"]=currency; s["requestedByStaffId"]=requestedByStaffId; s["staffAuthorityRef"]=staffAuthorityRef; s["checkerApprovalId"]=checkerApprovalId; s["checkerStaffId"]=checkerStaffId; s["policyCode"]=policyCode; s["issuedAt"]=issuedAt~utcIsoDate; return s
::method queueRestoreState
  expose authorityId transferIdentity transferId branchId sourceKind sourceId destinationKind destinationId amountMinor currency requestedByStaffId staffAuthorityRef checkerApprovalId checkerStaffId policyCode issuedAt
  use arg s
  authorityId=s["authorityId"]~string; transferIdentity=s["transferIdentity"]~string; transferId=s["transferId"]~string; branchId=s["branchId"]~string; sourceKind=.FBBranchCashUtil~token(s["sourceKind"]); sourceId=s["sourceId"]~string; destinationKind=.FBBranchCashUtil~token(s["destinationKind"]); destinationId=s["destinationId"]~string; amountMinor=s["amountMinor"]+0; currency=.FBBranchCashUtil~token(s["currency"]); requestedByStaffId=s["requestedByStaffId"]~string; staffAuthorityRef=s["staffAuthorityRef"]~string; checkerApprovalId=s["checkerApprovalId"]~string; checkerStaffId=s["checkerStaffId"]~string; policyCode=.FBBranchCashUtil~token(s["policyCode"]); issuedAt=.FBBranchCashUtil~dateValue(s["issuedAt"]); return self

::class FederationBankBranchCashAuthorityIssuer public
::method issue
  use arg transfer,approval,policy
  if transfer==.nil then return .FBBranchCashResult~failure("TRANSFER_REQUIRED")
  if approval==.nil then return .FBBranchCashResult~failure("CHECKER_REQUIRED")
  if approval~transferIdentity<>transfer~semanticIdentity then return .FBBranchCashResult~failure("APPROVAL_TRANSFER_MISMATCH")
  if approval~approverStaffId=transfer~requestedByStaffId then return .FBBranchCashResult~failure("SEPARATION_OF_DUTIES")
  if transfer~staffAuthorityRef="" then return .FBBranchCashResult~failure("STAFF_AUTHORITY_REQUIRED")
  if policy==.nil then return .FBBranchCashResult~failure("POLICY_REQUIRED")
  d=policy~decide("AUTHORISE_TRANSFER",transfer,.nil); if \d~allow then return .FBBranchCashResult~failure(d~code)
  authorityId="BCAUTH:"||transfer~transferId||":"||approval~approvalId
  e=.FederationBankBranchCashAuthorityEnvelope~new(authorityId,transfer~semanticIdentity,transfer~transferId,transfer~branchId,transfer~sourceKind,transfer~sourceId,transfer~destinationKind,transfer~destinationId,transfer~bundle~totalMinor,transfer~bundle~currency,transfer~requestedByStaffId,transfer~staffAuthorityRef,approval~approvalId,approval~approverStaffId,d~code)
  return .FBBranchCashResult~success(e)

::class FederationBankBranchCashTransfer public
::attribute transferId get
::attribute branchId get
::attribute sourceKind get
::attribute sourceId get
::attribute destinationKind get
::attribute destinationId get
::attribute bundle get
::attribute reasonClass get
::attribute requestedByStaffId get
::attribute staffAuthorityRef get
::attribute transitCustodyRef get
::attribute createdAt get
::method init
  expose transferId branchId sourceKind sourceId destinationKind destinationId bundle reasonClass requestedByStaffId staffAuthorityRef transitCustodyRef createdAt
  use arg transferIdArg,branchIdArg,sourceKindArg,sourceIdArg,destinationKindArg,destinationIdArg,bundleArg,reasonClassArg,requestedByStaffIdArg,staffAuthorityRefArg,transitCustodyRefArg="",createdAtArg=.nil
  transferId=transferIdArg~string; branchId=branchIdArg~string; sourceKind=.FBBranchCashUtil~token(sourceKindArg); sourceId=sourceIdArg~string; destinationKind=.FBBranchCashUtil~token(destinationKindArg); destinationId=destinationIdArg~string; bundle=bundleArg; reasonClass=.FBBranchCashUtil~token(reasonClassArg); requestedByStaffId=requestedByStaffIdArg~string; staffAuthorityRef=staffAuthorityRefArg~string
  if transitCustodyRefArg="" then transitCustodyRef="TRANSIT:"||transferId; else transitCustodyRef=transitCustodyRefArg~string
  if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg
  if transferId="" | branchId="" | sourceKind="" | sourceId="" | destinationKind="" | destinationId="" | bundle==.nil | reasonClass="" | requestedByStaffId="" | staffAuthorityRef="" then raise syntax 88.983 array("transfer identity required")
  if sourceKind<>"VAULT" & sourceKind<>"TILL" then raise syntax 88.983 array("unsupported source kind")
  if destinationKind<>"VAULT" & destinationKind<>"TILL" then raise syntax 88.983 array("unsupported destination kind")
  if sourceKind=destinationKind & sourceId=destinationId then raise syntax 88.983 array("source and destination must differ")
::method semanticIdentity
  expose transferId branchId sourceKind sourceId destinationKind destinationId bundle reasonClass requestedByStaffId staffAuthorityRef transitCustodyRef
  return "BRANCHCASHTRANSFER/1|"||transferId||"|"||branchId||"|"||sourceKind||":"||sourceId||"|"||destinationKind||":"||destinationId||"|"||bundle~semanticIdentity||"|"||reasonClass||"|"||requestedByStaffId||"|"||staffAuthorityRef||"|"||transitCustodyRef
::method queuePersistentType
  return "federationbank.branch.cash.transfer/1"
::method queuePersistentState
  expose transferId branchId sourceKind sourceId destinationKind destinationId bundle reasonClass requestedByStaffId staffAuthorityRef transitCustodyRef createdAt
  s=.table~new; s["transferId"]=transferId; s["branchId"]=branchId; s["sourceKind"]=sourceKind; s["sourceId"]=sourceId; s["destinationKind"]=destinationKind; s["destinationId"]=destinationId; s["bundle"]=bundle; s["reasonClass"]=reasonClass; s["requestedByStaffId"]=requestedByStaffId; s["staffAuthorityRef"]=staffAuthorityRef; s["transitCustodyRef"]=transitCustodyRef; s["createdAt"]=createdAt~utcIsoDate; return s
::method queueRestoreState
  expose transferId branchId sourceKind sourceId destinationKind destinationId bundle reasonClass requestedByStaffId staffAuthorityRef transitCustodyRef createdAt
  use arg s
  transferId=s["transferId"]~string; branchId=s["branchId"]~string; sourceKind=.FBBranchCashUtil~token(s["sourceKind"]); sourceId=s["sourceId"]~string; destinationKind=.FBBranchCashUtil~token(s["destinationKind"]); destinationId=s["destinationId"]~string; bundle=s["bundle"]; reasonClass=.FBBranchCashUtil~token(s["reasonClass"]); requestedByStaffId=s["requestedByStaffId"]~string; staffAuthorityRef=s["staffAuthorityRef"]~string; transitCustodyRef=s["transitCustodyRef"]~string; createdAt=.FBBranchCashUtil~dateValue(s["createdAt"]); return self


::class FederationBankBranchCashExternalInstruction public
::attribute shipmentId get
::attribute branchId get
::attribute direction get
::attribute vaultId get
::attribute amountMinor get
::attribute currency get
::attribute externalAuthorityRef get
::attribute manifestRef get
::attribute sealId get
::attribute requestedByStaffId get
::method init
  expose shipmentId branchId direction vaultId amountMinor currency externalAuthorityRef manifestRef sealId requestedByStaffId
  use arg shipmentIdArg,branchIdArg,directionArg,vaultIdArg,amountMinorArg,currencyArg,externalAuthorityRefArg,manifestRefArg,sealIdArg,requestedByStaffIdArg
  shipmentId=shipmentIdArg~string; branchId=branchIdArg~string; direction=.FBBranchCashUtil~token(directionArg); vaultId=vaultIdArg~string; amountMinor=amountMinorArg+0; currency=.FBBranchCashUtil~token(currencyArg); externalAuthorityRef=externalAuthorityRefArg~string; manifestRef=manifestRefArg~string; sealId=sealIdArg~string; requestedByStaffId=requestedByStaffIdArg~string
  if shipmentId="" | branchId="" | vaultId="" | amountMinor<0 | currency="" | externalAuthorityRef="" | manifestRef="" | sealId="" | requestedByStaffId="" then raise syntax 88.989 array("branch external cash instruction identity required")
  if direction<>"INBOUND" & direction<>"OUTBOUND" then raise syntax 88.989 array("branch external cash direction invalid")
::method semanticIdentity
  expose shipmentId branchId direction vaultId amountMinor currency externalAuthorityRef manifestRef sealId requestedByStaffId
  return "BRANCHEXTERNALCASH/1|"||shipmentId||"|"||branchId||"|"||direction||"|"||vaultId||"|"||amountMinor||"|"||currency||"|"||externalAuthorityRef||"|"||manifestRef||"|"||sealId||"|"||requestedByStaffId
::method queuePersistentType
  return "federationbank.branch.cash.external.instruction/1"
::method queuePersistentState
  expose shipmentId branchId direction vaultId amountMinor currency externalAuthorityRef manifestRef sealId requestedByStaffId
  x=.table~new; x["shipmentId"]=shipmentId; x["branchId"]=branchId; x["direction"]=direction; x["vaultId"]=vaultId; x["amountMinor"]=amountMinor~string; x["currency"]=currency; x["externalAuthorityRef"]=externalAuthorityRef; x["manifestRef"]=manifestRef; x["sealId"]=sealId; x["requestedByStaffId"]=requestedByStaffId; return x
::method queueRestoreState
  expose shipmentId branchId direction vaultId amountMinor currency externalAuthorityRef manifestRef sealId requestedByStaffId
  use arg x
  shipmentId=x["shipmentId"]~string; branchId=x["branchId"]~string; direction=.FBBranchCashUtil~token(x["direction"]); vaultId=x["vaultId"]~string; amountMinor=x["amountMinor"]+0; currency=.FBBranchCashUtil~token(x["currency"]); externalAuthorityRef=x["externalAuthorityRef"]~string; manifestRef=x["manifestRef"]~string; sealId=x["sealId"]~string; requestedByStaffId=x["requestedByStaffId"]~string; return self

::class FederationBankBranchCashExternalControl public
::attribute controlId get
::attribute instructionIdentity get
::attribute primaryStaffId get
::attribute checkerStaffId get
::attribute externalAuthorityRef get
::method init
  expose controlId instructionIdentity primaryStaffId checkerStaffId externalAuthorityRef
  use arg controlIdArg,instructionIdentityArg,primaryStaffIdArg,checkerStaffIdArg,externalAuthorityRefArg
  controlId=controlIdArg~string; instructionIdentity=instructionIdentityArg~string; primaryStaffId=primaryStaffIdArg~string; checkerStaffId=checkerStaffIdArg~string; externalAuthorityRef=externalAuthorityRefArg~string
  if controlId="" | instructionIdentity="" | primaryStaffId="" | checkerStaffId="" | externalAuthorityRef="" then raise syntax 88.989 array("branch external cash control identity required")
  if primaryStaffId=checkerStaffId then raise syntax 88.989 array("branch external cash control requires separation of duties")
::method semanticIdentity
  expose controlId instructionIdentity primaryStaffId checkerStaffId externalAuthorityRef
  return "BRANCHEXTERNALCONTROL/1|"||controlId||"|"||instructionIdentity||"|"||primaryStaffId||"|"||checkerStaffId||"|"||externalAuthorityRef

::class FederationBankBranchCashPolicyDecision public
::attribute allow get
::attribute code get
::attribute checkerRequired get
::method init
  expose allow code checkerRequired
  use arg allowArg,codeArg,checkerRequiredArg=.false
  allow=allowArg; code=.FBBranchCashUtil~token(codeArg); checkerRequired=checkerRequiredArg

::class FederationBankBranchCashPolicyPort public
::method decide abstract

::class FederationBankBranchCashFixturePolicy subclass FederationBankBranchCashPolicyPort public
::method decide
  use arg operation,subject=.nil,control=.nil
  op=.FBBranchCashUtil~token(operation)
  if op="OPEN" | op="CLOSE" | op="HANDOVER" then do
    if control==.nil then return .FederationBankBranchCashPolicyDecision~new(.false,"DUAL_CONTROL_REQUIRED",.true)
    if control~primaryStaffId=control~checkerStaffId then return .FederationBankBranchCashPolicyDecision~new(.false,"SEPARATION_OF_DUTIES",.true)
    return .FederationBankBranchCashPolicyDecision~new(.true,"ALLOW_"||op,.true)
  end
  if op="AUTHORISE_TRANSFER" | op="RESERVE_OUT" | op="ACCEPT_IN" | op="RELEASE_RESERVATION" then do
    if subject==.nil then return .FederationBankBranchCashPolicyDecision~new(.false,"TRANSFER_REQUIRED",.true)
    if subject~staffAuthorityRef="" then return .FederationBankBranchCashPolicyDecision~new(.false,"STAFF_AUTHORITY_REQUIRED",.true)
    return .FederationBankBranchCashPolicyDecision~new(.true,"ALLOW_"||op,.true)
  end
  if op="EXTERNAL_CASH" then do
    if subject==.nil then return .FederationBankBranchCashPolicyDecision~new(.false,"EXTERNAL_INSTRUCTION_REQUIRED",.true)
    if subject~externalAuthorityRef="" then return .FederationBankBranchCashPolicyDecision~new(.false,"EXTERNAL_CASH_AUTHORITY_REQUIRED",.true)
    if control==.nil then return .FederationBankBranchCashPolicyDecision~new(.false,"VAULT_DUAL_CONTROL_REQUIRED",.true)
    if control~primaryStaffId=control~checkerStaffId then return .FederationBankBranchCashPolicyDecision~new(.false,"SEPARATION_OF_DUTIES",.true)
    return .FederationBankBranchCashPolicyDecision~new(.true,"ALLOW_EXTERNAL_CASH",.true)
  end
  return .FederationBankBranchCashPolicyDecision~new(.false,"OPERATION_NOT_ALLOWED")

::class FederationBankBranchCashEndpointSnapshot public
::attribute endpointKind get
::attribute endpointId get
::attribute branchId get
::attribute currency get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::method init
  expose endpointKind endpointId branchId currency expectedMinor countedMinor discrepancyMinor
  use arg endpointKindArg,endpointIdArg,branchIdArg,currencyArg,expectedArg,countedArg,discrepancyArg
  endpointKind=.FBBranchCashUtil~token(endpointKindArg); endpointId=endpointIdArg~string; branchId=branchIdArg~string; currency=.FBBranchCashUtil~token(currencyArg); expectedMinor=expectedArg+0; countedMinor=countedArg+0; discrepancyMinor=discrepancyArg+0

::class FederationBankBranchCashPosition public
::attribute branchId get
::attribute currency get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::attribute inTransitMinor get
::method init
  expose branchId currency expectedMinor countedMinor discrepancyMinor inTransitMinor
  use arg branchIdArg,currencyArg,snapshotsArg,inTransitMinorArg=0
  branchId=branchIdArg~string; currency=.FBBranchCashUtil~token(currencyArg); expectedMinor=0; countedMinor=0; discrepancyMinor=0; inTransitMinor=inTransitMinorArg+0
  do s over snapshotsArg
    if s~branchId=branchId & s~currency=currency then do; expectedMinor+=s~expectedMinor; countedMinor+=s~countedMinor; discrepancyMinor+=s~discrepancyMinor; end
  end
::method totalCustodyMinor
  expose expectedMinor inTransitMinor
  return expectedMinor+inTransitMinor

::class FederationBankBranchCashVault public
::attribute vaultId get
::attribute branchId get
::attribute currency get
::attribute status get
::attribute primaryStaffId get
::attribute checkerStaffId get
::attribute controlRef get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::method init
  expose vaultId branchId currency status primaryStaffId checkerStaffId controlRef expectedMinor countedMinor discrepancyMinor reservations externalMovements journal
  use arg vaultIdArg,branchIdArg,currencyArg
  vaultId=vaultIdArg~string; branchId=branchIdArg~string; currency=.FBBranchCashUtil~token(currencyArg); status="CLOSED"; primaryStaffId=""; checkerStaffId=""; controlRef=""; expectedMinor=0; countedMinor=0; discrepancyMinor=0; reservations=.directory~new; externalMovements=.directory~new; journal=.array~new
  if vaultId="" | branchId="" | currency="" then raise syntax 88.984 array("vault identity required")
::method reservationMinor
  expose reservations
  total=0; do k over reservations; total+=reservations[k]+0; end; return total
::method availableMinor
  expose expectedMinor
  return expectedMinor-self~reservationMinor
::method open
  expose status primaryStaffId checkerStaffId controlRef expectedMinor countedMinor discrepancyMinor journal currency branchId vaultId
  use arg control,bundle,policy
  if status<>"CLOSED" then return .FBBranchCashResult~failure("VAULT_NOT_CLOSED")
  if control==.nil | control~branchId<>branchId | control~vaultId<>vaultId then return .FBBranchCashResult~failure("CONTROL_SCOPE_MISMATCH")
  if bundle~currency<>currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  d=policy~decide("OPEN",self,control); if \d~allow then return .FBBranchCashResult~failure(d~code)
  status="OPEN"; primaryStaffId=control~primaryStaffId; checkerStaffId=control~checkerStaffId; controlRef=control~controlRef; expectedMinor=bundle~totalMinor; countedMinor=expectedMinor; discrepancyMinor=0; journal~append("OPEN:"||expectedMinor||":"||controlRef)
  return .FBBranchCashResult~success(self)
::method validateApproval private
  use arg transfer,approval
  if approval==.nil then return .FBBranchCashResult~failure("CHECKER_REQUIRED")
  if approval~transferIdentity<>transfer~semanticIdentity then return .FBBranchCashResult~failure("APPROVAL_TRANSFER_MISMATCH")
  if approval~approverStaffId=transfer~requestedByStaffId then return .FBBranchCashResult~failure("SEPARATION_OF_DUTIES")
  return .FBBranchCashResult~success(approval)
::method reserveOut
  expose status vaultId branchId currency reservations journal
  use arg transfer,approval,policy
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if transfer~sourceKind<>"VAULT" | transfer~sourceId<>vaultId | transfer~branchId<>branchId then return .FBBranchCashResult~failure("TRANSFER_SOURCE_MISMATCH")
  if transfer~bundle~currency<>currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  d=policy~decide("RESERVE_OUT",transfer,.nil); if \d~allow then return .FBBranchCashResult~failure(d~code)
  a=self~validateApproval(transfer,approval); if \a~ok then return a
  if reservations~hasIndex(transfer~transferId) then do
    if reservations[transfer~transferId]=transfer~bundle~totalMinor then return .FBBranchCashResult~success(transfer,"IDEMPOTENT_RESERVATION")
    return .FBBranchCashResult~failure("TRANSFER_ID_CONFLICT")
  end
  if self~availableMinor<transfer~bundle~totalMinor then return .FBBranchCashResult~failure("INSUFFICIENT_VAULT_CASH")
  reservations[transfer~transferId]=transfer~bundle~totalMinor; journal~append("RESERVE_OUT:"||transfer~transferId||":"||transfer~bundle~totalMinor)
  return .FBBranchCashResult~success(transfer)
::method commitOut
  expose reservations expectedMinor journal
  use arg transfer
  if \reservations~hasIndex(transfer~transferId) then return .FBBranchCashResult~failure("TRANSFER_NOT_RESERVED")
  amount=reservations[transfer~transferId]+0
  if amount<>transfer~bundle~totalMinor then return .FBBranchCashResult~failure("RESERVATION_AMOUNT_MISMATCH")
  expectedMinor-=amount; reservations~remove(transfer~transferId); journal~append("COMMIT_OUT:"||transfer~transferId||":"||amount)
  return .FBBranchCashResult~success(expectedMinor)
::method releaseReservation
  expose reservations journal
  use arg transfer,policy
  d=policy~decide("RELEASE_RESERVATION",transfer,.nil); if \d~allow then return .FBBranchCashResult~failure(d~code)
  if reservations~hasIndex(transfer~transferId) then do; reservations~remove(transfer~transferId); journal~append("RELEASE_RESERVATION:"||transfer~transferId); end
  return .FBBranchCashResult~success(self)
::method acceptIn
  expose status vaultId branchId currency expectedMinor journal
  use arg transfer,approval,policy
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if transfer~destinationKind<>"VAULT" | transfer~destinationId<>vaultId | transfer~branchId<>branchId then return .FBBranchCashResult~failure("TRANSFER_DESTINATION_MISMATCH")
  if transfer~bundle~currency<>currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  d=policy~decide("ACCEPT_IN",transfer,.nil); if \d~allow then return .FBBranchCashResult~failure(d~code)
  a=self~validateApproval(transfer,approval); if \a~ok then return a
  expectedMinor+=transfer~bundle~totalMinor; journal~append("ACCEPT_IN:"||transfer~transferId||":"||transfer~bundle~totalMinor)
  return .FBBranchCashResult~success(expectedMinor)
::method applyExternalCash
  expose status vaultId branchId currency primaryStaffId checkerStaffId expectedMinor externalMovements journal
  use arg instruction,bundle,control,policy=.nil
  if policy==.nil then policy=.FederationBankBranchCashFixturePolicy~new
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if instruction==.nil | control==.nil then return .FBBranchCashResult~failure("EXTERNAL_CASH_INSTRUCTION_CONTROL_REQUIRED")
  if instruction~branchId<>branchId | instruction~vaultId<>vaultId then return .FBBranchCashResult~failure("EXTERNAL_CASH_VAULT_SCOPE_MISMATCH")
  if instruction~currency<>currency | bundle~currency<>currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  if instruction~amountMinor<>bundle~totalMinor then return .FBBranchCashResult~failure("COUNT_AMOUNT_MISMATCH")
  if control~instructionIdentity<>instruction~semanticIdentity then return .FBBranchCashResult~failure("EXTERNAL_CONTROL_ACTION_MISMATCH")
  if control~externalAuthorityRef<>instruction~externalAuthorityRef then return .FBBranchCashResult~failure("EXTERNAL_AUTHORITY_MISMATCH")
  if control~primaryStaffId<>primaryStaffId | control~checkerStaffId<>checkerStaffId then return .FBBranchCashResult~failure("VAULT_CUSTODY_CONTROL_MISMATCH")
  d=policy~decide("EXTERNAL_CASH",instruction,control); if \d~allow then return .FBBranchCashResult~failure(d~code)
  ident=instruction~semanticIdentity
  if externalMovements~hasIndex(instruction~shipmentId) then do
    if externalMovements[instruction~shipmentId]=ident then return .FBBranchCashResult~success(expectedMinor,"IDEMPOTENT_EXTERNAL_CASH")
    return .FBBranchCashResult~failure("EXTERNAL_SHIPMENT_ID_CONFLICT")
  end
  if instruction~direction="OUTBOUND" then do
    if expectedMinor<instruction~amountMinor then return .FBBranchCashResult~failure("INSUFFICIENT_VAULT_CASH")
    expectedMinor-=instruction~amountMinor
  end
  else expectedMinor+=instruction~amountMinor
  externalMovements[instruction~shipmentId]=ident; journal~append("EXTERNAL_CASH_"||instruction~direction||":"||instruction~shipmentId||":"||instruction~amountMinor||":"||instruction~externalAuthorityRef)
  return .FBBranchCashResult~success(expectedMinor)
::method countPhysical
  expose status currency countedMinor discrepancyMinor expectedMinor journal
  use arg bundle
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if bundle~currency<>currency then return .FBBranchCashResult~failure("CURRENCY_MISMATCH")
  countedMinor=bundle~totalMinor; discrepancyMinor=countedMinor-expectedMinor; journal~append("COUNT:"||countedMinor||":"||discrepancyMinor)
  return .FBBranchCashResult~success(discrepancyMinor)
::method handover
  expose status primaryStaffId checkerStaffId controlRef discrepancyMinor branchId vaultId journal
  use arg newControl,countBundle,policy
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if self~reservationMinor<>0 then return .FBBranchCashResult~failure("OUTSTANDING_RESERVATIONS")
  c=self~countPhysical(countBundle); if \c~ok then return c
  if discrepancyMinor<>0 then return .FBBranchCashResult~failure("VAULT_DISCREPANCY_REQUIRES_RESOLUTION",discrepancyMinor)
  if newControl~branchId<>branchId | newControl~vaultId<>vaultId then return .FBBranchCashResult~failure("CONTROL_SCOPE_MISMATCH")
  d=policy~decide("HANDOVER",self,newControl); if \d~allow then return .FBBranchCashResult~failure(d~code)
  primaryStaffId=newControl~primaryStaffId; checkerStaffId=newControl~checkerStaffId; controlRef=newControl~controlRef; journal~append("HANDOVER:"||controlRef)
  return .FBBranchCashResult~success(self)
::method close
  expose status discrepancyMinor branchId vaultId journal
  use arg control,closingBundle,policy
  if status<>"OPEN" then return .FBBranchCashResult~failure("VAULT_NOT_OPEN")
  if self~reservationMinor<>0 then return .FBBranchCashResult~failure("OUTSTANDING_RESERVATIONS")
  if control~branchId<>branchId | control~vaultId<>vaultId then return .FBBranchCashResult~failure("CONTROL_SCOPE_MISMATCH")
  d=policy~decide("CLOSE",self,control); if \d~allow then return .FBBranchCashResult~failure(d~code)
  c=self~countPhysical(closingBundle); if \c~ok then return c
  if discrepancyMinor<>0 then return .FBBranchCashResult~failure("VAULT_DISCREPANCY_REQUIRES_RESOLUTION",discrepancyMinor)
  status="CLOSED"; journal~append("CLOSE:"||closingBundle~totalMinor||":"||control~controlRef); return .FBBranchCashResult~success(self)
::method snapshot
  expose vaultId branchId currency status primaryStaffId checkerStaffId controlRef expectedMinor countedMinor discrepancyMinor reservations externalMovements
  d=.directory~new; d["vaultId"]=vaultId; d["branchId"]=branchId; d["currency"]=currency; d["status"]=status; d["primaryStaffId"]=primaryStaffId; d["checkerStaffId"]=checkerStaffId; d["controlRef"]=controlRef; d["expectedMinor"]=expectedMinor; d["countedMinor"]=countedMinor; d["discrepancyMinor"]=discrepancyMinor; d["reservations"]=.FBBranchCashUtil~copyDir(reservations); d["externalMovements"]=.FBBranchCashUtil~copyDir(externalMovements); return d
::method restoreState
  expose status primaryStaffId checkerStaffId controlRef expectedMinor countedMinor discrepancyMinor reservations externalMovements
  use arg s
  status=s["status"]~string; primaryStaffId=s["primaryStaffId"]~string; checkerStaffId=s["checkerStaffId"]~string; controlRef=s["controlRef"]~string; expectedMinor=s["expectedMinor"]+0; countedMinor=s["countedMinor"]+0; discrepancyMinor=s["discrepancyMinor"]+0; reservations=.FBBranchCashUtil~copyDir(s["reservations"]); externalMovements=.FBBranchCashUtil~copyDir(s["externalMovements"]); return self
::method endpointSnapshot
  expose vaultId branchId currency expectedMinor countedMinor discrepancyMinor
  return .FederationBankBranchCashEndpointSnapshot~new("VAULT",vaultId,branchId,currency,expectedMinor,countedMinor,discrepancyMinor)
::method queuePersistentType
  return "federationbank.branch.cash.vault/1"
::method queuePersistentState
  expose vaultId branchId currency
  s=self~snapshot; s["vaultId"]=vaultId; s["branchId"]=branchId; s["currency"]=currency; return s
::method queueRestoreState
  expose vaultId branchId currency
  use arg s
  vaultId=s["vaultId"]~string; branchId=s["branchId"]~string; currency=.FBBranchCashUtil~token(s["currency"]); self~restoreState(s); return self

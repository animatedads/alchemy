/* FederationBank External Cash v0.1
 * Physical cash logistics across the branch perimeter.
 * This module owns shipment/custody semantics; it does not own customer money,
 * account balances, or branch-vault truth.
 */
::class FederationBankExternalCashBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.external.cash/0.1"

::class FBExternalCashUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyDir class
  use arg d
  out=.directory~new; if d==.nil then return out
  do k over d; out[k]=d[k]; end
  return out
::method dateValue class
  use arg v
  if v==.nil then return .nil
  if v~isA(.DateTime) then return v
  t=v~string; if t="" then return .nil
  if t~right(1)="Z" then t=t~left(t~length-1)
  return .DateTime~fromIsoDate(t)

::class FederationBankExternalCashResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBExternalCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankExternalCashBundle public
::attribute currency get
::attribute denominations get
::attribute totalMinor get
::method init
  expose currency denominations totalMinor
  use arg currencyArg,denominationsArg
  currency=.FBExternalCashUtil~token(currencyArg); denominations=.FBExternalCashUtil~copyDir(denominationsArg); totalMinor=0
  if currency="" then raise syntax 88.990 array("external cash currency required")
  do denom over denominations
    d=denom+0; n=denominations[denom]+0
    if d<=0 | n<0 then raise syntax 88.990 array("invalid external cash denomination")
    totalMinor+=d*n
  end
::method semanticIdentity
  expose currency denominations totalMinor
  keys=.array~new; do k over denominations; keys~append(k~string); end; keys~sort
  t="FBEXTERNALCASHBUNDLE/1|"||currency||"|"||totalMinor
  do k over keys; t||="|"||k||"="||denominations[k]; end
  return t
::method queuePersistentType
  return "federationbank.external.cash.bundle/1"
::method queuePersistentState
  expose currency denominations
  s=.table~new; s["currency"]=currency; s["denominations"]=denominations; return s
::method queueRestoreState
  expose currency denominations totalMinor
  use arg s
  currency=.FBExternalCashUtil~token(s["currency"]); denominations=s["denominations"]; totalMinor=0; do k over denominations; totalMinor+=(k+0)*(denominations[k]+0); end; return self

::class FederationBankExternalCashShipment public
::attribute shipmentId get
::attribute branchId get
::attribute direction get
::attribute vaultId get
::attribute cashCentreId get
::attribute carrierId get
::attribute manifestRef get
::attribute sealId get
::attribute bundle get
::attribute requestedByStaffId get
::attribute staffAuthorityRef get
::attribute createdAt get
::method init
  expose shipmentId branchId direction vaultId cashCentreId carrierId manifestRef sealId bundle requestedByStaffId staffAuthorityRef createdAt
  use arg shipmentIdArg,branchIdArg,directionArg,vaultIdArg,cashCentreIdArg,carrierIdArg,manifestRefArg,sealIdArg,bundleArg,requestedByStaffIdArg,staffAuthorityRefArg,createdAtArg=.nil
  shipmentId=shipmentIdArg~string; branchId=branchIdArg~string; direction=.FBExternalCashUtil~token(directionArg); vaultId=vaultIdArg~string; cashCentreId=cashCentreIdArg~string; carrierId=carrierIdArg~string; manifestRef=manifestRefArg~string; sealId=sealIdArg~string; bundle=bundleArg; requestedByStaffId=requestedByStaffIdArg~string; staffAuthorityRef=staffAuthorityRefArg~string
  if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg
  if shipmentId="" | branchId="" | vaultId="" | cashCentreId="" | carrierId="" | manifestRef="" | sealId="" | bundle==.nil | requestedByStaffId="" | staffAuthorityRef="" then raise syntax 88.991 array("external cash shipment identity required")
  if direction<>"INBOUND" & direction<>"OUTBOUND" then raise syntax 88.991 array("external cash direction invalid")
::method semanticIdentity
  expose shipmentId branchId direction vaultId cashCentreId carrierId manifestRef sealId bundle requestedByStaffId staffAuthorityRef
  return "FBEXTERNALCASHSHIPMENT/1|"||shipmentId||"|"||branchId||"|"||direction||"|"||vaultId||"|"||cashCentreId||"|"||carrierId||"|"||manifestRef||"|"||sealId||"|"||bundle~semanticIdentity||"|"||requestedByStaffId||"|"||staffAuthorityRef
::method queuePersistentType
  return "federationbank.external.cash.shipment/1"
::method queuePersistentState
  expose shipmentId branchId direction vaultId cashCentreId carrierId manifestRef sealId bundle requestedByStaffId staffAuthorityRef createdAt
  s=.table~new; s["shipmentId"]=shipmentId; s["branchId"]=branchId; s["direction"]=direction; s["vaultId"]=vaultId; s["cashCentreId"]=cashCentreId; s["carrierId"]=carrierId; s["manifestRef"]=manifestRef; s["sealId"]=sealId; s["bundle"]=bundle; s["requestedByStaffId"]=requestedByStaffId; s["staffAuthorityRef"]=staffAuthorityRef; s["createdAt"]=createdAt~utcIsoDate; return s
::method queueRestoreState
  expose shipmentId branchId direction vaultId cashCentreId carrierId manifestRef sealId bundle requestedByStaffId staffAuthorityRef createdAt
  use arg s
  shipmentId=s["shipmentId"]~string; branchId=s["branchId"]~string; direction=.FBExternalCashUtil~token(s["direction"]); vaultId=s["vaultId"]~string; cashCentreId=s["cashCentreId"]~string; carrierId=s["carrierId"]~string; manifestRef=s["manifestRef"]~string; sealId=s["sealId"]~string; bundle=s["bundle"]; requestedByStaffId=s["requestedByStaffId"]~string; staffAuthorityRef=s["staffAuthorityRef"]~string; createdAt=.FBExternalCashUtil~dateValue(s["createdAt"]); return self

::class FederationBankExternalCashApproval public
::attribute approvalId get
::attribute shipmentIdentity get
::attribute approverStaffId get
::attribute staffAuthorityRef get
::attribute approvedAt get
::method init
  expose approvalId shipmentIdentity approverStaffId staffAuthorityRef approvedAt
  use arg approvalIdArg,shipmentIdentityArg,approverStaffIdArg,staffAuthorityRefArg,approvedAtArg=.nil
  approvalId=approvalIdArg~string; shipmentIdentity=shipmentIdentityArg~string; approverStaffId=approverStaffIdArg~string; staffAuthorityRef=staffAuthorityRefArg~string
  if approvedAtArg==.nil then approvedAt=.DateTime~new; else approvedAt=approvedAtArg
  if approvalId="" | shipmentIdentity="" | approverStaffId="" | staffAuthorityRef="" then raise syntax 88.992 array("external cash approval identity required")
::method queuePersistentType
  return "federationbank.external.cash.approval/1"
::method queuePersistentState
  expose approvalId shipmentIdentity approverStaffId staffAuthorityRef approvedAt
  s=.table~new; s["approvalId"]=approvalId; s["shipmentIdentity"]=shipmentIdentity; s["approverStaffId"]=approverStaffId; s["staffAuthorityRef"]=staffAuthorityRef; s["approvedAt"]=approvedAt~utcIsoDate; return s
::method queueRestoreState
  expose approvalId shipmentIdentity approverStaffId staffAuthorityRef approvedAt
  use arg s
  approvalId=s["approvalId"]~string; shipmentIdentity=s["shipmentIdentity"]~string; approverStaffId=s["approverStaffId"]~string; staffAuthorityRef=s["staffAuthorityRef"]~string; approvedAt=.FBExternalCashUtil~dateValue(s["approvedAt"]); return self

::class FederationBankExternalCashAuthorityEnvelope public
::attribute authorityId get
::attribute shipmentIdentity get
::attribute shipmentId get
::attribute branchId get
::attribute direction get
::attribute amountMinor get
::attribute currency get
::attribute vaultId get
::attribute manifestRef get
::attribute sealId get
::attribute makerStaffId get
::attribute makerStaffAuthorityRef get
::attribute checkerStaffId get
::attribute checkerStaffAuthorityRef get
::attribute policyRef get
::method init
  expose authorityId shipmentIdentity shipmentId branchId direction amountMinor currency vaultId manifestRef sealId makerStaffId makerStaffAuthorityRef checkerStaffId checkerStaffAuthorityRef policyRef
  use arg authorityIdArg,shipmentIdentityArg,shipmentIdArg,branchIdArg,directionArg,amountMinorArg,currencyArg,vaultIdArg,manifestRefArg,sealIdArg,makerStaffIdArg,makerStaffAuthorityRefArg,checkerStaffIdArg,checkerStaffAuthorityRefArg,policyRefArg
  authorityId=authorityIdArg~string; shipmentIdentity=shipmentIdentityArg~string; shipmentId=shipmentIdArg~string; branchId=branchIdArg~string; direction=.FBExternalCashUtil~token(directionArg); amountMinor=amountMinorArg+0; currency=.FBExternalCashUtil~token(currencyArg); vaultId=vaultIdArg~string; manifestRef=manifestRefArg~string; sealId=sealIdArg~string; makerStaffId=makerStaffIdArg~string; makerStaffAuthorityRef=makerStaffAuthorityRefArg~string; checkerStaffId=checkerStaffIdArg~string; checkerStaffAuthorityRef=checkerStaffAuthorityRefArg~string; policyRef=policyRefArg~string
  if authorityId="" | shipmentIdentity="" | shipmentId="" | branchId="" | direction="" | amountMinor<0 | currency="" | vaultId="" | manifestRef="" | sealId="" | makerStaffId="" | makerStaffAuthorityRef="" | checkerStaffId="" | checkerStaffAuthorityRef="" | policyRef="" then raise syntax 88.993 array("external cash authority identity required")
::method matchesShipment
  use arg shipment
  if shipment==.nil then return .false
  return shipment~semanticIdentity=self~shipmentIdentity & shipment~shipmentId=self~shipmentId & shipment~branchId=self~branchId & shipment~direction=self~direction & shipment~bundle~totalMinor=self~amountMinor & shipment~bundle~currency=self~currency & shipment~vaultId=self~vaultId & shipment~manifestRef=self~manifestRef & shipment~sealId=self~sealId
::method semanticIdentity
  expose authorityId shipmentIdentity makerStaffId checkerStaffId policyRef
  return "FBEXTERNALCASHAUTH/1|"||authorityId||"|"||shipmentIdentity||"|"||makerStaffId||"|"||checkerStaffId||"|"||policyRef
::method queuePersistentType
  return "federationbank.external.cash.authority/1"
::method queuePersistentState
  expose authorityId shipmentIdentity shipmentId branchId direction amountMinor currency vaultId manifestRef sealId makerStaffId makerStaffAuthorityRef checkerStaffId checkerStaffAuthorityRef policyRef
  s=.table~new; s["authorityId"]=authorityId; s["shipmentIdentity"]=shipmentIdentity; s["shipmentId"]=shipmentId; s["branchId"]=branchId; s["direction"]=direction; s["amountMinor"]=amountMinor~string; s["currency"]=currency; s["vaultId"]=vaultId; s["manifestRef"]=manifestRef; s["sealId"]=sealId; s["makerStaffId"]=makerStaffId; s["makerStaffAuthorityRef"]=makerStaffAuthorityRef; s["checkerStaffId"]=checkerStaffId; s["checkerStaffAuthorityRef"]=checkerStaffAuthorityRef; s["policyRef"]=policyRef; return s
::method queueRestoreState
  expose authorityId shipmentIdentity shipmentId branchId direction amountMinor currency vaultId manifestRef sealId makerStaffId makerStaffAuthorityRef checkerStaffId checkerStaffAuthorityRef policyRef
  use arg s
  authorityId=s["authorityId"]~string; shipmentIdentity=s["shipmentIdentity"]~string; shipmentId=s["shipmentId"]~string; branchId=s["branchId"]~string; direction=.FBExternalCashUtil~token(s["direction"]); amountMinor=s["amountMinor"]+0; currency=.FBExternalCashUtil~token(s["currency"]); vaultId=s["vaultId"]~string; manifestRef=s["manifestRef"]~string; sealId=s["sealId"]~string; makerStaffId=s["makerStaffId"]~string; makerStaffAuthorityRef=s["makerStaffAuthorityRef"]~string; checkerStaffId=s["checkerStaffId"]~string; checkerStaffAuthorityRef=s["checkerStaffAuthorityRef"]~string; policyRef=s["policyRef"]~string; return self

::class FederationBankExternalCashPolicyDecision public
::attribute allow get
::attribute code get
::attribute policyRef get
::method init
  expose allow code policyRef
  use arg allowArg,codeArg,policyRefArg
  allow=allowArg; code=.FBExternalCashUtil~token(codeArg); policyRef=policyRefArg~string

::class FederationBankExternalCashPolicyPort public
::method decide abstract

::class FederationBankExternalCashFixturePolicy subclass FederationBankExternalCashPolicyPort public
::method decide
  use arg operation,shipment
  op=.FBExternalCashUtil~token(operation)
  if shipment==.nil then return .FederationBankExternalCashPolicyDecision~new(.false,"SHIPMENT_REQUIRED","FIXTURE/0.1")
  if shipment~staffAuthorityRef="" then return .FederationBankExternalCashPolicyDecision~new(.false,"STAFF_AUTHORITY_REQUIRED","FIXTURE/0.1")
  if op="AUTHORISE" | op="DISPATCH" | op="RECEIVE" then return .FederationBankExternalCashPolicyDecision~new(.true,"ALLOW_"||op,"FIXTURE/0.1")
  return .FederationBankExternalCashPolicyDecision~new(.false,"OPERATION_NOT_ALLOWED","FIXTURE/0.1")

::class FederationBankExternalCashAuthorityIssuer public
::method issue
  use arg shipment,approval,policy
  if shipment==.nil then return .FederationBankExternalCashResult~failure("SHIPMENT_REQUIRED")
  if approval==.nil then return .FederationBankExternalCashResult~failure("CHECKER_REQUIRED")
  if approval~shipmentIdentity<>shipment~semanticIdentity then return .FederationBankExternalCashResult~failure("APPROVAL_SHIPMENT_MISMATCH")
  if approval~approverStaffId=shipment~requestedByStaffId then return .FederationBankExternalCashResult~failure("SEPARATION_OF_DUTIES")
  d=policy~decide("AUTHORISE",shipment); if \d~allow then return .FederationBankExternalCashResult~failure(d~code)
  auth=.FederationBankExternalCashAuthorityEnvelope~new("FBEXTAUTH:"||shipment~shipmentId,shipment~semanticIdentity,shipment~shipmentId,shipment~branchId,shipment~direction,shipment~bundle~totalMinor,shipment~bundle~currency,shipment~vaultId,shipment~manifestRef,shipment~sealId,shipment~requestedByStaffId,shipment~staffAuthorityRef,approval~approverStaffId,approval~staffAuthorityRef,d~policyRef)
  return .FederationBankExternalCashResult~success(auth)

::class FederationBankExternalCashReceipt public
::attribute receiptId get
::attribute shipmentIdentity get
::attribute receivingParty get
::attribute receivedBy get
::attribute sealId get
::attribute countedBundle get
::attribute custodyRef get
::attribute receivedAt get
::method init
  expose receiptId shipmentIdentity receivingParty receivedBy sealId countedBundle custodyRef receivedAt
  use arg receiptIdArg,shipmentIdentityArg,receivingPartyArg,receivedByArg,sealIdArg,countedBundleArg,custodyRefArg,receivedAtArg=.nil
  receiptId=receiptIdArg~string; shipmentIdentity=shipmentIdentityArg~string; receivingParty=.FBExternalCashUtil~token(receivingPartyArg); receivedBy=receivedByArg~string; sealId=sealIdArg~string; countedBundle=countedBundleArg; custodyRef=custodyRefArg~string
  if receivedAtArg==.nil then receivedAt=.DateTime~new; else receivedAt=receivedAtArg
  if receiptId="" | shipmentIdentity="" | receivingParty="" | receivedBy="" | sealId="" | countedBundle==.nil | custodyRef="" then raise syntax 88.994 array("external cash receipt identity required")
::method matchesShipment
  expose shipmentIdentity sealId countedBundle
  use arg shipment
  if shipment==.nil then return .false
  if shipmentIdentity<>shipment~semanticIdentity then return .false
  if sealId<>shipment~sealId then return .false
  if countedBundle~currency<>shipment~bundle~currency | countedBundle~totalMinor<>shipment~bundle~totalMinor then return .false
  return .true
::method semanticIdentity
  expose receiptId shipmentIdentity receivingParty receivedBy sealId countedBundle custodyRef
  return "FBEXTERNALCASHRECEIPT/1|"||receiptId||"|"||shipmentIdentity||"|"||receivingParty||"|"||receivedBy||"|"||sealId||"|"||countedBundle~semanticIdentity||"|"||custodyRef
::method queuePersistentType
  return "federationbank.external.cash.receipt/1"
::method queuePersistentState
  expose receiptId shipmentIdentity receivingParty receivedBy sealId countedBundle custodyRef receivedAt
  s=.table~new; s["receiptId"]=receiptId; s["shipmentIdentity"]=shipmentIdentity; s["receivingParty"]=receivingParty; s["receivedBy"]=receivedBy; s["sealId"]=sealId; s["countedBundle"]=countedBundle; s["custodyRef"]=custodyRef; s["receivedAt"]=receivedAt~utcIsoDate; return s
::method queueRestoreState
  expose receiptId shipmentIdentity receivingParty receivedBy sealId countedBundle custodyRef receivedAt
  use arg s
  receiptId=s["receiptId"]~string; shipmentIdentity=s["shipmentIdentity"]~string; receivingParty=.FBExternalCashUtil~token(s["receivingParty"]); receivedBy=s["receivedBy"]~string; sealId=s["sealId"]~string; countedBundle=s["countedBundle"]; custodyRef=s["custodyRef"]~string; receivedAt=.FBExternalCashUtil~dateValue(s["receivedAt"]); return self

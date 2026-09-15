/* FederationBank Branch Day v0.1
 * Branch opening/closing and end-of-day physical cash certification.
 * Coordinates evidence from custody authorities; does not own vault/till truth.
 */
::class FederationBankBranchDayBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.branch.day/0.1"

::class FBBranchDayUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyArray class
  use arg a
  out=.array~new; if a==.nil then return out
  do x over a; out~append(x); end
  return out
::method dateValue class
  use arg v
  if v==.nil then return .nil
  if v~isA(.DateTime) then return v
  text=v~string; if text="" then return .nil
  if text~right(1)="Z" then text=text~left(text~length-1)
  return .DateTime~fromIsoDate(text)

::class FederationBankBranchDayResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBBranchDayUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankBranchDayEndpointEvidence public
::attribute evidenceId get
::attribute endpointKind get
::attribute endpointId get
::attribute branchId get
::attribute currency get
::attribute status get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::attribute custodyRef get
::attribute sourceRef get
::attribute observedAt get
::method init
  expose evidenceId endpointKind endpointId branchId currency status expectedMinor countedMinor discrepancyMinor custodyRef sourceRef observedAt
  use arg evidenceIdArg,endpointKindArg,endpointIdArg,branchIdArg,currencyArg,statusArg,expectedArg,countedArg,discrepancyArg,custodyRefArg,sourceRefArg,observedAtArg=.nil
  evidenceId=evidenceIdArg~string; endpointKind=.FBBranchDayUtil~token(endpointKindArg); endpointId=endpointIdArg~string; branchId=branchIdArg~string; currency=.FBBranchDayUtil~token(currencyArg); status=.FBBranchDayUtil~token(statusArg); expectedMinor=expectedArg+0; countedMinor=countedArg+0; discrepancyMinor=discrepancyArg+0; custodyRef=custodyRefArg~string; sourceRef=sourceRefArg~string
  if observedAtArg==.nil then observedAt=.DateTime~new; else observedAt=observedAtArg
  if evidenceId="" | endpointKind="" | endpointId="" | branchId="" | currency="" | status="" | custodyRef="" | sourceRef="" then raise syntax 88.970 array("branch day endpoint evidence identity required")
  if endpointKind<>"VAULT" & endpointKind<>"TILL" then raise syntax 88.970 array("unsupported endpoint kind")
::method semanticIdentity
  expose evidenceId endpointKind endpointId branchId currency status expectedMinor countedMinor discrepancyMinor custodyRef sourceRef
  return "BRANCHDAYENDPOINT/1|"||evidenceId||"|"||endpointKind||":"||endpointId||"|"||branchId||"|"||currency||"|"||status||"|"||expectedMinor||"|"||countedMinor||"|"||discrepancyMinor||"|"||custodyRef||"|"||sourceRef
::method queuePersistentType
  return "federationbank.branch.day.endpoint/1"
::method queuePersistentState
  expose evidenceId endpointKind endpointId branchId currency status expectedMinor countedMinor discrepancyMinor custodyRef sourceRef observedAt
  s=.table~new; s["evidenceId"]=evidenceId; s["endpointKind"]=endpointKind; s["endpointId"]=endpointId; s["branchId"]=branchId; s["currency"]=currency; s["status"]=status; s["expectedMinor"]=expectedMinor~string; s["countedMinor"]=countedMinor~string; s["discrepancyMinor"]=discrepancyMinor~string; s["custodyRef"]=custodyRef; s["sourceRef"]=sourceRef; s["observedAt"]=observedAt~utcIsoDate; return s
::method queueRestoreState
  expose evidenceId endpointKind endpointId branchId currency status expectedMinor countedMinor discrepancyMinor custodyRef sourceRef observedAt
  use arg s
  evidenceId=s["evidenceId"]~string; endpointKind=.FBBranchDayUtil~token(s["endpointKind"]); endpointId=s["endpointId"]~string; branchId=s["branchId"]~string; currency=.FBBranchDayUtil~token(s["currency"]); status=.FBBranchDayUtil~token(s["status"]); expectedMinor=s["expectedMinor"]+0; countedMinor=s["countedMinor"]+0; discrepancyMinor=s["discrepancyMinor"]+0; custodyRef=s["custodyRef"]~string; sourceRef=s["sourceRef"]~string; observedAt=.FBBranchDayUtil~dateValue(s["observedAt"]); return self

::class FederationBankBranchDayPositionEvidence public
::attribute evidenceId get
::attribute branchId get
::attribute currency get
::attribute expectedMinor get
::attribute countedMinor get
::attribute discrepancyMinor get
::attribute inTransitMinor get
::attribute outstandingReconciliationCount get
::attribute sourceRef get
::method init
  expose evidenceId branchId currency expectedMinor countedMinor discrepancyMinor inTransitMinor outstandingReconciliationCount sourceRef
  use arg evidenceIdArg,branchIdArg,currencyArg,expectedArg,countedArg,discrepancyArg,inTransitArg,reconciliationCountArg,sourceRefArg
  evidenceId=evidenceIdArg~string; branchId=branchIdArg~string; currency=.FBBranchDayUtil~token(currencyArg); expectedMinor=expectedArg+0; countedMinor=countedArg+0; discrepancyMinor=discrepancyArg+0; inTransitMinor=inTransitArg+0; outstandingReconciliationCount=reconciliationCountArg+0; sourceRef=sourceRefArg~string
  if evidenceId="" | branchId="" | currency="" | sourceRef="" then raise syntax 88.971 array("branch position evidence identity required")
::method totalCustodyMinor
  expose expectedMinor inTransitMinor
  return expectedMinor+inTransitMinor
::method semanticIdentity
  expose evidenceId branchId currency expectedMinor countedMinor discrepancyMinor inTransitMinor outstandingReconciliationCount sourceRef
  return "BRANCHDAYPOSITION/1|"||evidenceId||"|"||branchId||"|"||currency||"|"||expectedMinor||"|"||countedMinor||"|"||discrepancyMinor||"|"||inTransitMinor||"|"||outstandingReconciliationCount||"|"||sourceRef
::method queuePersistentType
  return "federationbank.branch.day.position/1"
::method queuePersistentState
  expose evidenceId branchId currency expectedMinor countedMinor discrepancyMinor inTransitMinor outstandingReconciliationCount sourceRef
  s=.table~new; s["evidenceId"]=evidenceId; s["branchId"]=branchId; s["currency"]=currency; s["expectedMinor"]=expectedMinor~string; s["countedMinor"]=countedMinor~string; s["discrepancyMinor"]=discrepancyMinor~string; s["inTransitMinor"]=inTransitMinor~string; s["outstandingReconciliationCount"]=outstandingReconciliationCount~string; s["sourceRef"]=sourceRef; return s
::method queueRestoreState
  expose evidenceId branchId currency expectedMinor countedMinor discrepancyMinor inTransitMinor outstandingReconciliationCount sourceRef
  use arg s
  evidenceId=s["evidenceId"]~string; branchId=s["branchId"]~string; currency=.FBBranchDayUtil~token(s["currency"]); expectedMinor=s["expectedMinor"]+0; countedMinor=s["countedMinor"]+0; discrepancyMinor=s["discrepancyMinor"]+0; inTransitMinor=s["inTransitMinor"]+0; outstandingReconciliationCount=s["outstandingReconciliationCount"]+0; sourceRef=s["sourceRef"]~string; return self

::class FederationBankBranchDayControlTotals public
::attribute currency get
::attribute openingCustodyMinor get
::attribute customerCashInMinor get
::attribute customerCashOutMinor get
::attribute externalCashInMinor get
::attribute externalCashOutMinor get
::attribute adjustmentMinor get
::attribute adjustmentAuthorityRef get
::attribute closingCustodyMinor get
::attribute sourceRef get
::method init
  expose currency openingCustodyMinor customerCashInMinor customerCashOutMinor externalCashInMinor externalCashOutMinor adjustmentMinor adjustmentAuthorityRef closingCustodyMinor sourceRef
  use arg currencyArg,openingArg,customerInArg,customerOutArg,externalInArg,externalOutArg,adjustmentArg,adjustmentAuthorityRefArg,closingArg,sourceRefArg
  currency=.FBBranchDayUtil~token(currencyArg); openingCustodyMinor=openingArg+0; customerCashInMinor=customerInArg+0; customerCashOutMinor=customerOutArg+0; externalCashInMinor=externalInArg+0; externalCashOutMinor=externalOutArg+0; adjustmentMinor=adjustmentArg+0; adjustmentAuthorityRef=adjustmentAuthorityRefArg~string; closingCustodyMinor=closingArg+0; sourceRef=sourceRefArg~string
  if currency="" | sourceRef="" then raise syntax 88.972 array("branch day control totals identity required")
  if adjustmentMinor<>0 & adjustmentAuthorityRef="" then raise syntax 88.972 array("nonzero adjustment requires authority")
::method calculatedClosingMinor
  expose openingCustodyMinor customerCashInMinor customerCashOutMinor externalCashInMinor externalCashOutMinor adjustmentMinor
  return openingCustodyMinor+customerCashInMinor-customerCashOutMinor+externalCashInMinor-externalCashOutMinor+adjustmentMinor
::method balanced
  expose closingCustodyMinor
  return self~calculatedClosingMinor=closingCustodyMinor
::method semanticIdentity
  expose currency openingCustodyMinor customerCashInMinor customerCashOutMinor externalCashInMinor externalCashOutMinor adjustmentMinor adjustmentAuthorityRef closingCustodyMinor sourceRef
  return "BRANCHDAYTOTALS/1|"||currency||"|"||openingCustodyMinor||"|"||customerCashInMinor||"|"||customerCashOutMinor||"|"||externalCashInMinor||"|"||externalCashOutMinor||"|"||adjustmentMinor||"|"||adjustmentAuthorityRef||"|"||closingCustodyMinor||"|"||sourceRef
::method queuePersistentType
  return "federationbank.branch.day.totals/1"
::method queuePersistentState
  expose currency openingCustodyMinor customerCashInMinor customerCashOutMinor externalCashInMinor externalCashOutMinor adjustmentMinor adjustmentAuthorityRef closingCustodyMinor sourceRef
  s=.table~new; s["currency"]=currency; s["openingCustodyMinor"]=openingCustodyMinor~string; s["customerCashInMinor"]=customerCashInMinor~string; s["customerCashOutMinor"]=customerCashOutMinor~string; s["externalCashInMinor"]=externalCashInMinor~string; s["externalCashOutMinor"]=externalCashOutMinor~string; s["adjustmentMinor"]=adjustmentMinor~string; s["adjustmentAuthorityRef"]=adjustmentAuthorityRef; s["closingCustodyMinor"]=closingCustodyMinor~string; s["sourceRef"]=sourceRef; return s
::method queueRestoreState
  expose currency openingCustodyMinor customerCashInMinor customerCashOutMinor externalCashInMinor externalCashOutMinor adjustmentMinor adjustmentAuthorityRef closingCustodyMinor sourceRef
  use arg s
  currency=.FBBranchDayUtil~token(s["currency"]); openingCustodyMinor=s["openingCustodyMinor"]+0; customerCashInMinor=s["customerCashInMinor"]+0; customerCashOutMinor=s["customerCashOutMinor"]+0; externalCashInMinor=s["externalCashInMinor"]+0; externalCashOutMinor=s["externalCashOutMinor"]+0; adjustmentMinor=s["adjustmentMinor"]+0; adjustmentAuthorityRef=s["adjustmentAuthorityRef"]~string; closingCustodyMinor=s["closingCustodyMinor"]+0; sourceRef=s["sourceRef"]~string; return self

::class FederationBankBranchDayApproval public
::attribute approvalId get
::attribute actionIdentity get
::attribute approverStaffId get
::attribute authorityRef get
::method init
  expose approvalId actionIdentity approverStaffId authorityRef
  use arg approvalIdArg,actionIdentityArg,approverStaffIdArg,authorityRefArg
  approvalId=approvalIdArg~string; actionIdentity=actionIdentityArg~string; approverStaffId=approverStaffIdArg~string; authorityRef=authorityRefArg~string
  if approvalId="" | actionIdentity="" | approverStaffId="" | authorityRef="" then raise syntax 88.973 array("branch day approval identity required")
::method queuePersistentType
  return "federationbank.branch.day.approval/1"
::method queuePersistentState
  expose approvalId actionIdentity approverStaffId authorityRef
  s=.table~new; s["approvalId"]=approvalId; s["actionIdentity"]=actionIdentity; s["approverStaffId"]=approverStaffId; s["authorityRef"]=authorityRef; return s
::method queueRestoreState
  expose approvalId actionIdentity approverStaffId authorityRef
  use arg s
  approvalId=s["approvalId"]~string; actionIdentity=s["actionIdentity"]~string; approverStaffId=s["approverStaffId"]~string; authorityRef=s["authorityRef"]~string; return self

::class FederationBankBranchDayPolicyDecision public
::attribute allow get
::attribute code get
::method init
  expose allow code
  use arg allowArg,codeArg
  allow=allowArg; code=.FBBranchDayUtil~token(codeArg)
::class FederationBankBranchDayPolicyPort public
::method decide abstract
::class FederationBankBranchDayFixturePolicy subclass FederationBankBranchDayPolicyPort public
::method decide
  use arg operation,day=.nil
  op=.FBBranchDayUtil~token(operation)
  if op="OPEN" | op="BEGIN_CLOSE" | op="CLOSE" then return .FederationBankBranchDayPolicyDecision~new(.true,"ALLOW_"||op)
  return .FederationBankBranchDayPolicyDecision~new(.false,"OPERATION_NOT_ALLOWED")

::class FederationBankBranchDay public
::attribute dayId get
::attribute branchId get
::attribute businessDate get
::attribute state get
::attribute openedByStaffId get
::attribute closedByStaffId get
::attribute openedAt get
::attribute closedAt get
::method init
  expose dayId branchId businessDate state openedByStaffId closedByStaffId openedAt closedAt openingEndpoints openingPositions closingEndpoints closingPositions controlTotals journal
  use arg dayIdArg,branchIdArg,businessDateArg
  dayId=dayIdArg~string; branchId=branchIdArg~string; businessDate=businessDateArg~string; state="CREATED"; openedByStaffId=""; closedByStaffId=""; openedAt=.nil; closedAt=.nil; openingEndpoints=.array~new; openingPositions=.array~new; closingEndpoints=.array~new; closingPositions=.array~new; controlTotals=.array~new; journal=.array~new
  if dayId="" | branchId="" | businessDate="" then raise syntax 88.974 array("branch day identity required")
::method openingEndpoints
  expose openingEndpoints
  return .FBBranchDayUtil~copyArray(openingEndpoints)
::method openingPositions
  expose openingPositions
  return .FBBranchDayUtil~copyArray(openingPositions)
::method closingEndpoints
  expose closingEndpoints
  return .FBBranchDayUtil~copyArray(closingEndpoints)
::method closingPositions
  expose closingPositions
  return .FBBranchDayUtil~copyArray(closingPositions)
::method controlTotals
  expose controlTotals
  return .FBBranchDayUtil~copyArray(controlTotals)
::method canonical private
  use arg prefix,objects
  ids=.array~new; do o over objects; ids~append(o~semanticIdentity); end; ids~sort
  text=prefix; do id over ids; text||="|"||id; end; return text
::method openActionIdentity
  expose dayId branchId businessDate
  use arg endpoints,positions,requestedByStaffId
  return self~canonical("BRANCHDAYOPEN/1|"||dayId||"|"||branchId||"|"||businessDate||"|"||requestedByStaffId,endpoints)||self~canonical("|POSITIONS",positions)
::method beginCloseActionIdentity
  expose dayId branchId businessDate
  use arg requestedByStaffId
  return "BRANCHDAYBEGINCLOSE/1|"||dayId||"|"||branchId||"|"||businessDate||"|"||requestedByStaffId
::method closeActionIdentity
  expose dayId branchId businessDate
  use arg endpoints,positions,totals,requestedByStaffId
  return self~canonical("BRANCHDAYCLOSE/1|"||dayId||"|"||branchId||"|"||businessDate||"|"||requestedByStaffId,endpoints)||self~canonical("|POSITIONS",positions)||self~canonical("|TOTALS",totals)
::method validateEndpoints private
  expose branchId
  use arg endpoints,requiredStatus
  seen=.directory~new; vaultCount=0
  do e over endpoints
    if e~branchId<>branchId then return .FederationBankBranchDayResult~failure("ENDPOINT_BRANCH_MISMATCH")
    if e~status<>requiredStatus then return .FederationBankBranchDayResult~failure("ENDPOINT_STATUS_MISMATCH",e~endpointKind||":"||e~endpointId||":"||e~status)
    if e~discrepancyMinor<>0 | e~countedMinor<>e~expectedMinor then return .FederationBankBranchDayResult~failure("ENDPOINT_DISCREPANCY",e~endpointKind||":"||e~endpointId)
    key=e~endpointKind||":"||e~endpointId; if seen~hasIndex(key) then return .FederationBankBranchDayResult~failure("DUPLICATE_ENDPOINT",key); seen[key]=1
    if e~endpointKind="VAULT" then vaultCount+=1
  end
  if vaultCount<1 then return .FederationBankBranchDayResult~failure("VAULT_EVIDENCE_REQUIRED")
  return .FederationBankBranchDayResult~success(endpoints)
::method validatePositions private
  expose branchId
  use arg positions
  seen=.directory~new
  do p over positions
    if p~branchId<>branchId then return .FederationBankBranchDayResult~failure("POSITION_BRANCH_MISMATCH")
    if p~discrepancyMinor<>0 | p~expectedMinor<>p~countedMinor then return .FederationBankBranchDayResult~failure("BRANCH_POSITION_DISCREPANCY",p~currency)
    if p~inTransitMinor<>0 then return .FederationBankBranchDayResult~failure("CASH_IN_TRANSIT",p~currency)
    if p~outstandingReconciliationCount<>0 then return .FederationBankBranchDayResult~failure("OUTSTANDING_RECONCILIATION",p~currency)
    if seen~hasIndex(p~currency) then return .FederationBankBranchDayResult~failure("DUPLICATE_CURRENCY_POSITION",p~currency); seen[p~currency]=p
  end
  return .FederationBankBranchDayResult~success(seen)
::method validateApproval private
  use arg approval,identity,requestedByStaffId
  if approval==.nil then return .FederationBankBranchDayResult~failure("CHECKER_REQUIRED")
  if approval~actionIdentity<>identity then return .FederationBankBranchDayResult~failure("APPROVAL_ACTION_MISMATCH")
  if approval~approverStaffId=requestedByStaffId then return .FederationBankBranchDayResult~failure("SEPARATION_OF_DUTIES")
  return .FederationBankBranchDayResult~success(approval)
::method open
  expose state openedByStaffId openedAt openingEndpoints openingPositions journal
  use arg endpoints,positions,requestedByStaffId,approval,policy
  if state<>"CREATED" then return .FederationBankBranchDayResult~failure("DAY_NOT_CREATED")
  d=policy~decide("OPEN",self); if \d~allow then return .FederationBankBranchDayResult~failure(d~code)
  e=self~validateEndpoints(endpoints,"OPEN"); if \e~ok then return e
  p=self~validatePositions(positions); if \p~ok then return p
  identity=self~openActionIdentity(endpoints,positions,requestedByStaffId); a=self~validateApproval(approval,identity,requestedByStaffId); if \a~ok then return a
  openingEndpoints=.FBBranchDayUtil~copyArray(endpoints); openingPositions=.FBBranchDayUtil~copyArray(positions); openedByStaffId=requestedByStaffId~string; openedAt=.DateTime~new; state="OPEN"; journal~append("OPEN:"||approval~approvalId)
  return .FederationBankBranchDayResult~success(self)
::method beginClose
  expose state journal
  use arg requestedByStaffId,approval,policy
  if state<>"OPEN" then return .FederationBankBranchDayResult~failure("DAY_NOT_OPEN")
  d=policy~decide("BEGIN_CLOSE",self); if \d~allow then return .FederationBankBranchDayResult~failure(d~code)
  identity=self~beginCloseActionIdentity(requestedByStaffId); a=self~validateApproval(approval,identity,requestedByStaffId); if \a~ok then return a
  state="CLOSING"; journal~append("BEGIN_CLOSE:"||approval~approvalId); return .FederationBankBranchDayResult~success(self)
::method close
  expose state openingPositions closingEndpoints closingPositions controlTotals closedByStaffId closedAt journal
  use arg endpoints,positions,totals,requestedByStaffId,approval,policy
  if state<>"CLOSING" then return .FederationBankBranchDayResult~failure("DAY_NOT_CLOSING")
  d=policy~decide("CLOSE",self); if \d~allow then return .FederationBankBranchDayResult~failure(d~code)
  e=self~validateEndpoints(endpoints,"CLOSED"); if \e~ok then return e
  p=self~validatePositions(positions); if \p~ok then return p
  openByCurrency=.directory~new; do o over openingPositions; openByCurrency[o~currency]=o; end
  closeByCurrency=p~value; totalsByCurrency=.directory~new
  do t over totals
    if totalsByCurrency~hasIndex(t~currency) then return .FederationBankBranchDayResult~failure("DUPLICATE_CONTROL_TOTALS",t~currency)
    if \openByCurrency~hasIndex(t~currency) | \closeByCurrency~hasIndex(t~currency) then return .FederationBankBranchDayResult~failure("CONTROL_TOTAL_CURRENCY_MISMATCH",t~currency)
    if t~openingCustodyMinor<>openByCurrency[t~currency]~totalCustodyMinor then return .FederationBankBranchDayResult~failure("OPENING_CONTROL_TOTAL_MISMATCH",t~currency)
    if t~closingCustodyMinor<>closeByCurrency[t~currency]~totalCustodyMinor then return .FederationBankBranchDayResult~failure("CLOSING_CONTROL_TOTAL_MISMATCH",t~currency)
    if \t~balanced then return .FederationBankBranchDayResult~failure("CASH_CONTROL_TOTALS_UNBALANCED",t~currency)
    totalsByCurrency[t~currency]=t
  end
  do c over closeByCurrency; if \totalsByCurrency~hasIndex(c) then return .FederationBankBranchDayResult~failure("CONTROL_TOTALS_REQUIRED",c); end
  identity=self~closeActionIdentity(endpoints,positions,totals,requestedByStaffId); a=self~validateApproval(approval,identity,requestedByStaffId); if \a~ok then return a
  closingEndpoints=.FBBranchDayUtil~copyArray(endpoints); closingPositions=.FBBranchDayUtil~copyArray(positions); controlTotals=.FBBranchDayUtil~copyArray(totals); closedByStaffId=requestedByStaffId~string; closedAt=.DateTime~new; state="CLOSED"; journal~append("CLOSE:"||approval~approvalId); return .FederationBankBranchDayResult~success(self)
::method queuePersistentType
  return "federationbank.branch.day/1"
::method queuePersistentState
  expose dayId branchId businessDate state openedByStaffId closedByStaffId openedAt closedAt openingEndpoints openingPositions closingEndpoints closingPositions controlTotals journal
  s=.table~new; s["dayId"]=dayId; s["branchId"]=branchId; s["businessDate"]=businessDate; s["state"]=state; s["openedByStaffId"]=openedByStaffId; s["closedByStaffId"]=closedByStaffId; if openedAt==.nil then s["openedAt"]=""; else s["openedAt"]=openedAt~utcIsoDate; if closedAt==.nil then s["closedAt"]=""; else s["closedAt"]=closedAt~utcIsoDate; s["openingEndpoints"]=openingEndpoints; s["openingPositions"]=openingPositions; s["closingEndpoints"]=closingEndpoints; s["closingPositions"]=closingPositions; s["controlTotals"]=controlTotals; s["journal"]=journal; return s
::method queueRestoreState
  expose dayId branchId businessDate state openedByStaffId closedByStaffId openedAt closedAt openingEndpoints openingPositions closingEndpoints closingPositions controlTotals journal
  use arg s
  dayId=s["dayId"]~string; branchId=s["branchId"]~string; businessDate=s["businessDate"]~string; state=.FBBranchDayUtil~token(s["state"]); openedByStaffId=s["openedByStaffId"]~string; closedByStaffId=s["closedByStaffId"]~string; openedAt=.FBBranchDayUtil~dateValue(s["openedAt"]); closedAt=.FBBranchDayUtil~dateValue(s["closedAt"]); openingEndpoints=s["openingEndpoints"]; openingPositions=s["openingPositions"]; closingEndpoints=s["closingEndpoints"]; closingPositions=s["closingPositions"]; controlTotals=s["controlTotals"]; journal=s["journal"]; return self

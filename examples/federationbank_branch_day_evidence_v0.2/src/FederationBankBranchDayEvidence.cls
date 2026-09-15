/* FederationBank Branch Day Evidence v0.2
 * Adapters from authoritative branch-cash/till/teller-cash/external-cash state
 * into Branch Day typed evidence. No UI and no duplicated financial truth.
 */
::class FederationBankBranchDayEvidenceBuild public
::constant VERSION "0.2"
::constant API_VERSION "federationbank.branch.day.evidence/0.2"

::class FBBranchDayEvidenceUtil public
::method token class
  use arg v
  if v==.nil then return ""
  return v~string~strip~upper
::method copyArray class
  use arg a
  out=.array~new; if a==.nil then return out
  do x over a; out~append(x); end; return out

::class FederationBankBranchDayEvidenceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBBranchDayEvidenceUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankBranchDayEvidenceSet public
::attribute branchId get
::attribute businessDate get
::attribute currency get
::attribute endpoints get
::attribute positions get
::attribute totals get
::attribute capturedAt get
::method init
  expose branchId businessDate currency endpoints positions totals capturedAt
  use arg branchIdArg,businessDateArg,currencyArg,endpointsArg,positionsArg,totalsArg=.nil,capturedAtArg=.nil
  branchId=branchIdArg~string; businessDate=businessDateArg~string; currency=.FBBranchDayEvidenceUtil~token(currencyArg); endpoints=.FBBranchDayEvidenceUtil~copyArray(endpointsArg); positions=.FBBranchDayEvidenceUtil~copyArray(positionsArg); if totalsArg==.nil then totals=.array~new; else totals=.FBBranchDayEvidenceUtil~copyArray(totalsArg); if capturedAtArg==.nil then capturedAt=.DateTime~new; else capturedAt=capturedAtArg
::method semanticIdentity
  expose branchId businessDate currency endpoints positions totals
  ids=.array~new; do e over endpoints; ids~append(e~semanticIdentity); end; do p over positions; ids~append(p~semanticIdentity); end; do t over totals; ids~append(t~semanticIdentity); end; ids~sort; out="FBBRANCHDAYEVIDENCE/1|"||branchId||"|"||businessDate||"|"||currency; do i over ids; out||="|"||i; end; return out

::class FederationBankBranchDayEvidenceAssembler public
::method init
  expose branchCashService tills tellerCashService externalCashService
  use arg branchCashServiceArg,tillsArg,tellerCashServiceArg=.nil,externalCashServiceArg=.nil
  branchCashService=branchCashServiceArg; if tillsArg==.nil then tills=.directory~new; else tills=tillsArg; tellerCashService=tellerCashServiceArg; externalCashService=externalCashServiceArg
  if branchCashService==.nil then raise syntax 88.998 array("branch cash service required for Branch Day evidence")
::method endpointEvidence
  expose branchCashService tills
  use arg branchId,currency
  cur=.FBBranchDayEvidenceUtil~token(currency); out=.array~new; vs=branchCashService~state~vaults
  do id over vs
    v=vs[id]; if v~branchId=branchId & v~currency=cur then out~append(.FederationBankBranchDayEndpointEvidence~new("BD:VAULT:"||v~vaultId||":"||v~status,"VAULT",v~vaultId,branchId,cur,v~status,v~expectedMinor,v~countedMinor,v~discrepancyMinor,"VAULT-CONTROL:"||v~controlRef,"FEDERATIONBANK_BRANCH_CASH:"||v~vaultId))
  end
  do id over tills
    t=tills[id]; if t~branchId=branchId & t~currency=cur then do
      custody="TILL-CUSTODY:"||t~tillId||":"||t~custodianStaffId
      out~append(.FederationBankBranchDayEndpointEvidence~new("BD:TILL:"||t~tillId||":"||t~status,"TILL",t~tillId,branchId,cur,t~status,t~expectedMinor,t~countedMinor,t~discrepancyMinor,custody,"FEDERATIONBANK_TELLER_TILL:"||t~tillId))
    end
  end
  return out
::method branchCashReconciliationCount private
  expose branchCashService
  use arg branchId,currency
  n=0; ws=branchCashService~state~works; cur=.FBBranchDayEvidenceUtil~token(currency)
  do id over ws; w=ws[id]; if w~transfer~branchId=branchId & w~transfer~bundle~currency=cur then if w~state="RECONCILIATION_REQUIRED" then n+=1; end; return n
::method tellerCashReconciliationCount private
  expose tellerCashService
  use arg branchId,currency,businessDate=""
  if tellerCashService==.nil then return 0
  n=0; ws=tellerCashService~state~works; cur=.FBBranchDayEvidenceUtil~token(currency)
  do id over ws
    w=ws[id]; i=w~instruction
    if i~custodyContext~branchId=branchId & i~bundle~currency=cur then do
      if businessDate="" | w~updatedAt~utcIsoDate~left(10)=businessDate then if w~state="RECONCILIATION_REQUIRED" | w~state="COMPENSATION_REQUIRED" then n+=1
    end
  end
  return n
::method externalOutstandingCount private
  expose externalCashService
  use arg branchId,currency
  if externalCashService==.nil then return 0
  return externalCashService~branchOutstandingCount(branchId,currency)
::method positionEvidence
  expose branchCashService externalCashService
  use arg branchId,currency,businessDate=""
  es=self~endpointEvidence(branchId,currency); expected=0; counted=0; discrepancy=0
  do e over es; expected+=e~expectedMinor; counted+=e~countedMinor; discrepancy+=e~discrepancyMinor; end
  inTransit=branchCashService~inTransitMinor(branchId,currency)
  if externalCashService<>.nil then inTransit+=externalCashService~branchInTransitMinor(branchId,currency)
  recon=self~branchCashReconciliationCount(branchId,currency)+self~tellerCashReconciliationCount(branchId,currency,businessDate)+self~externalOutstandingCount(branchId,currency)
  return .FederationBankBranchDayPositionEvidence~new("BD:POSITION:"||branchId||":"||.FBBranchDayEvidenceUtil~token(currency),branchId,currency,expected,counted,discrepancy,inTransit,recon,"BRANCH-DAY-EVIDENCE-ASSEMBLER/0.2")
::method customerCashMinor private
  expose tellerCashService
  use arg branchId,currency,direction,businessDate
  if tellerCashService==.nil then return 0
  total=0; ws=tellerCashService~state~works; cur=.FBBranchDayEvidenceUtil~token(currency); dir=.FBBranchDayEvidenceUtil~token(direction)
  do id over ws
    w=ws[id]; i=w~instruction
    if w~state="COMPLETED" & i~custodyContext~branchId=branchId & i~bundle~currency=cur & i~direction=dir then if businessDate="" | w~updatedAt~utcIsoDate~left(10)=businessDate then total+=i~bundle~totalMinor
  end
  return total
::method externalCashMinor private
  expose externalCashService
  use arg branchId,currency,direction,businessDate
  if externalCashService==.nil then return 0
  return externalCashService~completedMinor(branchId,currency,direction,businessDate)
::method openingEvidence
  use arg branchId,businessDate,currency
  es=self~endpointEvidence(branchId,currency); p=self~positionEvidence(branchId,currency,businessDate); return .FederationBankBranchDayEvidenceSet~new(branchId,businessDate,currency,es,.array~of(p))
::method closingEvidence
  use arg day,currency,adjustmentMinor=0,adjustmentAuthorityRef=""
  if day==.nil then return .FederationBankBranchDayEvidenceResult~failure("BRANCH_DAY_REQUIRED")
  cur=.FBBranchDayEvidenceUtil~token(currency); es=self~endpointEvidence(day~branchId,cur); p=self~positionEvidence(day~branchId,cur,day~businessDate)
  opening=0; found=.false; do op over day~openingPositions; if op~currency=cur then do; opening=op~totalCustodyMinor; found=.true; leave; end; end
  if \found then return .FederationBankBranchDayEvidenceResult~failure("OPENING_POSITION_NOT_FOUND",cur)
  customerIn=self~customerCashMinor(day~branchId,cur,"DEPOSIT",day~businessDate); customerOut=self~customerCashMinor(day~branchId,cur,"WITHDRAWAL",day~businessDate); externalIn=self~externalCashMinor(day~branchId,cur,"INBOUND",day~businessDate); externalOut=self~externalCashMinor(day~branchId,cur,"OUTBOUND",day~businessDate)
  source="TELLER-CASH+EXTERNAL-CASH:"||day~dayId||":"||cur
  t=.FederationBankBranchDayControlTotals~new(cur,opening,customerIn,customerOut,externalIn,externalOut,adjustmentMinor,adjustmentAuthorityRef,p~totalCustodyMinor,source)
  set=.FederationBankBranchDayEvidenceSet~new(day~branchId,day~businessDate,cur,es,.array~of(p),.array~of(t)); return .FederationBankBranchDayEvidenceResult~success(set)
::requires "FederationBankBranchDay.cls"
::requires "FederationBankBranchCashService.cls"
::requires "FederationBankTellerTill.cls"
::requires "FederationBankExternalCashService.cls"

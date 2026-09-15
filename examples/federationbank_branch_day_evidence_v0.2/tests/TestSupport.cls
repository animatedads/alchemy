::class FBBranchDayEvidenceTest public
::method assertTrue class
  use arg c,m="assertion failed"
  if \c then raise syntax 88.901 array(m)
::method assertEq class
  use arg e,a,m="values differ"
  if e~string<>a~string then raise syntax 88.901 array(m||" expected="||e||" actual="||a)
::method bcBundle class
  use arg amount
  d=.directory~new; d[amount~string]=1; return .FederationBankBranchCashBundle~new("GBP",d)
::method tillBundle class
  use arg amount
  d=.directory~new; d[amount~string]=1; return .FederationBankCashBundle~new("GBP",d)
::method branchCashService class
  v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP"); c=.FederationBankBranchCashControl~new("IOM-DOUGLAS","VAULT-1","STAFF-A","STAFF-B","CTRL:VAULT-1"); r=v~open(c,self~bcBundle(80000),.FederationBankBranchCashFixturePolicy~new); self~assertTrue(r~ok)
  s=.FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,.directory~new); ignore=s~addVault(v); return s
::method openTill class
  t=.FederationBankTellerTill~new("TILL-04","IOM-DOUGLAS","GBP"); ctx=.FederationBankTillCustodyContext~new("TILL-04","IOM-DOUGLAS","TELLER-04","SESSION-1","WS-1","CUSTODY:TILL-04"); a=.FederationBankTillApproval~new("APR-OPEN","OPEN","SUP-1","OPEN"); r=t~open(ctx,self~tillBundle(20000),a,.FederationBankTillPolicy~new); self~assertTrue(r~ok); return t
::method tellerCashState class
  return .FBBranchDayEvidenceFakeTellerCashState~new
::method tellerCashService class
  use arg state
  return .FBBranchDayEvidenceFakeTellerCashService~new(state)
::method cashWork class
  use arg id,direction,amount,state="COMPLETED"
  ctx=.FederationBankTillCustodyContext~new("TILL-04","IOM-DOUGLAS","TELLER-04","SESSION:"||id,"WS-1","CUSTODY:TILL-04")
  i=.FBBranchDayEvidenceFakeCashInstruction~new(id,direction,self~tillBundle(amount),ctx)
  return .FBBranchDayEvidenceFakeCashWork~new(i,state)
::method externalService class
  v=.FederationBankExternalCashMemoryVaultPort~new("IOM-DOUGLAS","VAULT-X","GBP",100000); return .FederationBankExternalCashService~new(.FederationBankExternalCashFixturePolicy~new,v)
::method externalShipment class
  use arg id,direction,amount
  d=.directory~new; d[amount~string]=1; b=.FederationBankExternalCashBundle~new("GBP",d); return .FederationBankExternalCashShipment~new(id,"IOM-DOUGLAS",direction,"VAULT-X","CENTRE","CARRIER","MAN:"||id,"SEAL:"||id,b,"STAFF-A","STAFF-AUTH:A")
::method externalComplete class
  use arg service,shipment
  a=.FederationBankExternalCashApproval~new("APR:"||shipment~shipmentId,shipment~semanticIdentity,"STAFF-B","STAFF-AUTH:B"); p=.directory~new; p["shipment"]=shipment; p["approval"]=a; ignore=service~handle(.FederationBankExternalCashServiceEnvelope~new("SUB:"||shipment~shipmentId,"FBEXTCASH.SHIPMENT.SUBMIT","STAFF-A","CASH",p)); p=.directory~new; p["shipmentId"]=shipment~shipmentId; ignore=service~handle(.FederationBankExternalCashServiceEnvelope~new("DSP:"||shipment~shipmentId,"FBEXTCASH.SHIPMENT.DISPATCH","STAFF-A","CASH",p)); rec=.FederationBankExternalCashReceipt~new("REC:"||shipment~shipmentId,shipment~semanticIdentity,"CASH_CENTRE","STAFF-C",shipment~sealId,shipment~bundle,"CUSTODY:"||shipment~shipmentId); p["receipt"]=rec; return service~handle(.FederationBankExternalCashServiceEnvelope~new("RCV:"||shipment~shipmentId,"FBEXTCASH.SHIPMENT.RECEIVE","STAFF-C","CASH",p))

::class FBBranchDayEvidenceFakeCashInstruction public
::attribute cashWorkId get
::attribute direction get
::attribute bundle get
::attribute custodyContext get
::method init
  expose cashWorkId direction bundle custodyContext
  use arg idArg,directionArg,bundleArg,contextArg
  cashWorkId=idArg~string; direction=directionArg~string~upper; bundle=bundleArg; custodyContext=contextArg

::class FBBranchDayEvidenceFakeCashWork public
::attribute instruction get
::attribute state
::attribute updatedAt get
::method init
  expose instruction state updatedAt
  use arg instructionArg,stateArg
  instruction=instructionArg; state=stateArg~string~upper; updatedAt=.DateTime~new

::class FBBranchDayEvidenceFakeTellerCashState public
::method init; expose works; works=.directory~new
::method putWork; expose works; use arg w; works[w~instruction~cashWorkId]=w; return w
::method works; expose works; d=.directory~new; do k over works; d[k]=works[k]; end; return d

::class FBBranchDayEvidenceFakeTellerCashService public
::method init; expose state; use arg state
::method state; expose state; return state
::requires "FederationBankBranchDayEvidence.cls"
::requires "FederationBankBranchDay.cls"
::requires "FederationBankBranchCashService.cls"
::requires "FederationBankTellerTill.cls"
::requires "FederationBankExternalCashService.cls"

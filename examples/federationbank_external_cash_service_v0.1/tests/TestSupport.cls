::class FBExtServiceTest public
::method assertTrue class
  use arg c,m="assertion failed"
  if \c then raise syntax 88.999 array(m)
::method assertEq class
  use arg e,a,m="values differ"
  if e~string<>a~string then raise syntax 88.999 array(m||" expected="||e||" actual="||a)
::method bundle class
  use arg amount=10000
  d=.directory~new; d[amount~string]=1; return .FederationBankExternalCashBundle~new("GBP",d)
::method shipment class
  use arg id="S1",direction="INBOUND",amount=10000
  return .FederationBankExternalCashShipment~new(id,"IOM-DOUGLAS",direction,"VAULT-1","CASH-CENTRE-IOM","CARRIER-1","MAN:"||id,"SEAL:"||id,self~bundle(amount),"STAFF-A","STAFF-AUTH:A")
::method approval class
  use arg s
  return .FederationBankExternalCashApproval~new("APR:"||s~shipmentId,s~semanticIdentity,"STAFF-B","STAFF-AUTH:B")
::method submit class
  use arg service,s,id="CMD-SUB"
  p=.directory~new; p["shipment"]=s; p["approval"]=self~approval(s); return service~handle(.FederationBankExternalCashServiceEnvelope~new(id,"FBEXTCASH.SHIPMENT.SUBMIT","STAFF-A","CASH_MANAGER",p,"CORR:"||s~shipmentId))
::method dispatch class
  use arg service,s,id="CMD-DSP"
  p=.directory~new; p["shipmentId"]=s~shipmentId; return service~handle(.FederationBankExternalCashServiceEnvelope~new(id,"FBEXTCASH.SHIPMENT.DISPATCH","STAFF-A","CASH_MANAGER",p,"CORR:"||s~shipmentId))
::method receive class
  use arg service,s,amount=.nil,id="CMD-RCV"
  if amount==.nil then amount=s~bundle~totalMinor
  rec=.FederationBankExternalCashReceipt~new("REC:"||s~shipmentId,s~semanticIdentity,if s~direction="INBOUND" then "BRANCH" else "CASH_CENTRE","STAFF-C",s~sealId,self~bundle(amount),"CUSTODY:"||s~shipmentId)
  p=.directory~new; p["shipmentId"]=s~shipmentId; p["receipt"]=rec; return service~handle(.FederationBankExternalCashServiceEnvelope~new(id,"FBEXTCASH.SHIPMENT.RECEIVE","STAFF-C","CASH_RECEIVER",p,"CORR:"||s~shipmentId))
::method service class
  use arg vault=.nil,store=.nil,sink=.nil
  if vault==.nil then vault=.FederationBankExternalCashMemoryVaultPort~new("IOM-DOUGLAS","VAULT-1","GBP",100000)
  return .FederationBankExternalCashService~new(.FederationBankExternalCashFixturePolicy~new,vault,store,sink)
::requires "FederationBankExternalCashService.cls"

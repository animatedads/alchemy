::class FBBranchCashServiceTestSupport public
::method assertTrue class
  use arg condition,message="assertion failed"
  if \condition then raise syntax 88.901 array(message)
::method assertEq class
  use arg actual,expected,message="values differ"
  if actual<>expected then raise syntax 88.901 array(message||" actual="||actual||" expected="||expected)
::method bundle class
  use arg amountMinor,currency="GBP"
  d=.directory~new; d[amountMinor~string]=1; return .FederationBankBranchCashBundle~new(currency,d)
::method control class
  use arg vaultId="VAULT-1",a="STAFF-A",b="STAFF-B"
  return .FederationBankBranchCashControl~new("IOM-DOUGLAS",vaultId,a,b,"CTRL:"||a||":"||b)
::method openVault class
  use arg vaultId="VAULT-1",amount=100000
  v=.FederationBankBranchCashVault~new(vaultId,"IOM-DOUGLAS","GBP"); r=v~open(self~control(vaultId),self~bundle(amount),.FederationBankBranchCashFixturePolicy~new); self~assertTrue(r~ok,"open vault"); return v
::method transfer class
  use arg id="TX-1",sourceKind="VAULT",sourceId="VAULT-1",destKind="TILL",destId="TILL-1",amount=10000,maker="STAFF-A",reason="TILL_REPLENISHMENT"
  return .FederationBankBranchCashTransfer~new(id,"IOM-DOUGLAS",sourceKind,sourceId,destKind,destId,self~bundle(amount),reason,maker,"STAFF-AUTH:"||maker)
::method approval class
  use arg t,checker="STAFF-B"
  return .FederationBankBranchCashApproval~new("APR:"||t~transferId,t~semanticIdentity,checker,"STAFF-AUTH:"||checker)
::method ports class
  d=.directory~new; return d
::method service class
  use arg ports=.nil,store=.nil,sink=.nil
  if ports==.nil then ports=self~ports
  return .FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,ports,store,sink)
::method envelope class
  use arg id,t,a
  p=.directory~new; p["transfer"]=t; p["approval"]=a; return .FederationBankBranchCashServiceEnvelope~new("CMD:"||id,"FBBRANCHCASH.TRANSFER.SUBMIT",t~requestedByStaffId,"TELLER",p,"CORR:"||id)
::requires "FederationBankBranchCashService.cls"

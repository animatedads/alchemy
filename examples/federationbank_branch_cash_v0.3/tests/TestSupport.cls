::class FBBranchCashTestSupport public
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
  use arg vaultId="VAULT-1",branchId="IOM-DOUGLAS",a="STAFF-A",b="STAFF-B",ref="CTRL-1"
  return .FederationBankBranchCashControl~new(branchId,vaultId,a,b,ref)
::method openVault class
  use arg vaultId="VAULT-1",amountMinor=100000
  v=.FederationBankBranchCashVault~new(vaultId,"IOM-DOUGLAS","GBP"); r=v~open(self~control(vaultId),self~bundle(amountMinor),.FederationBankBranchCashFixturePolicy~new); self~assertTrue(r~ok,"open vault"); return v
::method transfer class
  use arg transferId="TX-1",sourceKind="VAULT",sourceId="VAULT-1",destKind="TILL",destId="TILL-1",amountMinor=10000,maker="STAFF-A"
  return .FederationBankBranchCashTransfer~new(transferId,"IOM-DOUGLAS",sourceKind,sourceId,destKind,destId,self~bundle(amountMinor),"TILL_REPLENISHMENT",maker,"STAFF-AUTH:"||maker)
::method approval class
  use arg transfer,staff="STAFF-B"
  return .FederationBankBranchCashApproval~new("APR:"||transfer~transferId,transfer~semanticIdentity,staff,"STAFF-AUTH:"||staff)
::requires "FederationBankBranchCash.cls"

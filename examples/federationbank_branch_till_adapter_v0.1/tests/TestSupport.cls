::class FBBranchTillTest public
::method assertTrue class
  use arg condition,message="assertion failed"
  if \condition then do; say "FAIL:" message; exit 1; end
::method assertEq class
  use arg expected,actual,message="values differ"
  if expected~string<>actual~string then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
::method tillBundle class
  use arg amount,currency="GBP"
  d=.directory~new; d[amount~string]=1; return .FederationBankCashBundle~new(currency,d)
::method branchBundle class
  use arg amount,currency="GBP"
  d=.directory~new; d[amount~string]=1; return .FederationBankBranchCashBundle~new(currency,d)
::method context class
  use arg tillId="TILL-04",staffId="TELLER-04",branchId="IOM-DOUGLAS"
  return .FederationBankTillCustodyContext~new(tillId,branchId,staffId,"SESSION:"||staffId,"WS:"||tillId,"CUSTODY:"||staffId)
::method openTill class
  use arg tillId="TILL-04",staffId="TELLER-04",amount=10000,branchId="IOM-DOUGLAS"
  t=.FederationBankTellerTill~new(tillId,branchId,"GBP"); c=self~context(tillId,staffId,branchId)
  a=.FederationBankTillApproval~new("OPENAPR:"||tillId,"OPEN","OPEN-SUP","OPEN")
  r=t~open(c,self~tillBundle(amount),a); self~assertTrue(r~ok,"till open failed "||r~code)
  pair=.directory~new; pair["till"]=t; pair["context"]=c; return pair
::method transfer class
  use arg id="TX-1",sourceKind="VAULT",sourceId="VAULT-1",destKind="TILL",destId="TILL-04",amount=20000,maker="BRANCH-OPS",branchId="IOM-DOUGLAS"
  return .FederationBankBranchCashTransfer~new(id,branchId,sourceKind,sourceId,destKind,destId,self~branchBundle(amount),"INTERNAL_CASH_TRANSFER",maker,"STAFF-AUTH:"||maker)
::method branchApproval class
  use arg transfer,checker="CASH-SUP-01"
  return .FederationBankBranchCashApproval~new("BCAPR:"||transfer~transferId,transfer~semanticIdentity,checker,"STAFF-AUTH:"||checker)
::method authority class
  use arg transfer,approval=.nil
  if approval==.nil then approval=self~branchApproval(transfer)
  r=.FederationBankBranchCashAuthorityIssuer~new~issue(transfer,approval,.FederationBankBranchCashFixturePolicy~new)
  self~assertTrue(r~ok,"authority issue failed "||r~code); return r~value
::method openVault class
  use arg amount=100000
  v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP")
  c=.FederationBankBranchCashControl~new("IOM-DOUGLAS","VAULT-1","VAULT-A","VAULT-B","CTRL-1")
  r=v~open(c,self~branchBundle(amount),.FederationBankBranchCashFixturePolicy~new); self~assertTrue(r~ok,"vault open failed "||r~code); return v
::requires "FederationBankBranchTillAdapter.cls"
::requires "FederationBankBranchCashService.cls"

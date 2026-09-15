::class FBTillTest public
::method assertEq class
  use arg e,a,m="assertEq"
  if e~string<>a~string then raise syntax 98.900 array(m||" expected="||e||" actual="||a)
::method assertTrue class
  use arg x,m="assertTrue"
  if \x then raise syntax 98.900 array(m)
::method bundle class
  use arg amount,currency="GBP"
  d=.directory~new; d["100"]=amount%100; r=amount//100; if r>0 then d["1"]=r
  return .FederationBankCashBundle~new(currency,d)
::method ctx class
  use arg staff="TELLER-04",till="TILL-04"
  return .FederationBankTillCustodyContext~new(till,"DOUGLAS",staff,"S:"||staff,"WS-04","CUSTODY:"||staff)
::method approval class
  use arg action=.nil,approver="SUP-01",id="A1"
  ident="OPEN"; aid="OPEN"
  if action<>.nil then do; ident=action~semanticIdentity; aid=action~actionId; end
  return .FederationBankTillApproval~new(id,aid,approver,ident)
::requires "../src/FederationBankTellerTill.cls"

::class FBTillInternalTest public
::method instruction class
  use arg id="ITX-1",sourceKind="VAULT",sourceId="VAULT-1",destKind="TILL",destId="TILL-04",amount=10000,maker="BRANCH-OPS"
  return .FederationBankTillInternalCashInstruction~new(id,"DOUGLAS",sourceKind,sourceId,destKind,destId,amount,"GBP","BRANCH-CASH-AUTH:"||id,maker)
::method approval class
  use arg instruction,approver="SUP-01"
  return .FederationBankTillInternalCashApproval~new("IAPR:"||instruction~transferId,instruction~semanticIdentity,approver,"STAFF-AUTH:"||approver)

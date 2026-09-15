::class FBExternalCashTest public
::method assertTrue class
  use arg c,m="assertion failed"
  if \c then raise syntax 88.999 array(m)
::method assertEq class
  use arg e,a,m="values differ"
  if e~string<>a~string then raise syntax 88.999 array(m||" expected="||e||" actual="||a)
::method bundle class
  use arg amount=10000,currency="GBP"
  d=.directory~new; d[amount~string]=1; return .FederationBankExternalCashBundle~new(currency,d)
::method shipment class
  use arg id="SHIP-1",direction="INBOUND",amount=10000,maker="STAFF-A"
  return .FederationBankExternalCashShipment~new(id,"IOM-DOUGLAS",direction,"VAULT-1","CASH-CENTRE-IOM","CARRIER-1","MANIFEST:"||id,"SEAL:"||id,self~bundle(amount),maker,"STAFF-AUTH:"||maker)
::method approval class
  use arg s,checker="STAFF-B"
  return .FederationBankExternalCashApproval~new("APR:"||s~shipmentId,s~semanticIdentity,checker,"STAFF-AUTH:"||checker)
::method authority class
  use arg s,checker="STAFF-B"
  r=.FederationBankExternalCashAuthorityIssuer~new~issue(s,self~approval(s,checker),.FederationBankExternalCashFixturePolicy~new); self~assertTrue(r~ok,r~code); return r~value
::requires "FederationBankExternalCash.cls"

::class FBExtBranchAdapterTest public
::method assertTrue class
  use arg c,m="assertion failed"
  if \c then raise syntax 88.901 array(m)
::method assertEq class
  use arg e,a,m="values differ"
  if e~string<>a~string then raise syntax 88.901 array(m||" expected="||e||" actual="||a)
::method bcBundle class
  use arg amount
  d=.directory~new; d[amount~string]=1; return .FederationBankBranchCashBundle~new("GBP",d)
::method extBundle class
  use arg amount
  d=.directory~new; d[amount~string]=1; return .FederationBankExternalCashBundle~new("GBP",d)
::method branchService class
  v=.FederationBankBranchCashVault~new("VAULT-1","IOM-DOUGLAS","GBP"); c=.FederationBankBranchCashControl~new("IOM-DOUGLAS","VAULT-1","CUST-A","CUST-B","CTRL:OPEN"); r=v~open(c,self~bcBundle(100000),.FederationBankBranchCashFixturePolicy~new); self~assertTrue(r~ok); s=.FederationBankBranchCashService~new(.FederationBankBranchCashFixturePolicy~new,.directory~new); ignore=s~addVault(v); return s
::method shipment class
  use arg id="S1",direction="OUTBOUND",amount=10000
  return .FederationBankExternalCashShipment~new(id,"IOM-DOUGLAS",direction,"VAULT-1","CENTRE","CARRIER","MAN:"||id,"SEAL:"||id,self~extBundle(amount),"STAFF-A","STAFF-AUTH:A")
::method authority class
  use arg s
  a=.FederationBankExternalCashApproval~new("APR:"||s~shipmentId,s~semanticIdentity,"STAFF-B","STAFF-AUTH:B"); return .FederationBankExternalCashAuthorityIssuer~new~issue(s,a,.FederationBankExternalCashFixturePolicy~new)~value
::method registryFor class
  use arg service,shipment,authority
  v=service~state~vault(shipment~vaultId); i=.FederationBankBranchCashExternalInstruction~new(shipment~shipmentId,shipment~branchId,shipment~direction,shipment~vaultId,shipment~bundle~totalMinor,shipment~bundle~currency,authority~semanticIdentity,shipment~manifestRef,shipment~sealId,shipment~requestedByStaffId); c=.FederationBankBranchCashExternalControl~new("EXTCTRL:"||shipment~shipmentId,i~semanticIdentity,v~primaryStaffId,v~checkerStaffId,authority~semanticIdentity); r=.FederationBankExternalBranchCashControlRegistry~new; r~put(shipment~shipmentId,c); return r
::method receipt class
  use arg s
  return .FederationBankExternalCashReceipt~new("REC:"||s~shipmentId,s~semanticIdentity,"BRANCH","CUST-A",s~sealId,s~bundle,"CUSTODY:"||s~shipmentId)
::requires "FederationBankExternalBranchCashAdapter.cls"

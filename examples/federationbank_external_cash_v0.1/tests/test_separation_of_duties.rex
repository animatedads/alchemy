s=.FBExternalCashTest~shipment("S2","OUTBOUND",10000,"STAFF-A"); r=.FederationBankExternalCashAuthorityIssuer~new~issue(s,.FBExternalCashTest~approval(s,"STAFF-A"),.FederationBankExternalCashFixturePolicy~new)
.FBExternalCashTest~assertEq("SEPARATION_OF_DUTIES",r~code); say "PASS: maker cannot checker external cash shipment"
::requires "TestSupport.cls"

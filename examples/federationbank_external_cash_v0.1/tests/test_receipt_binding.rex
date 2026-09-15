s=.FBExternalCashTest~shipment("S3","INBOUND",10000); r=.FederationBankExternalCashReceipt~new("R1",s~semanticIdentity,"BRANCH","STAFF-C",s~sealId,.FBExternalCashTest~bundle(10000),"CUSTODY:R1")
.FBExternalCashTest~assertTrue(r~matchesShipment(s)); bad=.FederationBankExternalCashReceipt~new("R2",s~semanticIdentity,"BRANCH","STAFF-C",s~sealId,.FBExternalCashTest~bundle(9000),"CUSTODY:R2"); .FBExternalCashTest~assertTrue(\bad~matchesShipment(s)); say "PASS: receipt binds seal and counted amount"
::requires "TestSupport.cls"

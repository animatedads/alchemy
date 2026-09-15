root="/tmp/fbextcash-restart-"||random(10000,99999); address system "rm -rf '"root"'"
v=.FederationBankExternalCashMemoryVaultPort~new("IOM-DOUGLAS","VAULT-1","GBP",100000); store=.FederationBankExternalCashServiceStore~new(root); s=.FBExtServiceTest~service(v,store); sh=.FBExtServiceTest~shipment("RST1","INBOUND",15000); ignore=.FBExtServiceTest~submit(s,sh); ignore=.FBExtServiceTest~dispatch(s,sh); s2=.FBExtServiceTest~service(v,.FederationBankExternalCashServiceStore~new(root)); .FBExtServiceTest~assertEq("IN_TRANSIT",s2~work("RST1")~state); r=.FBExtServiceTest~receive(s2,sh); .FBExtServiceTest~assertEq("COMPLETED",r~code); say "PASS: in-transit external cash survives durable service restart"
::requires "TestSupport.cls"
::requires "FederationBankExternalCashServicePersistence.cls"

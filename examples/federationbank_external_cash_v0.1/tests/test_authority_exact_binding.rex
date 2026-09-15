s=.FBExternalCashTest~shipment("S1","INBOUND",10000); a=.FBExternalCashTest~authority(s); s2=.FBExternalCashTest~shipment("S1","INBOUND",11000)
.FBExternalCashTest~assertTrue(a~matchesShipment(s),"exact shipment must match"); .FBExternalCashTest~assertTrue(\a~matchesShipment(s2),"changed amount must not match")
say "PASS: external cash authority binds exact shipment"
::requires "TestSupport.cls"

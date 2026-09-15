mb=.MBRiskServiceTestSupport~fixture
-- A later FX observation means the old cross-currency sizing no longer nets the whole book.
mb~recordFXEvidence(.MBFXEvidence~new("FX-RS-DRIFT","FX-AUTH","GBP","EUR",1.10,"11:16","CURRENT"))
svc=.FederationBankMerchantRiskService~new(mb)
p=.MBRiskServiceTestSupport~payload("hedgeId","H-RS","policyRef","POL-RISK-SURV")
ignore=svc~handle(.MBRiskServiceEnvelope~new("C1","RISK.WATCH.REGISTER","OPS-1","MERCHANT_RISK_ADMIN",p,"09:03"))
notice=.MBRiskMarketStructureNotice~new("MSE-RS-DRIFT-SANC","JURISDICTIONAL_RESTRICTION","11:17","NL","SANCTIONS-AUTH","SANCTION-DRIFT","LEGAL-DRIFT","RES-RS-B",.true,.false,.false,.false,.false,"TRANSFER_RESTRICTED")
p2=.directory~new; p2["notice"]=notice
r=svc~handle(.MBRiskServiceEnvelope~new("C2","RISK.MARKET_STRUCTURE.INGEST","FEED-1","MARKET_STRUCTURE_FEED",p2,"11:17"))
.MBRiskServiceTestSupport~assertTrue(r~ok,"event ingested")
row=r~value[1]
.MBRiskServiceTestSupport~assertEq("DIRECTIONAL_RESIDUAL",row["bookState"],"whole book detects FX directional residual")
.MBRiskServiceTestSupport~assertTrue(row["netBaseExposure"]<>0,"non-zero aggregate exposure retained")
found=.false
work=svc~openWork
do w over work
  if w~workType="CFD_BOOK_DIRECTIONAL_RESIDUAL" then do
    found=.true
    .MBRiskServiceTestSupport~assertEq("TR-RS-A",w~rootTradeId,"book work carries root trade")
    .MBRiskServiceTestSupport~assertEq("DIRECTIONAL_RESIDUAL",w~bookState,"book work classifies residual")
    .MBRiskServiceTestSupport~assertTrue(w~netBaseExposure<>0,"book work carries non-zero exposure")
  end
end
.MBRiskServiceTestSupport~assertTrue(found,"directional residual work created")
say "PASS test_whole_book_directional_residual"
exit 0
::requires "TestSupport.cls"
::requires "FederationBankMerchantRiskService.cls"

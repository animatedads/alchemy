permit=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-LINE","POL-LINE")
mb=.FederationBankMerchantBank~new

iGbp=.MBInstrumentIdentity~new("SAME-EQ","ISIN-LINE-1","XLON","ORDINARY","GBP","GBP","GBP",1,"ISSUER","GBP","SEDOL-LINE-1","CRSTGB22")
iUsdContract=.MBInstrumentIdentity~new("SAME-EQ","ISIN-LINE-1","XLON","ORDINARY","GBP","GBP","USD",1,"ISSUER","GBP","SEDOL-LINE-1","CRSTGB22")
iOtherLine=.MBInstrumentIdentity~new("SAME-EQ","ISIN-LINE-1","XLON","ORDINARY","GBP","GBP","GBP",1,"ISSUER","USD","SEDOL-LINE-USD","CRSTGB22")

if \iGbp~sameSettlementLineIdentity(iUsdContract) then raise syntax 88.900 array("ASSERT_TRUE","same operational settlement line must be recognised")
if iGbp~exactContractIdentity(iUsdContract) then raise syntax 88.900 array("ASSERT_FALSE","different CFD contract currency is not exact contract identity")
if iGbp~sameSettlementLineIdentity(iOtherLine) then raise syntax 88.900 array("ASSERT_FALSE","different denomination/security line must not be same settlement line")

mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-LINE-GBP","1","CFD","SAME-EQ","GBP","CASH",permit,"","",1,iGbp))
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-LINE-USD","1","CFD","SAME-EQ","USD","CASH",permit,"","",1,iUsdContract))
mb~createPortfolio("PF-LINE-A","CLIENT-LINE","GBP")
mb~createPortfolio("PF-LINE-B","MM-LINE","USD")
mb~bookTrade(.MBDerivativeTrade~new("TR-LINE-A","PF-LINE-A","CLIENT-LINE","CFD","LONG","GBP",1000000,0,0,"",1,"LINE","CFD-LINE-GBP","SAME-EQ","09:00"))
mb~recordFXEvidence(.MBFXEvidence~new("FX-LINE","FX-AUTH","GBP","USD",1.25,"09:01","CURRENT"))
off=.MBDerivativeTrade~new("TR-LINE-B","PF-LINE-B","MM-LINE","CFD","SHORT","USD",1250000,0,0,"",1,"LINE","CFD-LINE-USD","SAME-EQ","09:01","MM-LINE","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INT-LINE","H-LINE","TR-LINE-A",off,"FX-LINE","TRADE-AUTH","09:01")
call assertEq "SETTLEMENT_LINE_HEDGE",h~relationshipType,"same settlement line but different derivative contract is explicit hedge class"
call assertEq "EQUIVALENCE_UNPROVED",h~equivalenceState,"settlement-line relationship does not become risk-free by identity alone"

say "PASS test_settlement_line_hedge_identity"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "FederationBankMerchantBank.cls"

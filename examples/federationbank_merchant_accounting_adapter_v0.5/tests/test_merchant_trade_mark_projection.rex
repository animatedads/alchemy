t=.MBAccountingTest~new
mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-PROJ","CLIENT-PROJ","GBP")
e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-PROJ","1","CFD","IDX-P","GBP","CASH",e))
trade=.MBDerivativeTrade~new("T-PROJ","PF-PROJ","CLIENT-PROJ","CFD","LONG","GBP",1000,0,0,"",1,"IDX-P","CFD-PROJ","IDX-P","08:00","CLIENT-PROJ","CLIENT")
mb~bookTrade(trade)
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-P1","MARKET-AUTH","IDX-P","08:10","GBP",100,"CURRENT"))
mark1=.MBTradeMark~new("MARK-P1","T-PROJ","08:10","GBP",100.25,10,1000,"MKT-P1")
mb~recordTradeMark(mark1)
val1=mb~createPortfolioValuation("VAL-P1","PF-PROJ","08:10")

scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP","2026-01-01")
projection=.FederationBankMerchantAccountingProjectionV1~new
p1=projection~projectTradeMarkTransition(mb,trade,mark1,val1,scale,"2026-08-28","2026-08")
t~assertEq(0,p1~previousMarketValueMinor,"opening carrying amount is explicit zero")
t~assertEq(10025,p1~currentMarketValueMinor,"Merchant amount converted exactly to minor units")
t~assertEq("T-PROJ",p1~economicRootTradeId,"ordinary client trade roots to itself")
t~assertEq("CLIENT_CONTRACT",p1~contractRole,"client contract role derived from Merchant contract")

adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
r1=adapter~postDerivativeFairValueTransition(p1)
t~assertEq("POSTED",r1~status,"projected Merchant mark transition posts")
t~assertEq(10025,adapter~book~balance("1300","GBP")~netDebitMinor,"first mark recognises derivative asset")
t~assertEq(-10025,adapter~book~balance("4100","GBP")~netDebitMinor,"first mark recognises fair-value gain")
t~assertEq("VAL-P1",r1~entry~lines[1]~dimensions["valuationRef"],"journal binds actual Merchant valuation")
t~assertEq("GBP-2DP",r1~entry~lines[1]~dimensions["scaleEvidenceRef"],"journal binds exact currency scale evidence")

mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-P2","MARKET-AUTH","IDX-P","08:20","GBP",110,"CURRENT"))
mark2=.MBTradeMark~new("MARK-P2","T-PROJ","08:20","GBP",125.50,20,1000,"MKT-P2")
mb~recordTradeMark(mark2)
val2=mb~createPortfolioValuation("VAL-P2","PF-PROJ","08:20")
p2=projection~projectTradeMarkTransition(mb,trade,mark2,val2,scale,"2026-08-28","2026-08",mark1)
r2=adapter~postDerivativeFairValueTransition(p2)
t~assertEq("POSTED",r2~status,"second Merchant mark transition posts")
t~assertEq(12550,adapter~book~balance("1300","GBP")~netDebitMinor,"book carrying amount equals latest Merchant mark")
t~assertEq(-12550,adapter~book~balance("4100","GBP")~netDebitMinor,"cumulative P&L equals exact mark transition")
t~assertEq("MARK-P1",r2~entry~lines[1]~dimensions["previousMarkRef"],"prior Merchant mark is explicit evidence")
t~assertEq("MARK-P2",r2~entry~lines[1]~dimensions["currentMarkRef"],"current Merchant mark is explicit evidence")

say "merchant projection assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingProjection.cls"
::requires "TestSupport.cls"

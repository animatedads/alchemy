t=.MBAccountingTest~new
mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-X","CLIENT-X","GBP")
e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-X","1","CFD","IDX-X","GBP","CASH",e))
trade=.MBDerivativeTrade~new("T-X","PF-X","CLIENT-X","CFD","LONG","GBP",1000,0,0,"",1,"IDX-X","CFD-X","IDX-X","08:00","CLIENT-X","CLIENT")
mb~bookTrade(trade)
scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
projection=.FederationBankMerchantAccountingProjectionV1~new
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")

mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-X1","MARKET-AUTH","IDX-X","08:10","GBP",100,"CURRENT"))
m1=.MBTradeMark~new("MARK-X1","T-X","08:10","GBP",100,0,1000,"MKT-X1")
mb~recordTradeMark(m1)
v1=mb~createPortfolioValuation("VAL-X1","PF-X","08:10")
r1=adapter~postDerivativeFairValueTransition(projection~projectTradeMarkTransition(mb,trade,m1,v1,scale,"2026-08-28","2026-08"))
t~assertEq("POSTED",r1~status,"initial asset mark posts")

mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-X2","MARKET-AUTH","IDX-X","08:20","GBP",90,"CURRENT"))
m2=.MBTradeMark~new("MARK-X2","T-X","08:20","GBP",-50,0,1000,"MKT-X2")
mb~recordTradeMark(m2)
v2=mb~createPortfolioValuation("VAL-X2","PF-X","08:20")
r2=adapter~postDerivativeFairValueTransition(projection~projectTradeMarkTransition(mb,trade,m2,v2,scale,"2026-08-28","2026-08",m1))
t~assertEq("POSTED",r2~status,"asset-to-liability crossing posts atomically")
t~assertEq(3,r2~entry~lines~items,"crossing journal derecognises asset, recognises liability and records P&L")
t~assertEq(0,adapter~book~balance("1300","GBP")~netDebitMinor,"old derivative asset fully derecognised")
t~assertEq(-5000,adapter~book~balance("2300","GBP")~netDebitMinor,"new derivative liability recognised")
t~assertEq(-10000,adapter~book~balance("4100","GBP")~netDebitMinor,"prior gain remains historical")
t~assertEq(15000,adapter~book~balance("5100","GBP")~netDebitMinor,"crossing records exact 150 loss movement")
t~assertEq(5000,adapter~book~balance("4100","GBP")~netDebitMinor + adapter~book~balance("5100","GBP")~netDebitMinor,"net P&L is 50 loss, matching current -50 carrying value from zero origin")

say "sign crossing assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingProjection.cls"
::requires "TestSupport.cls"

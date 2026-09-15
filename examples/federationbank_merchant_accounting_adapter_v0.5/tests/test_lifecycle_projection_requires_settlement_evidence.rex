t=.MBAccountingTest~new
mb=.FederationBankMerchantBank~new
mb~createPortfolio("PF-L","CLIENT-L","GBP")
e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
mb~registerProduct(.MBDerivativeProductDefinition~new("OPT-L","1","OPTION","EQ-L","GBP","CASH",e,"CALL","EUROPEAN",100))
trade=.MBDerivativeTrade~new("OPT-T","PF-L","CLIENT-L","OPTION","LONG","GBP",500,100,25,"20261231",1,"EQ-L","OPT-L","EQ-L","08:00","CLIENT-L","CLIENT")
mb~bookTrade(trade)
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-L","MARKET-AUTH","EQ-L","09:00","GBP",125,"CURRENT"))
evt=mb~closeTrade("EVT-L","OPT-T","EXERCISED","09:01",84.25,"MKT-L","MB-LIFECYCLE-AUTH")
scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
obs=.FederationBankMerchantAccountingProjectionV1~new~projectTradeLifecycleObservation(mb,trade,evt,scale,"2026-08-28","2026-08")
t~assertEq("EXERCISED",obs~eventType,"actual Merchant lifecycle event projected")
t~assertEq(8425,obs~realisedPnLMinor,"realised P&L is converted exactly but remains observation")
t~assertEq("SETTLEMENT_EVIDENCE_REQUIRED",obs~postingState,"lifecycle event is not settlement authority")
t~assertEq("MB-LIFECYCLE-AUTH",obs~authorityRef,"Merchant lifecycle authority retained")

adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
r=adapter~postTradeLifecycleObservation(obs)
t~assertEq("REJECTED",r~status,"lifecycle-only posting is rejected")
t~assertEq("SETTLEMENT_EVIDENCE_REQUIRED",r~errorCode,"cash/settlement cannot be fabricated from lifecycle state")
t~assertEq(0,adapter~book~entryCount,"no journal created from lifecycle report alone")

say "lifecycle gate assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingProjection.cls"
::requires "TestSupport.cls"

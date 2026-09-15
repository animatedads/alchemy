t=.MBAccountingTest~new
mb=.FederationBankMerchantBank~new
e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL","POLICY")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-C","1","CFD","IDX-C","GBP","CASH",e))
mb~createPortfolio("PF-C","CLIENT-C","GBP")
mb~createPortfolio("PF-H","MM-C","GBP")
orig=.MBDerivativeTrade~new("CFD-ORIG","PF-C","CLIENT-C","CFD","SHORT","GBP",1000,0,0,"",1,"IDX-C","CFD-C","IDX-C","09:00","CLIENT-C","CLIENT")
mb~bookTrade(orig)
offset=.MBDerivativeTrade~new("CFD-REV","PF-H","MM-C","CFD","LONG","GBP",1000,0,0,"",1,"IDX-C","CFD-C","IDX-C","09:01","MM-C","EXTERNAL_HEDGE")
mb~bookCFDOffset("CLOSE-INTENT-C","HEDGE-C","CFD-ORIG",offset,"","MB-AUTH","09:01")
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-C","MARKET-AUTH","IDX-C","09:10","GBP",100,"CURRENT"))
mark=.MBTradeMark~new("MARK-C","CFD-REV","09:10","GBP",-100,0,1000,"MKT-C")
mb~recordTradeMark(mark)
val=mb~createPortfolioValuation("VAL-C","PF-H","09:10")
scale=.MBAccountingCurrencyScaleEvidence~new("GBP-2DP","GBP",100,"ACCOUNTING-POLICY","ISO4217:GBP")
p=.FederationBankMerchantAccountingProjectionV1~new~projectTradeMarkTransition(mb,offset,mark,val,scale,"2026-08-28","2026-08")
t~assertEq("REVERSING_CONTRACT",p~contractRole,"Merchant hedge graph identifies close-intent reversing contract")
t~assertEq("CFD-ORIG",p~economicRootTradeId,"reversing contract retains original CFD economic root")
t~assertEq("CLOSE-INTENT-C",p~closeIntentRef,"actual Merchant close intent becomes evidence only")

adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
r=adapter~postDerivativeFairValueTransition(p)
t~assertEq("POSTED",r~status,"reversing contract transition posts")
t~assertEq("",r~entry~reversalOf,"customer close never becomes AccountingBook reversal")
t~assertEq("CFD-ORIG",r~entry~correlationRef,"journal correlation preserves customer-root graph")
t~assertEq("CLOSE-INTENT-C",r~entry~lines[1]~dimensions["closeIntentRef"],"close intent retained on accounting evidence")

say "CFD projection identity assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingProjection.cls"
::requires "TestSupport.cls"

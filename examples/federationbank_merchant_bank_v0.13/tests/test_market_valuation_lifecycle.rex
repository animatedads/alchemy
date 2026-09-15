e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-PROD","POLICY-PROD")
mb=.FederationBankMerchantBank~new
mb~registerRelationship(.MBMerchantRelationship~new("MBR-200","CLIENT-200","RETAIL-LINK-200","LINK-AUTH-200"))
mb~createPortfolio("PF-200","CLIENT-200","GBP","MBR-200")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-A","1","CFD","IDX-A","GBP","CASH",e))
mb~registerProduct(.MBDerivativeProductDefinition~new("OPT-B","1","OPTION","EQ-B","GBP","CASH",e,"CALL","EUROPEAN",100))
mb~bookTrade(.MBDerivativeTrade~new("T-A","PF-200","CLIENT-200","CFD","LONG","GBP",1000000,0,0,"",1,"IDX-A","CFD-A","IDX-A","08:01"))
mb~bookTrade(.MBDerivativeTrade~new("T-B","PF-200","CLIENT-200","OPTION","LONG","GBP",500000,10000,25000,"20261231",10,"EQ-B","OPT-B","EQ-B","08:02"))
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-A","MARKET-DATA-AUTH","IDX-A","08:10","GBP",812345,"CURRENT"))
mb~recordMarketEvidence(.MBMarketEvidence~new("MKT-B","MARKET-DATA-AUTH","EQ-B","08:10","GBP",12345,"CURRENT"))
mb~recordTradeMark(.MBTradeMark~new("MARK-A","T-A","08:10","GBP",400000,120000,1000000,"MKT-A"))
mb~recordTradeMark(.MBTradeMark~new("MARK-B","T-B","08:10","GBP",300000,50000,500000,"MKT-B"))
v=mb~createPortfolioValuation("VAL-200","PF-200","08:10")
call assertEq 700000,v~marketValue,"aggregate market value"
call assertEq 170000,v~unrealisedPnL,"aggregate unrealised pnl"
call assertEq 1500000,v~grossExposure,"aggregate exposure"
call assertEq 2,v~positionCount,"two open positions"
call assertEq "CURRENT",v~valuationStatus,"market evidence status propagated"

evt=mb~closeTrade("EVT-B","T-B","EXERCISED","09:00",84000,"MKT-B","MB-TRADE-AUTH-1")
call assertEq "EXERCISED",evt~eventType,"option exercise recorded"
call assertEq "CLOSED",mb~portfolio("PF-200")~trade("T-B")~status,"option closed"
call expectLifecycle mb,"EVT-X","T-A","EXERCISED","09:01",0,"MKT-A","MB-TRADE-AUTH-X","CFD cannot be option-exercised"

-- Revalue after lifecycle close: only the still-open CFD contributes.
v2=mb~createPortfolioValuation("VAL-201","PF-200","09:02")
call assertEq 400000,v2~marketValue,"closed option excluded from live position value"
call assertEq 84000,v2~realisedPnL,"realised pnl retained separately"
call assertEq 1,v2~positionCount,"one open position"

say "PASS test_market_valuation_lifecycle"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectLifecycle
  use strict arg mb,eventId,tradeId,eventType,effectiveAt,pnl,evidence,auth,label
  caught=.false
  signal on syntax name got
  mb~closeTrade(eventId,tradeId,eventType,effectiveAt,pnl,evidence,auth)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
got:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"

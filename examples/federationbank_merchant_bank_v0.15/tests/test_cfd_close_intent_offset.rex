e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-PROD","POL-PROD")
mb=.FederationBankMerchantBank~new
id=.MBInstrumentIdentity~new("SHELL-EQ","GB00BP6MXD84","XLON","ORDINARY","GBP","GBP","GBP",1,"SHELL-PLC")
mb~registerProduct(.MBDerivativeProductDefinition~new("CFD-SHEL-LON","1","CFD","SHELL-EQ","GBP","CASH",e,"","",1,id))
p=mb~createPortfolio("PF-CFD","CLIENT-CFD","GBP")
hp=mb~createPortfolio("PF-HEDGE","MM-1","GBP")
orig=.MBDerivativeTrade~new("CFD-ORIG","PF-CFD","CLIENT-CFD","CFD","SHORT","GBP",1000000,0,0,"",1,"SHEL","CFD-SHEL-LON","SHELL-EQ","09:00","CLIENT-CFD","CLIENT")
mb~bookTrade(orig)
off=.MBDerivativeTrade~new("CFD-OFF","PF-HEDGE","MM-1","CFD","LONG","GBP",1000000,0,0,"",1,"SHEL","CFD-SHEL-LON","SHELL-EQ","09:01","MM-1","EXTERNAL_HEDGE")
h=mb~bookCFDOffset("INTENT-1","HEDGE-1","CFD-ORIG",off,"","MB-TRADING-AUTH","09:01")
call assertEq "EXACT_OFFSET",h~relationshipType,"same contract/listing is exact offset"
call assertEq "NET_ZERO",h~economicState,"sizing produces net zero"
call assertEq "OPEN",orig~status,"CFD legal contract remains open"
call assertEq "ACTIVE",orig~contractState,"CFD promise remains active"
call assertEq "CLOSED",orig~clientViewState,"front end may display closed"
call assertEq "OPEN",off~status,"reversing CFD is also a live contract"
a=mb~assessHedgeRisk("HRA-1","HEDGE-1","","","","","09:02")
call assertEq "NET_ZERO_MARKET_RISK_WITH_MONITORING",a~riskState,"market risk net zero but still monitored"
call assertEq 1,a~monitoringRequired,"monitoring retained"
call expectSyntaxTradeClose orig,"CFD cannot be legally closed by state flip"
say "PASS test_cfd_close_intent_offset"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntaxTradeClose
  use strict arg trade,label
  caught=.false
  signal on syntax name gotSyntax
  trade~close
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"

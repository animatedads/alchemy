mb=.FederationBankMerchantBank~new
p=mb~createPortfolio("PF-WRONG","CLIENT-WRONG","GBP")
hp=mb~createPortfolio("PF-WRONG-H","MM-WRONG","GBP")
orig=.MBDerivativeTrade~new("TR-WRONG","PF-WRONG","CLIENT-WRONG","CFD","SHORT","GBP",1000000,0,0,"",1,"ABC","","ABC","09:00")
mb~bookTrade(orig)
wrong=.MBDerivativeTrade~new("TR-WRONG-OFF","PF-WRONG-H","MM-WRONG","CFD","SHORT","GBP",1000000,0,0,"",1,"ABC","","ABC","09:01","MM-WRONG","EXTERNAL_HEDGE")
call expectSyntax mb,"BOOKCFDOFFSET",.array~of("INT-W","H-W","TR-WRONG",wrong,"","MB-TRADE-AUTH","09:01"),"wrong-way close must not double short"
call assertEq "OPEN",orig~clientViewState,"failed close intent leaves client position open"
call assertEq 0,hp~tradeCount,"wrong-way reversing trade not booked"
say "PASS test_cfd_wrong_way_close"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine expectSyntax
  use strict arg target,method,args,label
  caught=.false
  signal on syntax name gotSyntax
  target~sendWith(method,args)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
gotSyntax:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"

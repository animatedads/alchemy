i=.FBTellerCashDomainTestSupport~instruction("DTRANS","DEPOSIT",17500)
c=.FBTellerCashDomainTestSupport~command("DTRANS","DEPOSIT",17500,.true)
r=.FederationBankTellerCashCoreTranslator~translate(i,c)
.FBTellerCashDomainTestSupport~assertTrue(r~ok)
x=r~value
.FBTellerCashDomainTestSupport~assertEq("TRANSFER",x~operation)
.FBTellerCashDomainTestSupport~assertEq("FB-SETTLEMENT-GBP",x~sourceAccountId)
.FBTellerCashDomainTestSupport~assertEq("GBP-SRC",x~targetAccountId)
.FBTellerCashDomainTestSupport~assertEq("DEPOSIT",x~detail("tellerCashOperation"))
.FBTellerCashDomainTestSupport~pass("deposit translates internal settlement debit to customer credit without claiming cash receipt")
::requires "TestSupport.cls"

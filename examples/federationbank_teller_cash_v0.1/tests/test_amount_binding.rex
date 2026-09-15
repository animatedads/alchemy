i=.FBTellerCashDomainTestSupport~instruction("AMT","WITHDRAWAL",10000)
c=.FBTellerCashDomainTestSupport~command("AMT","WITHDRAWAL",11000,.true)
r=.FederationBankTellerCashCoreTranslator~translate(i,c)
.FBTellerCashDomainTestSupport~assertFalse(r~ok)
.FBTellerCashDomainTestSupport~assertEq("CASH_COUNT_AMOUNT_MISMATCH",r~code)
.FBTellerCashDomainTestSupport~pass("counted physical bundle must equal authorised banking amount")
::requires "TestSupport.cls"

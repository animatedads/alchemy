i=.FBTellerCashDomainTestSupport~instruction("WTRANS","WITHDRAWAL",12500)
c=.FBTellerCashDomainTestSupport~command("WTRANS","WITHDRAWAL",12500,.true)
r=.FederationBankTellerCashCoreTranslator~translate(i,c)
.FBTellerCashDomainTestSupport~assertTrue(r~ok)
x=r~value
.FBTellerCashDomainTestSupport~assertEq("TRANSFER",x~operation)
.FBTellerCashDomainTestSupport~assertEq("GBP-SRC",x~sourceAccountId)
.FBTellerCashDomainTestSupport~assertEq("FB-SETTLEMENT-GBP",x~targetAccountId)
.FBTellerCashDomainTestSupport~assertEq("WITHDRAWAL",x~detail("tellerCashOperation"))
.FBTellerCashDomainTestSupport~assertEq(i~semanticIdentity,x~detail("tellerCashInstructionIdentity"))
.FBTellerCashDomainTestSupport~pass("withdrawal translates customer debit to internal settlement without claiming physical release")
::requires "TestSupport.cls"

i=.FBTellerCashDomainTestSupport~instruction("NOAUTH")
c=.FBTellerCashDomainTestSupport~command("NOAUTH","WITHDRAWAL",10000,.false)
r=.FederationBankTellerCashCoreTranslator~translate(i,c)
.FBTellerCashDomainTestSupport~assertFalse(r~ok,"translation must reject missing staff authority")
.FBTellerCashDomainTestSupport~assertEq("STAFF_AUTHORITY_EVIDENCE_REQUIRED",r~code)
.FBTellerCashDomainTestSupport~pass("cash-to-Core translation requires exact Staff Authority evidence")
::requires "TestSupport.cls"

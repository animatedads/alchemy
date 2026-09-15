t=.MBAccountingTest~new
fx=.MBSettlementAccountingFixture~closeOut(1000,"CLIENT-REC","REC")
mb=fx["mb"]; o=fx["obligation"]; scale=fx["scale"]
p=.FederationBankMerchantAccountingProjectionV1~new~projectSettlementObligation(mb,o,scale,"2026-08-28","2026-08")
t~assertEq("RECEIVABLE",p~settlementSide,"positive Merchant settlement is receivable")
t~assertEq(100000,p~amountMinor,"obligation scales exactly to minor units")
t~assertEq("EXEC-SET-REC",p~executionId,"projection binds actual close-out execution")

a=.FederationBankMerchantAccountingAdapter~new
a~addPeriod("2026-08","2026-08-01","2026-08-31")
r=a~postSettlementObligation(p)
t~assertEq("POSTED",r~status,"attributable settlement obligation posts")
t~assertEq("1315",r~entry~lines[1]~accountId,"receivable account recognised")
t~assertEq("2395",r~entry~lines[2]~accountId,"derivative derecognition remains in explicit control")
t~assertEq(100000,a~book~balance("1315","GBP")~netDebitMinor,"receivable balance is exact")
t~assertEq(-100000,a~book~balance("2395","GBP")~netDebitMinor,"control liability remains explicit")
t~assertEq(0,a~book~balance("1105","GBP")~netDebitMinor,"obligation does not fabricate cash")

say "settlement obligation recognition assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0
::requires "SettlementAccountingFixture.cls"
::requires "TestSupport.cls"

t=.MBAccountingTest~new
adapter=.FederationBankMerchantAccountingAdapter~new
adapter~addPeriod("2026-08","2026-08-01","2026-08-31")
refs=.array~of("MB-VALUATION-EVIDENCE-ORIG")
orig=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EV-ORIG","FEDERATIONBANK_MERCHANT_BANK","MB:FV:T0:1","2026-08-28","2026-08","T0","PF-C","T0","GBP",10000,"ASSET","INCREASE","MERCHANT_VALUATION","","CLIENT-CPTY","CLIENT_CONTRACT",refs)
r1=adapter~postDerivativeFairValueMovement(orig)
t~assertEq("POSTED",r1~status,"original CFD accounting consequence posts")

revrefs=.array~of("MB-VALUATION-EVIDENCE-REV")
rev=.MBAccountingDerivativeFairValueMovementEvidence~new("ACC-EV-REV","FEDERATIONBANK_MERCHANT_BANK","MB:FV:T1:1","2026-08-28","2026-08","T1","PF-C-H","T0","GBP",10000,"LIABILITY","INCREASE","MERCHANT_VALUATION","CLOSE-INTENT-1","MM-1","REVERSING_CONTRACT",revrefs)
r2=adapter~postDerivativeFairValueMovement(rev)
t~assertEq("POSTED",r2~status,"reversing CFD accounting consequence posts independently")
t~assertEq(2,adapter~book~entryCount,"original and reversing contracts both remain posted")
t~assertEq("",r1~entry~reversalOf,"original contract journal is not reversed")
t~assertEq("",r2~entry~reversalOf,"reversing CFD is not an accounting reversal of original")
t~assertEq("T0",r2~entry~correlationRef,"reversing contract retains customer-root economic root")
t~assertEq("CLOSE-INTENT-1",r2~entry~lines[1]~dimensions["closeIntentRef"],"close intent retained as evidence only")
t~assertEq("REVERSING_CONTRACT",r2~entry~lines[1]~dimensions["contractRole"],"reversing contract role explicit")
t~assertEq(10000,adapter~book~balance("1300","GBP")~netDebitMinor,"original derivative asset remains gross")
t~assertEq(-10000,adapter~book~balance("2300","GBP")~netDebitMinor,"reversing derivative liability remains gross")
t~assertEq(0,adapter~book~balance("4100","GBP")~netDebitMinor + adapter~book~balance("5100","GBP")~netDebitMinor,"net P&L may be zero without collapsing gross contracts")

say "cfd close accounting assertions=" t~assertions "failures=" t~failures
if t~failures>0 then exit 1
exit 0

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "TestSupport.cls"

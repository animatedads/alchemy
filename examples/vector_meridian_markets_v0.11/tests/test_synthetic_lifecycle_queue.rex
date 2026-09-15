v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
x~setLifecyclePolicy(.VMMSyntheticLifecyclePolicy~new("LIFE-JPY","JPY",5,10,80,"POL-LIFE-JPY"),"VMM-RISK")
p1=.VMMPortfolioReferencePosition~new("P-A","AJI","JGB-A","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000000,"ALL_JAPAN_INSURANCE","","BOOK-A","","VAL-A")
s1=.VMMPortfolioSnapshot~new("SNAP-LIFE-A","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p1),"AJI-POSITIONS-A","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s1)
p2=.VMMPortfolioReferencePosition~new("P-B","AJI","JGB-B","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10100000000,"ALL_JAPAN_INSURANCE","","BOOK-B","","VAL-B")
s2=.VMMPortfolioSnapshot~new("SNAP-LIFE-B","AJI","ALL_JAPAN_INSURANCE","JPY","20260930",.array~of(p2),"AJI-POSITIONS-B","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s2)
x~createOffer("OFF-LIFE","REQ-LIFE","AJI","SNAP-LIFE-A","JPY",10000000000,5,25,120000000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-LIFE","MKT-LIFE","RISK-LIFE")
x~acceptOffer("CON-LIFE","OFF-LIFE","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
pp=.VMMSyntheticPremiumPeriod~new("PREM-LIFE-1","JPY","20260901","20260930","20261005",120000000,"SCHED-LIFE")
x~setPremiumSchedule("CON-LIFE",.array~of(pp),"VMM-OTC-OPS")
x~recordPremiumAccrual("ACCR-LIFE","CON-LIFE","PREM-LIFE-1",30,30,"20260930","ACCR-EVID-LIFE","VMM-FINANCE")
root="./tmp_queue_synthetic_lifecycle_"||.DateTime~new~microseconds
q=.VMMInstitutionalLifecycleQueueService~new(x,root,"ALL_JAPAN_INSURANCE_LIFECYCLE_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
client=.VMMInstitutionalLifecycleQueueClient~new(q~manager,"ALL_JAPAN_INSURANCE_LIFECYCLE_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
pay=.VMMInstitutionalPremiumPaymentNotice~new("PAY-1","IDEMP-PAY-1","CORR-PAY-1","CON-LIFE","PREM-LIFE-1","AJI","ALL_JAPAN_INSURANCE","AJI-TREASURY","JPY",120000000,"BANK-PAYMENT-EVIDENCE","20261005T090000")
call assertTrue client~submitInstruction(pay)~ok,"premium payment notice queued"
call assertTrue q~processNextInstruction("20261005T091000")~ok,"VMM records premium payment from queue"
r=client~receiveResult; call assertTrue r~ok,"premium lifecycle result returned"
call assertEq "PREMIUM_PAYMENT",r~value~actionType,"premium result action type"
call assertNear 120000000,x~premiumSettled("CON-LIFE"),0.01,"queued payment becomes VMM settlement truth"
chg=.VMMInstitutionalReferenceChangeRequest~new("REF-1","IDEMP-REF-1","CORR-REF-1","CON-LIFE","SNAP-LIFE-B","CLIENT_SUBSTITUTION","AJI","ALL_JAPAN_INSURANCE","AJI-PORTFOLIO-CONTROL","20260930","AJI-SUBSTITUTION-EVID")
call assertTrue client~submitInstruction(chg)~ok,"reference change request queued"
call assertTrue q~processNextInstruction("20260930T161000","VMM-RISK-APPROVAL","VMM-OTC-CONTROL")~ok,"VMM approves and records queued substitution"
r2=client~receiveResult; call assertTrue r2~ok,"reference change lifecycle result returned"
call assertEq "REFERENCE_CHANGE",r2~value~actionType,"reference result action type"
call assertEq "SNAP-LIFE-B",x~contract("CON-LIFE")~currentSnapshotId,"queue substitution advances immutable reference snapshot"
/* Federation principal has no lifecycle queue ACL. */
blocked=q~manager~put(.VMMInstitutionalLifecycleQueueBuild~instructionQueue,pay,.nil,"FEDERATIONBANK_MERCHANT_VMM_GATEWAY")
call assertTrue \blocked~ok,"Federation cannot inject institutional lifecycle messages"
call assertTrue \client~hasMethod("vmm"),"institutional lifecycle client has no VMM engine accessor"
call assertTrue \client~hasMethod("productService"),"institutional lifecycle client has no product service accessor"
say "PASS test_synthetic_lifecycle_queue"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertNear
  use strict arg expected,actual,tolerance,label
  if abs(expected-actual)>tolerance then raise syntax 88.900 array("ASSERT_NEAR",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VectorMeridianInstitutionalLifecycleQueue.cls"

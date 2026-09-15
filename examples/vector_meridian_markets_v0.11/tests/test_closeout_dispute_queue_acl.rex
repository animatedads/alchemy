v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
cp=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(cp)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("RISK-JPY","JPY",100000000000,50000000000,100,"RISK-POL"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-Q09","AJI","JGB-Q09","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-Q09","","VAL-Q09")
s=.VMMPortfolioSnapshot~new("SNAP-Q09","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"POS-Q09","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-Q09","REQ-Q09","AJI","SNAP-Q09","JPY",10000000,5,25,100000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-Q09","MKT-Q09","RISK-Q09")
k=x~acceptOffer("CON-Q09","OFF-Q09","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-JPY","JPY",2,1,3,"ISDA-CLOSEOUT","DEF-POL"),"VMM-LEGAL")
ops=.VMMCloseoutOperationsService~new(d)
ops~setPolicy(.VMMCloseoutOperationsPolicy~new("OPS-JPY","JPY",2,3,"INDEPENDENT-VALUATION-AGENT","LEGAL-NETTING-OPINION-POLICY","OPS-POL"),"VMM-LEGAL")
ev=d~declareDefault("DEF-Q09",k~contractId,"INSOLVENCY","ALL_JAPAN_INSURANCE","2026-10-06","2026-10-06","INSOLVENCY-Q09","VMM-LEGAL")
d~assessUncured("UNCURED-Q09",ev~eventId,"2026-10-07","UNCURED-Q09","VMM-LEGAL")
t=d~electTermination("TERM-Q09",ev~eventId,"VECTOR_MERIDIAN_MARKETS_LTD","2026-10-07","TERM-Q09","ORIGINAL-VALUATION-AGENT","VMM-LEGAL")
co=d~determineCloseout("CLOSE-Q09",t~terminationId,2000000,"2026-10-10","ISDA-METHOD","MKT-Q09","CSA-Q09","VMM-VALUATION")
root="./tmp_queue_closeout_v09_"||.DateTime~new~microseconds
q=.VMMInstitutionalCloseoutQueueService~new(ops,root,"ALL_JAPAN_INSURANCE_CLOSEOUT_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
client=.VMMInstitutionalCloseoutQueueClient~new(q~manager,"ALL_JAPAN_INSURANCE_CLOSEOUT_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
msg=.VMMInstitutionalCloseoutDisputeInstruction~new("REQ-DISP-Q09","IDEMP-DISP-Q09","CORR-DISP-Q09","DISP-Q09",co~closeoutId,k~contractId,"AJI","ALL_JAPAN_INSURANCE","AJI-LEGAL",1400000,"2026-10-11","AJI-DISPUTE-EVID-Q09")
blocked=q~manager~put(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,msg,.nil,"FEDERATIONBANK_MERCHANT_VMM_GATEWAY")
call assertTrue \blocked~ok,"Federation principal has no ACL on bilateral close-out dispute queue"
call assertTrue client~submitDispute(msg)~ok,"institutional client queues valuation dispute"
processed=q~processNextInstruction("2026-10-11")
call assertTrue processed~ok,"VMM consumes client dispute through Queue Fabric"
r=client~receiveResult
call assertTrue r~ok,"client receives dispute result"
call assertEq "DISPUTE_OPEN",r~value~status,"result records open valuation dispute"
call assertEq "DISP-Q09",r~value~referenceId,"result identifies exact dispute object"
ops~resolveDispute("RES-Q09","DISP-Q09",1600000,"2026-10-12","INDEPENDENT-VALUATION-AGENT","METHOD-FALLBACK-Q09","MKT-FALLBACK-Q09","VMM-LEGAL")
f=ops~finalizeCloseout("FINAL-Q09",co~closeoutId,"2026-10-12","VMM-LEGAL")
call assertTrue q~publishFinalization(f~finalizationId,"2026-10-12")~ok,"VMM publishes immutable finalization notice"
n=client~receiveNotice
call assertTrue n~ok,"institutional client receives finalization notice"
call assertEq "FINAL-Q09",n~value~finalizationId,"notice identifies exact finalization"
call assertEq "DISPUTE_RESOLUTION",n~value~basis,"notice states why final amount supersedes original determination"
call assertEq 1600000,n~value~netAmountToVMM,"notice carries finalized signed amount from VMM perspective"
call assertTrue \client~hasMethod("operationsService"),"client gateway has no VMM close-out operations service reference"
call assertTrue \client~hasMethod("vmm"),"client gateway has no VMM engine reference"
say "PASS test_closeout_dispute_queue_acl"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VectorMeridianInstitutionalCloseoutQueue.cls"

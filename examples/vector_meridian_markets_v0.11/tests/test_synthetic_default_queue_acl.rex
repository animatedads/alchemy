v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
x~setRiskPolicy(.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,100,"POL-SYN-JPY"),"VMM-RISK")
p=.VMMPortfolioReferencePosition~new("P-DEF-Q","AJI","JGB-Q","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",10000000,"ALL_JAPAN_INSURANCE","","BOOK-Q","","VAL-Q")
s=.VMMPortfolioSnapshot~new("SNAP-DEF-Q","AJI","ALL_JAPAN_INSURANCE","JPY","20260828",.array~of(p),"AJI-POSITIONS-Q","","VMM-PORTFOLIO")
x~registerPortfolioSnapshot(s)
x~createOffer("OFF-DEF-Q","REQ-DEF-Q","AJI","SNAP-DEF-Q","JPY",10000000,5,25,120000,"20260901","20310831","20260828T140000","20260828T132100","MODEL-Q","MKT-Q","RISK-Q")
k=x~acceptOffer("CON-DEF-Q","OFF-DEF-Q","20260828T132200","ALL_JAPAN_INSURANCE","AJI-SIGNER")
d=.VMMInstitutionalDefaultCloseoutService~new(x)
d~setPolicy(.VMMSyntheticDefaultPolicy~new("DEF-POL-Q","JPY",2,1,3,"ISDA-2002-CLOSEOUT-AMOUNT","POL-DEFAULT-Q"),"VMM-LEGAL")
/* VMM itself defaults, so All Japan is the non-defaulting termination elector. */
ev=d~declareDefault("DEF-Q-1",k~contractId,"REPUDIATION","VECTOR_MERIDIAN_MARKETS_LTD","2026-10-01","2026-10-01","VMM-REPUDIATION-EVID","VMM-LEGAL")
d~assessUncured("UNCURED-Q-1",ev~eventId,"2026-10-05","CURE-EXPIRED-Q","VMM-LEGAL")
root="./tmp_queue_synthetic_default_"||.DateTime~new~microseconds
q=.VMMInstitutionalDefaultQueueService~new(d,root,"ALL_JAPAN_INSURANCE_DEFAULT_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
client=.VMMInstitutionalDefaultQueueClient~new(q~manager,"ALL_JAPAN_INSURANCE_DEFAULT_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
call assertTrue q~publishDefaultNotice(ev~eventId,"2026-10-05")~ok,"VMM publishes bilateral default notice"
n=client~receiveNotice; call assertTrue n~ok,"institutional client receives default notice"
call assertEq "DEF-Q-1",n~value~eventId,"notice identifies exact default event"
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",n~value~defaultingEntity,"notice identifies VMM as defaulting party"
/* Federation has no default-lifecycle ACL and cannot inject a termination election. */
term=.VMMInstitutionalTerminationElectionInstruction~new("REQ-TERM-Q","IDEMP-TERM-Q","CORR-TERM-Q",ev~eventId,"TERM-Q-1",k~contractId,"AJI","ALL_JAPAN_INSURANCE","AJI-LEGAL","2026-10-05","AJI-TERMINATION-NOTICE","AJI-VALUATION-AGENT")
blocked=q~manager~put(.VMMInstitutionalDefaultQueueBuild~instructionQueue,term,.nil,"FEDERATIONBANK_MERCHANT_VMM_GATEWAY")
call assertTrue \blocked~ok,"Federation cannot inject institutional default instructions"
call assertTrue client~submitInstruction(term)~ok,"non-defaulting institutional client queues termination election"
processed=q~processNextInstruction("2026-10-05"); call assertTrue processed~ok,"VMM processes bilateral termination election"
r=client~receiveResult; call assertTrue r~ok,"termination result returned"
call assertEq "TERMINATION_ELECTION",r~value~actionType,"result identifies termination election"
call assertEq "TERMINATED",r~value~status,"result reports terminated contract"
call assertEq "TERMINATED",k~state,"queue election changes contract only through VMM default service"
call assertTrue \client~hasMethod("vmm"),"default client has no VMM engine accessor"
call assertTrue \client~hasMethod("defaultService"),"default client has no default service accessor"
say "PASS test_synthetic_default_queue_acl"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VectorMeridianInstitutionalDefaultQueue.cls"

mb=.FederationBankMerchantBank~new
mb~registerRelationship(.MBMerchantRelationship~new("REL-CLOSED","CLIENT-CLOSED","RETAIL-CLOSED","LINK-AUTH"))
p=mb~createPortfolio("PF-CLOSED","CLIENT-CLOSED","GBP","REL-CLOSED")
hp=mb~createPortfolio("PF-CLOSED-H","MM-CLOSED","GBP")
mb~bookTrade(.MBDerivativeTrade~new("TR-CLOSED","PF-CLOSED","CLIENT-CLOSED","CFD","LONG","GBP",1000000,0,0,"",1,"IDX-C","","IDX-C","08:00"))
off=.MBDerivativeTrade~new("TR-CLOSED-H","PF-CLOSED-H","MM-CLOSED","CFD","SHORT","GBP",1000000,0,0,"",1,"IDX-C","","IDX-C","08:01","MM-CLOSED","EXTERNAL_HEDGE")
mb~bookCFDOffset("INT-CLOSED","H-CLOSED","TR-CLOSED",off,"","MB-TRADE-AUTH","08:01")
v=.MBValuationSnapshot~new("V-CLOSED","PF-CLOSED","08:02","GBP",0,0,1000000,"MKTSET-C",0,"CURRENT",1,0)
mb~recordValuation(v)
mb~assessMargin("A-CLOSED","PF-CLOSED",v,.MBRiskPolicy~new("P-CLOSED",6,0,3600),0,"08:02")
resolver=.FixtureLinkageResolver~new("S-CLOSED","C-CLOSED","ATM-IOM-001","REL-CLOSED")
svc=.MBPositionEnquiryService~new(mb,resolver)
req=.directory~new
req["schema"]=.MBPositionServiceBuild~REQUEST_SCHEMA
req["commandId"]="CMD-CLOSED"
req["operation"]=.MBPositionServiceBuild~OPERATION
req["terminalId"]="ATM-IOM-001"
req["bankSessionId"]="S-CLOSED"
req["customerId"]="C-CLOSED"
req["requestedAt"]="2026-08-26T12:00:00.000Z"
r=svc~handleRequest(req)
call assertEq 1,r["ok"],"read succeeds"
call assertEq 0,r["data"]["positionCount"],"ATM sees no open client position after economic close"
call assertEq 1,p~monitoredContractCount,"original CFD remains live/monitored"
call assertEq 1,hp~monitoredContractCount,"reversing CFD remains live/monitored"
say "PASS test_closed_client_position_projection"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::class FixtureLinkageResolver
::method init
  expose session customer terminal relationship
  use strict arg session,customer,terminal,relationship
::method resolve
  expose session customer terminal relationship
  use strict arg gotSession,gotCustomer,gotTerminal,transportContext=.nil
  if gotSession<>session | gotCustomer<>customer | gotTerminal<>terminal then return .nil
  return .MBTrustedRelationshipLink~new(session,customer,terminal,relationship,"RETAIL-LINKAGE-AUTH")
::requires "FederationBankMerchantPositionService.cls"

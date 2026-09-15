mb=.FederationBankMerchantBank~new
svc=.MBPositionEnquiryService~new(mb,.NilResolver~new)
r=svc~handleRequest(request())
call assertFalse r["ok"],"missing relationship neutral failure"
call assertEq "NO_LINKED_BROKERAGE_ACCOUNT",r["code"],"no account discovery"

req=request(); req["portfolioId"]="PF-I-CHOOSE"
r=svc~handleRequest(req)
call assertEq "BROKERAGE_CALLER_SCOPE_INVALID",r["code"],"terminal cannot choose portfolio"

bad=.MBPositionEnquiryService~new(mb,.MismatchResolver~new)
r=bad~handleRequest(request())
call assertEq "BROKERAGE_LINKAGE_CONTEXT_MISMATCH",r["code"],"link must bind exact retail context"
call expectNoTrade bad,"read service has no trading method"

say "PASS test_linkage_and_scope"
exit 0
::routine request
  d=.directory~new
  d["schema"]=.MBPositionServiceBuild~REQUEST_SCHEMA
  d["commandId"]="C1"; d["operation"]=.MBPositionServiceBuild~OPERATION; d["terminalId"]="ATM1"; d["bankSessionId"]="S1"; d["customerId"]="CUST1"; d["requestedAt"]="NOW"
  return d
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertFalse
  use strict arg actual,label
  if actual<>.false then raise syntax 88.900 array("ASSERT_FALSE",label)
::routine expectNoTrade
  use strict arg svc,label
  caught=.false
  signal on syntax name got
  svc~placeTrade("anything")
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_NO_METHOD",label)
  return
got:
  caught=.true
  signal off syntax
  return
::class NilResolver
::method resolve
  use arg s,c,t,transportContext
  return .nil
::class MismatchResolver
::method resolve
  use strict arg s,c,t,transportContext=.nil
  return .MBTrustedRelationshipLink~new("OTHER",c,t,"MBR-X","AUTH")
::requires "FederationBankMerchantPositionService.cls"

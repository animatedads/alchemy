v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
p=.VMMSyntheticRiskPolicy~new("SYN-RISK-JPY","JPY",100000000000,50000000000,25,"POL-SYN-JPY")
p~addWrongWayEntity("FEDERATIONBANK_HOLDINGS","VMM-FUNDING-DEPENDENCY-FED")
x~setRiskPolicy(p,"VMM-INDEPENDENT-RISK")
a=.VMMPortfolioReferencePosition~new("P-JGB","AJI","JGB-BASKET","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",9000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-JGB")
b=.VMMPortfolioReferencePosition~new("P-FED","AJI","FED-SENIOR","FEDERATIONBANK_HOLDINGS","BANK_DEBT","JPY",1000000000,"ALL_JAPAN_INSURANCE","","AJI-CURRENT","","VAL-FED")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-Q","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T132000",.array~of(a,b),"AJI-POSITIONS","","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
root="./tmp_queue_synthetic_"||.DateTime~new~microseconds
q=.VMMInstitutionalSyntheticQueueService~new(x,root,"ALL_JAPAN_INSURANCE_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
client=.VMMInstitutionalSyntheticQueueClient~new(q~manager,"ALL_JAPAN_INSURANCE_GATEWAY","ALL_JAPAN_INSURANCE","AJI")
req=.VMMInstitutionalSyntheticRequest~new("REQ-AJI-1","IDEMP-REQ-AJI-1","CORR-AJI-1","AJI","ALL_JAPAN_INSURANCE","AJI-TREASURY","AJI-SNAP-Q","PORTFOLIO_LOSS_PROTECTION","JPY",10000000000,"20310831","20260828T132100")
call assertTrue client~submitRequest(req)~ok,"institutional request queued"
call assertTrue q~processNextRequest("OFF-AJI-1",5,25,120000000,"20260901","20260828T140000","20260828T132200","MODEL-AJI-1","MKT-AJI-1","RISK-AJI-1")~ok,"VMM prices queued request"
rr=client~receiveOffer; call assertTrue rr~ok,"offer received"
o=rr~value
call assertEq "OFF-AJI-1",o~offerId,"offer identity"
call assertEq 10000000000,o~protectedNotional,"offer notional"
acc=.VMMInstitutionalSyntheticAcceptance~new("ACC-AJI-1","IDEMP-ACC-AJI-1","CORR-AJI-1","OFF-AJI-1","VMM-AJI-SYN-1","AJI","ALL_JAPAN_INSURANCE","AJI-AUTH-SIGNER","20260828T132300")
call assertTrue client~submitAcceptance(acc)~ok,"institutional acceptance queued"
call assertTrue q~processNextAcceptance~ok,"VMM books accepted contract"
cc=client~receiveConfirmation; call assertTrue cc~ok,"confirmation received"
conf=cc~value
call assertEq "VMM-AJI-SYN-1",conf~contractId,"contract confirmation identity"
call assertEq "ACTIVE",x~contract("VMM-AJI-SYN-1")~state,"contract active in VMM books"
/* The client object deliberately has no product service or VMM engine methods. */
call assertTrue \client~hasMethod("vmm"),"client has no VMM engine accessor"
call assertTrue \client~hasMethod("productService"),"client has no product-service accessor"
/* A random Federation principal is not granted access to the institutional request queue. */
r=q~manager~put(.VMMInstitutionalSyntheticQueueBuild~requestQueue,req,.nil,"FEDERATIONBANK_MERCHANT_VMM_GATEWAY")
call assertTrue \r~ok,"Federation principal cannot enter insurer synthetic queue"
say "PASS test_synthetic_queue_contract_lifecycle"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "VectorMeridianInstitutionalSyntheticQueue.cls"

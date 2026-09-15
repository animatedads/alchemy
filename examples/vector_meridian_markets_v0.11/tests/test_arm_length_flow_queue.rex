v=.VectorMeridianMarkets~new
s=.VMMAlgorithmStrategy~new("ALG-ARM-1","3.0","ARM_LENGTH_MM","SRC-ARM","MODEL-ARM",1000000,2000000,"POL-ARM")
v~registerStrategy(s); v~enableStrategy("ALG-ARM-1","VMM-RISK")
root="./tmp_queue_arm_"||.DateTime~new~microseconds
svc=.VMMArmLengthFlowService~new(v,root)
client=.FederationMerchantVMMQueueClient~new(svc~manager)
rfq=.VMMArmLengthRFQ~new("RFQ-ARM-1","IDEMP-RFQ-ARM-1","CORR-ARM-1","FEDERATIONBANK_MERCHANT_BANK","FEDERATIONBANK_MERCHANT_GATEWAY","CITI-L","CITI","GB00CITI0001","XLON","ORDINARY","GBP","GBP","GBP","RES-CITI-L","CFD","LONG",100000,"REL-OPAQUE-ARM-1","20260828T140000")
call assertTrue \rfq~hasMethod("customerEntity"),"wire RFQ has no customer legal-identity field"
call assertTrue client~submitRFQ(rfq)~ok,"Federation submits RFQ only to queue"
call assertTrue svc~processNextRFQ("ALG-ARM-1","Q-ARM-1",80,10,"20260828T140010","20260828T140001")~ok,"VMM consumes and prices RFQ"
qr=client~receiveQuote
call assertTrue qr~ok,"Federation receives VMM quote"
q=qr~value
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",q~vmmEntity,"quote identifies separate VMM legal entity"
call assertEq "CORR-ARM-1",q~correlationId,"correlation survives company boundary"
inst=.VMMArmLengthExecutionInstruction~new("EXEC-ARM-1","IDEMP-EXEC-ARM-1","CORR-ARM-1",q~quoteId,"VMM-T-ARM-1","20260828T140002","FEDERATIONBANK_MERCHANT_BANK","FEDERATIONBANK_MERCHANT_GATEWAY")
call assertTrue client~submitExecution(inst)~ok,"Federation sends acceptance through queue"
call assertTrue svc~processNextExecution~ok,"VMM books its own principal trade"
cr=client~receiveTradeConfirmation
call assertTrue cr~ok,"Federation receives VMM trade confirmation"
c=cr~value
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",c~vmmEntity,"confirmation retains VMM counterparty identity"
call assertEq "FEDERATIONBANK_MERCHANT_FLOW",c~counterpartyChannel,"trade remains arm-length merchant flow"
t=v~principalTrade("VMM-T-ARM-1")
call assertEq "REL-OPAQUE-ARM-1",t~anonRelationshipRef,"VMM retains opaque relationship reference only"
call assertEq "SHORT",t~principalSide,"VMM takes opposite side of customer flow"
say "PASS test_arm_length_flow_queue"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg value,label
  if \value then raise syntax 88.900 array("ASSERT_TRUE",label)

::requires "VectorMeridianFederationQueue.cls"

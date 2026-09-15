i=.VMMTradableInstrument~new("CITI-L","CITI","GB00CITI0001","XLON","ORDINARY","GBP","GBP","GBP","RES-CITI-L")
a=.VectorMeridianFederationMerchantAdapter~new
mi=a~asMerchantInstrumentIdentity(i,"GBP")
call assertEq "GB00CITI0001",mi~isin,"ISIN retained into Merchant identity"
call assertEq "XLON",mi~venueMic,"venue retained into Merchant identity"
call assertEq "GBP",mi~settlementCurrency,"settlement currency retained"
call assertEq "RES-CITI-L",mi~resolutionEvidenceRef,"resolution evidence retained"
say "PASS test_merchant_identity_adapter"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianFederationMerchantAdapter.cls"

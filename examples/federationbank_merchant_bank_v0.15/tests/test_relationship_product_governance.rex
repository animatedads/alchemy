e=.MBDecisionEvidence~new("PERMITTED","PERMITTED","LEGAL-PROD-1","POLICY-PROD-1")
mb=.FederationBankMerchantBank~new
r=.MBMerchantRelationship~new("MBR-100","CLIENT-LEGAL-1","RETAIL-LINK-OPAQUE-77","LINK-AUTH-9","20260826T080000")
mb~registerRelationship(r)
p=mb~createPortfolio("PF-100","CLIENT-LEGAL-1","GBP","MBR-100")
prod=.MBDerivativeProductDefinition~new("PROD-CFD-FTSE","1","CFD","FTSE100","GBP","CASH",e)
mb~registerProduct(prod)
t=.MBDerivativeTrade~new("T-100","PF-100","CLIENT-LEGAL-1","CFD","LONG","GBP",1000000,0,0,"",1,"FTSE100","PROD-CFD-FTSE","FTSE100","20260826T080100")
mb~bookTrade(t)
call assertEq "MBR-100",p~relationshipId,"portfolio bound to merchant relationship"
call assertEq "PROD-CFD-FTSE",t~productId,"trade bound to governed product"
call assertTrue mb~journal~retainedNodeCount>=4,"relationship/product/portfolio/trade journalled"

bad=.MBDecisionEvidence~new("PERMITTED","PROHIBITED","LEGAL-PROD-2","POLICY-NO")
call expectProduct bad,"policy-prohibited product rejected"
call expectPortfolio mb,"PF-X","OTHER-ENTITY","GBP","MBR-100","cross-entity portfolio linkage rejected"

say "PASS test_relationship_product_governance"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
::routine expectProduct
  use strict arg evidence,label
  caught=.false
  signal on syntax name got
  x=.MBDerivativeProductDefinition~new("BAD","1","CFD","X","GBP","CASH",evidence)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
got:
  caught=.true
  signal off syntax
  return
::routine expectPortfolio
  use strict arg mb,id,entity,currency,relationshipId,label
  caught=.false
  signal on syntax name got2
  mb~createPortfolio(id,entity,currency,relationshipId)
  signal off syntax
  if \caught then raise syntax 88.900 array("ASSERT_EXPECTED_SYNTAX",label)
  return
got2:
  caught=.true
  signal off syntax
  return
::requires "FederationBankMerchantBank.cls"

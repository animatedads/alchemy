cat=.RIDDistributionCatalog~new
prov=.RIDProviderIdentity~new("P","SYS")
p=.RIDProductReference~new("P1",prov,"X","1","SEM-A","INVESTMENT","GB")
.RIDTestSupport~ok(cat~addProduct(p))
a=.RIDProductDistributionApproval~new("A1","P1","SEM-B")
a~allowActivity("ARRANGE")
.RIDTestSupport~failCode("APPROVAL_PRODUCT_IDENTITY_MISMATCH",cat~approveProduct(a))
say "PASS exact product approval identity"
exit 0
::requires "RegulatedIntermediaryDistribution.cls"
::requires "TestSupport.cls"

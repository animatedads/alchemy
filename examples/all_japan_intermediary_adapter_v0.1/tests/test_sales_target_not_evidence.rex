svc=.AJIIntermediaryAdapterFixtures~distributionService
.RIDServiceFixtures~openCase(svc,"CASE-TARGET","CUSTOMER:T","ADVISED")
.RIDServiceTestSupport~ok(.RIDServiceFixtures~action(svc,"CASE-TARGET","START_DISCOVERY","CMD-TARGET-START"))
/* A workforce sales target can be referenced, but it is not demands-and-needs evidence. */
.RIDServiceTestSupport~ok(.RIDServiceFixtures~evidence(svc,"CASE-TARGET","E-SALES-TARGET","SALES_TARGET","INTERNAL","CRM:SALES:TARGET:HOME"))
.RIDServiceTestSupport~ok(.RIDServiceFixtures~evidence(svc,"CASE-TARGET","E-DISC","PRODUCT_DISCLOSURE","INTERNAL","DOC:DISC"))
.RIDServiceTestSupport~ok(.RIDServiceFixtures~evidence(svc,"CASE-TARGET","E-REM","REMUNERATION_DISCLOSURE","INTERNAL","DOC:REM"))
r=.RIDServiceFixtures~action(svc,"CASE-TARGET","RECOMMEND","CMD-TARGET-REC")
.RIDServiceTestSupport~fail("REQUIRED_EVIDENCE_MISSING",r)
.RIDServiceTestSupport~eq("DEMANDS_AND_NEEDS",r~detail)
say "PASS sales target cannot substitute for customer insurance evidence"
::requires "AdapterFixtures.cls"

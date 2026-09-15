v=.VectorMeridianMarkets~new
x=.VMMInstitutionalSyntheticService~new(v)
c=.VMMInstitutionalCounterparty~new("AJI","ALL_JAPAN_INSURANCE","REL-AJI","JP","KYC-AJI","ISDA-AJI","CSA-AJI","VMM-ONBOARD")
x~registerCounterparty(c)
p1=.VMMPortfolioReferencePosition~new("P1","AJI","JGB-10Y","JAPAN_GOVERNMENT","SOVEREIGN_BOND","JPY",6000000000,"ALL_JAPAN_INSURANCE","ALL_JAPAN_LIFE_LEGACY","BOOK-LIFE","SUCCESSION-LIFE-TO-AJI","VAL-P1")
p2=.VMMPortfolioReferencePosition~new("P2","AJI","TOPIX-BASKET","JAPAN_EQUITY_BASKET","EQUITY","JPY",4000000000,"ALL_JAPAN_INSURANCE","ALL_JAPAN_GENERAL_LEGACY","BOOK-GENERAL","SUCCESSION-GENERAL-TO-AJI","VAL-P2")
s=.VMMPortfolioSnapshot~new("AJI-SNAP-1","AJI","ALL_JAPAN_INSURANCE","JPY","20260828T130000",.array~of(p1,p2),"AJI-POSITION-EXPORT","MERGER-LEGAL-SUCCESSION-2026","VMM-PORTFOLIO-CONTROL")
x~registerPortfolioSnapshot(s)
call assertEq 2,s~inheritedCount,"both legacy books retained with succession evidence"
call assertEq 10000000000,s~totalMarketValue,"merged reference snapshot has exact normalized value"
call assertEq 6000000000,s~issuerMarketValue("JAPAN_GOVERNMENT"),"issuer aggregation remains exact"
say "PASS test_synthetic_merged_portfolio_snapshot"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMSyntheticProducts.cls"

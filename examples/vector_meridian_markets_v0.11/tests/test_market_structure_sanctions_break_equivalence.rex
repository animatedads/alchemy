v=.VectorMeridianMarkets~new
us=.VMMTradableInstrument~new("DUAL-US","DUAL","US000000DUA1","XNYS","ORDINARY","USD","USD","USD","RES-DUAL-US")
uk=.VMMTradableInstrument~new("DUAL-UK","DUAL","GB000000DUA1","XLON","DR","GBP","GBP","GBP","RES-DUAL-UK")
link=.VMMMarketStructureLink~new("LINK-DUAL-1",us~identityKey,uk~identityKey,"HEDGE_EQUIVALENT","LINK-EVID-PRE-SANCTIONS","VMM-MARKET-STRUCTURE")
v~registerMarketStructureLink(link)
call assertEq 1,v~marketStructureEquivalent(us,uk),"explicit evidence can establish economic hedge equivalence"
v~impairMarketStructureLink("LINK-DUAL-1","BROKEN","SANCTIONS_TRANSFER_RESTRICTION","LINK-EVID-SANCTIONS","VMM-COMPLIANCE","20260828T143000")
call assertEq 0,v~marketStructureEquivalent(us,uk),"sanctions can break prior economic equivalence"
call assertEq "BROKEN",link~status,"market-structure break retained as state"
call assertEq 0,us~sameTradableLine(uk),"economic equivalence never collapses legal tradable-line identity"
say "PASS test_market_structure_sanctions_break_equivalence"
exit 0

::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)

::requires "VectorMeridianMarkets.cls"

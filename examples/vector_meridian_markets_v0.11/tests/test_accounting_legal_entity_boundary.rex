v=.VectorMeridianMarkets~new
eng=.AccountingEngine~new("VECTOR_MERIDIAN_MARKETS_LTD","VMM-STAT","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(eng,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
a=.VMMAccountingService~new(v,eng)
call assertEq "VECTOR_MERIDIAN_MARKETS_LTD",a~book~legalEntityId,"VMM accounting owns its own legal-entity book"
call assertEq 16,a~book~chart~accountIds~items,"VMM accounting chart configured with close-out accounts"
blocked=.false
signal on syntax name wrongEntity
bad=.AccountingEngine~new("FEDERATIONBANK_MERCHANT_BANK","FB-MB","ENTITY_GAAP")
.VMMAccountingPolicy~configureEngine(bad,.AccountingPeriod~new("2026-08","2026-08-01","2026-08-31"))
signal off syntax
raise syntax 88.900 array("ASSERT_FEDERATION_ENGINE_ACCEPTED")
wrongEntity:
  blocked=.true; signal off syntax
if \blocked then raise syntax 88.900 array("ASSERT_WRONG_ENTITY_NOT_BLOCKED")
say "PASS test_accounting_legal_entity_boundary"
exit 0
::routine assertEq
  use strict arg expected,actual,label
  if expected<>actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
::requires "VMMAccounting.cls"

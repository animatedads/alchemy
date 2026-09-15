r = .directory~new
r["reservationId"] = "res-9"
r["expectedMicroWlu"] = "10000000"
b = .ReportWluReservationAdapter~bind("b-r", "PRIMARY", r)
if b~sourcePoint \= "WLU:RESERVE:res-9" then do
  say "FAIL reserve point"
  exit 1
end

s = .directory~new
s["settlementId"] = "set-9"
s["actualMicroWlu"] = "6000000"
b2 = .ReportWluSettlementAdapter~bind("b-s", "PRIMARY", s)
if b2~sourceKind \= "WLU_SETTLEMENT" then do
  say "FAIL settle kind"
  exit 1
end

n = .directory~new
n["nodePath"] = "ENTERPRISE/FLYLO/SHANNON/CHAT"
n["ceilingMicroWlu"] = "20000000"
b3 = .ReportWluNodeAdapter~bind("b-n", "SUPPORTING", n)
if b3~sourcePoint \= "WLU:NODE:ENTERPRISE/FLYLO/SHANNON/CHAT" then do
  say "FAIL node"
  exit 1
end

pb = .directory~new
pb["priceBookId"] = "flylo-std"
pb["version"] = "3"
pb["currency"] = "GBP"
signal on syntax name good
ignore = .ReportWluPriceBookAdapter~bind("b-£", "PRIMARY", pb)
say "FAIL price book accepted as PRIMARY"
exit 1
good:
  b4 = .ReportWluPriceBookAdapter~bind("b-gbp", "DERIVED", pb)
  if b4~sourceKind \= "WLU_PRICE_BOOK" then do
    say "FAIL price kind"
    exit 1
  end
  say "PASS test_wlu_adapter"
  exit 0

::requires "../src/adapters/wlu/ReportWluAdapter.cls"

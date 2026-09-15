d = .directory~new
d["positionId"] = "MC-441"
b = .ReportCollateralAdapter~bind("b-col", "PRIMARY", d)
if b~sourceKind \= "COLLATERAL_POSITION" then do
  say "FAIL kind" b~sourceKind
  exit 1
end
if b~sourcePoint \= "BANK:COLLATERAL:MC-441" then do
  say "FAIL point" b~sourcePoint
  exit 1
end
say "PASS test_bank_adapter"
exit 0

::requires "../src/adapters/bank/ReportCollateralAdapter.cls"

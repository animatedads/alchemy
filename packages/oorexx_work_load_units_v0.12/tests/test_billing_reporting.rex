MICRO = 1000000
ledger = .WLUMemoryLedger~new
ignore = ledger~append(100, "RESERVE", "r1", "AI_A", "acct-A", "MODEL:X", 2 * MICRO, "")
ignore = ledger~append(110, "CONSUME", "r1", "AI_A", "acct-A", "MODEL:X", 1500000, "")
ignore = ledger~append(120, "RELEASED", "r1", "AI_A", "acct-A", "MODEL:X", 1500000, "reserved=2000000")
ignore = ledger~append(130, "DENY", "", "AI_A", "acct-A", "MODEL:X", MICRO, "WLU_CAPACITY_EXHAUSTED")
ignore = ledger~append(140, "SETTLED", "r2", "AI_A", "acct-A", "MODEL:X", 500000, "reserved=500000")
ignore = ledger~append(150, "SETTLED", "r3", "AI_B", "acct-B", "MODEL:X", 9 * MICRO, "")

price = .WLUPriceBook~new("customer-uk", "2026-08", "GBP", 250000) /* GBP 0.25 / WLU */
billingResult = .WLUBillingCalculator~statement(ledger~events, "acct-A", price)
call assertTrue billingResult~ok, "billing statement"
s = billingResult~value
call assertEq 2 * MICRO, s~settledMicroWlu, "only terminal settlement events bill"
call assertEq 2, s~settlementCount, "settlement count"
call assertEq "GBP", s~currency, "currency"
call assertEq 500000, s~microCurrency, "money translated after accounting"
call assertEq "customer-uk", s~priceBookId, "price book id"
call assertEq "2026-08", s~priceBookVersion, "price book version"

window = .WLUBillingCalculator~statement(ledger~events, "acct-A", price, 125, 145)
call assertTrue window~ok, "billing window"
call assertEq 500000, window~value~settledMicroWlu, "window isolates second settlement"

say "PASS test_billing_reporting"
exit 0

assertEq: procedure
  use arg expected, actual, label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return
assertTrue: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "WLUReporting.cls"

strategy = .PlayerStrategy~new("test", 0.5, 0.0, 1.0)
a = .Player~new("A", 1000, strategy)
b = .Player~new("B", 1000, strategy)
c = .Player~new("C", 1000, strategy)

/* 100 / 300 / 500 => 300 main, 400 side, 200 unmatched return. */
a~totalBet = 100
b~totalBet = 300
c~totalBet = 500
pots = .PotBuilder~build(.array~of(a,b,c))
call assertEqual 3, pots~items, "slice count"
call assertEqual "MAIN", pots[1]~potType, "main kind"
call assertEqual 300, pots[1]~amount, "main amount"
call assertEqual 100, pots[1]~cap, "main cap"
call assertEqual 3, pots[1]~eligible~items, "main eligible"
call assertEqual "SIDE", pots[2]~potType, "side kind"
call assertEqual 400, pots[2]~amount, "side amount"
call assertEqual 300, pots[2]~cap, "side cap"
call assertEqual 2, pots[2]~eligible~items, "side eligible"
call assertEqual "RETURN", pots[3]~potType, "return kind"
call assertEqual 200, pots[3]~amount, "return amount"
call assertEqual 500, pots[3]~cap, "return cap"

/* Folded chips stay in pots but the folded player cannot win them. */
a~folded = .true
a~totalBet = 100
b~totalBet = 300
c~totalBet = 300
pots = .PotBuilder~build(.array~of(a,b,c))
call assertEqual 2, pots~items, "folded slice count"
call assertEqual 300, pots[1]~amount, "folded main amount"
call assertEqual 2, pots[1]~eligible~items, "folded main eligible"
call assertEqual 400, pots[2]~amount, "folded side amount"
call assertEqual 2, pots[2]~eligible~items, "folded side eligible"

say "PASS side-pot contribution ledger"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return 0

::requires "poker.cls"

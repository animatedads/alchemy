/* Minimal evaluator smoke test. */
call assertScore "royal-flush", .array~of(.Card~new(14,"S"),.Card~new(13,"S"),.Card~new(12,"S"),.Card~new(11,"S"),.Card~new(10,"S")), 8
call assertScore "quads", .array~of(.Card~new(9,"S"),.Card~new(9,"H"),.Card~new(9,"D"),.Card~new(9,"C"),.Card~new(2,"S")), 7
call assertScore "full-house", .array~of(.Card~new(8,"S"),.Card~new(8,"H"),.Card~new(8,"D"),.Card~new(4,"C"),.Card~new(4,"S")), 6
say "PASS evaluator smoke"
exit 0

assertScore: procedure
  use arg label, cards, expectedCategory
  score = .HandEvaluator~bestScore(cards)
  category = score % (15 ** 5)
  if category <> expectedCategory then do
    say "FAIL" label "score="score "category="category
    exit 1
  end
return

::requires "poker.cls"

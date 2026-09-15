strategy = .GrokFallbackStrategy~new
player = .Player~new("GROK", 1000, strategy)
table = .FallbackTestTable~new(0.33, 1000, "FLOP")

d = strategy~decide(player, table, 760, 100, .true)
if d~action \= "FOLD" then raise syntax 93.900 array("fallback failed large-bet protection")
if d~equity \= 0.33 then raise syntax 93.900 array("fallback equity mismatch")

say "PASS GROK fallback folds medium equity versus large bet"
exit 0

::class FallbackTestTable
::attribute equity get
::attribute pot get
::attribute street get
::method init
  expose equity pot street
  use arg equity, pot, street
::method estimateEquity
  expose equity
  use arg player
  return equity
::method randomInt
  use arg lo, hi
  return hi

::requires "poker.cls"

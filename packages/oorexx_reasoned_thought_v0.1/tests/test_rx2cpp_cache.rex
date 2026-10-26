/* Reasoned Thought qualification 8: a job's facts matrix under a falsifying MEASUREMENT.
 * Tom's rx2cpp example: a performance assumption that a benchmark can prove wrong, with the
 * erroneous fact and its whole downstream dependency tree recoverable - even when the measurement
 * only arrives 35 turns later.
 *
 *   Fact (turn 5):      "the cache will speed matters up"            -- the assumption
 *   Decision (turn 8):  "implement the cache"        needs the two facts
 *   Decision (turn 12): "route the hot path through the cache"       needs "implement the cache"
 *   Decision (turn 20): "spend effort tuning the cache size"         needs "implement the cache"
 *   Measurement (turn 40): "cache never hit; crossover cost paid; 1.6x SLOWDOWN"  refutes the speed fact
 *
 * Pure ooRexx 5.3; no native deps. Author: Claude (Opus 4.8), 2026-10-26. Architecture: Tom Dyer.
 */
signal on syntax name onSyntax

m = .FactsMatrix~new
m~fact("F_speed",     "the cache will speed matters up",                    5)
m~fact("F_crossover", "the interpret<->compiled crossover cost is minor",   5)
m~decision("D_impl",    "implement the cache",                     8)
m~needs("D_impl", "F_speed"); m~needs("D_impl", "F_crossover")
m~decision("D_hotpath", "route the hot path through the cache",   12)
m~needs("D_hotpath", "D_impl")
m~decision("D_tune",    "spend effort tuning the cache size",     20)
m~needs("D_tune", "D_impl")

say "== Turn 8-20: the job as planned - every decision rests soundly on the assumptions"
j = m~journal
heldAll = j~status("D_impl")["ok"] & j~status("D_hotpath")["ok"] & j~status("D_tune")["ok"]
call check heldAll, "implement/hot-path/tune all hold while the speed assumption stands"

say ""
say "== Turn 40: the benchmark lands"
m~measure("M_bench", "cache never hit; crossover cost paid; 1.6x slowdown", .array~of("F_speed"), 40)
rev = m~review

say "   erroneous fact(s):"
do f over rev["refutedFacts"]; say "     " || f["id"] "(turn" f["turn"] || "):" f["statement"]; end
say "   decisions to reconsider (the dependency tree thereafter):"
do d over rev["fallenDecisions"]; say "     " || d["id"] "(turn" d["turn"] || "): lost" d["lost"][1]; end

fellIds = .set~new
do d over rev["fallenDecisions"]; fellIds~put(d["id"]); end
expectedFell = .set~new; expectedFell~put("D_impl"); expectedFell~put("D_hotpath"); expectedFell~put("D_tune")

call check rev["refutedFacts"]~items = 1 & rev["refutedFacts"][1]["id"] = "F_speed" & rev["refutedFacts"][1]["turn"] = 5, -
  "the measurement pinpoints the one erroneous fact and WHEN it was assumed: F_speed, turn 5"
call check setEqual(fellIds, expectedFell), -
  "every decision built on it - directly (D_impl) and transitively (D_hotpath, D_tune) - is flagged to reconsider"
call check j~status("F_crossover")["ok"], -
  "the 'minor crossover cost' fact is NOT impugned: a minor cost paid with no hits still yields a slowdown"

say ""
say "   That is the payoff: a 1.6x slowdown discovered at turn 40 points straight back to the turn-5"
say "   assumption that was wrong, and names exactly which later decisions rested on it."

say ""
say "REASONED THOUGHT RX2CPP-CACHE FACTS-MATRIX TEST: PASS (" || checks || " checks)"
exit 0

setEqual: procedure
  use arg a, b
  if a~items \= b~items then return .false
  do x over a; if \ b~hasItem(x) then return .false; end
  return .true

check:
  use arg ok, label
  if symbol("checks") = "LIT" then checks = 0
  checks += 1
  if ok == 1 | ok == .true then do; say "PASS" label; return; end
  say "FAIL" label
  exit 1

onSyntax:
  co = condition("O")
  say "SYNTAX rc=" || rc "line" sigl":" condition("D")
  if co \== .nil, co~hasIndex("ADDITIONAL") then do e over co["ADDITIONAL"]; say "  A=" || e; end
  exit 1

::requires "FactsMatrix.cls"

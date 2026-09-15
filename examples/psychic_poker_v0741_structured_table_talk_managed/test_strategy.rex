standard = .PlayerStrategy~new("standard", 0.5, 0.08, 1.0)
equity = .PsychicEquityStrategy~new("equity", 0.5, 0.08, 1.0)
exploit = .PsychicExploitStrategy~new("exploit", 0.5, 0.08, 1.0)
team = .PsychicTeamStrategy~new("team", 0.5, 0.08, 1.0)

call assertEqual "STANDARD", standard~strategyType, "standard type"
call assertEqual "PSYCHIC_EQUITY", equity~strategyType, "equity type"
call assertEqual "PSYCHIC_EXPLOIT", exploit~strategyType, "exploit type"
call assertEqual "PSYCHIC_TEAM", team~strategyType, "team type"
call assertEqual "INDIVIDUAL_BANKROLL", exploit~objective, "exploit objective"
call assertEqual "TEAM_BANKROLL", team~objective, "team objective"

normal = .Player~new("Normal", 1000, standard)
psi = .PsychicPlayer~new("Psi", 1000, exploit, "RED")
otherPsi = .PsychicPlayer~new("Other", 1000, team, "BLUE")

if normal~knownStrategyObjectFor(normal) \== .nil then call fail "ordinary player gained strategy privilege"
if psi~knownStrategyObjectFor(normal) == .nil then call fail "psychic cannot read normal strategy object"
if psi~knownStrategyObjectFor(otherPsi) \== .nil then call fail "psychic can read psychic strategy object"

table = .PokerTable~new("test", .GameConfig~new(5,10,1000,4))
table~addPlayer(psi)
table~addPlayer(.PsychicPlayer~new("Mate",1000,team,"RED"))
if table~teamMatePressure(psi) then call fail "team pressure exists without voluntary aggression"

say "PASS strategy families and privilege boundaries"
exit 0

assertEqual: procedure
  use arg expected, actual, label
  if expected \= actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return 0

fail: procedure
  use arg message
  say "FAIL" message
  exit 1

::requires "poker.cls"

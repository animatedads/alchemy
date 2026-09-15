t1 = makeTable(424242)
t1~verbose = .false
t1~playHand

root = "/tmp/psychic-poker-v06-rng-isolation"
address system "rm -rf" root
t2 = makeTable(424242)
t2~verbose = .false
store = .PokerExperimentStore~new(root, t2~players, 99)
store~beginExperiment("rng-isolation")
t2~observer(store)
t2~playHand

p1 = t1~players
p2 = t2~players
if p1~items \= p2~items then do
  say "FAIL rng isolation player count"
  exit 1
end
do i = 1 to p1~items
  if p1[i]~name \= p2[i]~name then do
    say "FAIL rng isolation player identity"
    exit 1
  end
  if p1[i]~stack \= p2[i]~stack then do
    say "FAIL rng isolation" p1[i]~name p1[i]~stack p2[i]~stack
    exit 1
  end
end
say "PASS poker RNG isolated from NoSQLServer activity"
exit 0

makeTable: procedure
  use arg seed
  config = .GameConfig~new(5, 10, 1000, 16, seed)
  table = .PokerTable~new("alpha", config)
  safe = .PlayerStrategy~new("safe", 0.25, 0.03, 0.80)
  balanced = .PlayerStrategy~new("balanced", 0.50, 0.08, 1.00)
  loose = .PlayerStrategy~new("loose", 0.75, 0.16, 1.25)
  psiEquity = .PsychicEquityStrategy~new("psi-equity", 0.50, 0.08, 1.00)
  psiExploit = .PsychicExploitStrategy~new("psi-exploit", 0.55, 0.10, 1.10)
  psiTeam = .PsychicTeamStrategy~new("psi-team", 0.55, 0.10, 1.10)
  table~addPlayer(.Player~new("Ada", 1000, safe))
  table~addPlayer(.Player~new("Grace", 1000, balanced))
  table~addPlayer(.Player~new("Alan", 1000, loose))
  table~addPlayer(.PsychicPlayer~new("PsiEq", 1000, psiEquity, "SOLO_EQ"))
  table~addPlayer(.PsychicPlayer~new("PsiX", 1000, psiExploit, "SOLO_X"))
  table~addPlayer(.PsychicPlayer~new("PsiA", 1000, psiTeam, "RED"))
  table~addPlayer(.PsychicPlayer~new("PsiB", 1000, psiTeam, "RED"))
  return table

::requires "poker.cls"
::requires "experiment_store.cls"

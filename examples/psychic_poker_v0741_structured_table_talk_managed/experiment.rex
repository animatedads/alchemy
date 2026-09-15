parse arg hands root replaySeed
if hands = "" then hands = 20
if root = "" then root = "/tmp/psychic-poker-v05-db"

config = .GameConfig~new(5, 10, 1000, 16)
table = .PokerTable~new("alpha", config)

safe = .PlayerStrategy~new("safe", 0.25, 0.03, 0.80)
balanced = .PlayerStrategy~new("balanced", 0.50, 0.08, 1.00)
loose = .PlayerStrategy~new("loose", 0.75, 0.16, 1.25)
psiEquity = .PsychicEquityStrategy~new("psi-equity", 0.50, 0.08, 1.00)
psiExploit = .PsychicExploitStrategy~new("psi-exploit", 0.55, 0.10, 1.10)
psiTeam = .PsychicTeamStrategy~new("psi-team", 0.55, 0.10, 1.10)

ada = .Player~new("Ada", 1000, safe)
grace = .Player~new("Grace", 1000, balanced)
alan = .Player~new("Alan", 1000, loose)
psiE = .PsychicPlayer~new("PsiEq", 1000, psiEquity, "SOLO_EQ")
psiX = .PsychicPlayer~new("PsiX", 1000, psiExploit, "SOLO_X")
psiA = .PsychicPlayer~new("PsiA", 1000, psiTeam, "RED")
psiB = .PsychicPlayer~new("PsiB", 1000, psiTeam, "RED")

table~addPlayer(ada); table~addPlayer(grace); table~addPlayer(alan)
table~addPlayer(psiE); table~addPlayer(psiX); table~addPlayer(psiA); table~addPlayer(psiB)
store = .PokerExperimentStore~new(root, table~players, 1)
store~beginExperiment("strategy-family-comparison")
experimentId = store~experimentId
table~observer(store)

do h = 1 to hands
  live = 0
  ps = table~players
  do i = 1 to ps~items
    if ps[i]~stack > 0 then live += 1
  end
  if live < 2 then leave
  table~playHand
end

say ""
say "=== LIVE OBJECT TABLE ==="
call show store~execute("SELECT name,stack,psychic,team,strategy_type,strategy_objective FROM live_players ORDER BY stack DESC")
say ""
say "=== PROFIT BY STRATEGY FAMILY ==="
call show store~execute("SELECT strategy_type,strategy_objective,SUM(profit) AS profit,COUNT(*) AS player_hands FROM hand_result WHERE experiment_id=" || experimentId || " GROUP BY strategy_type,strategy_objective ORDER BY profit DESC")
say ""
say "=== LIVE + HISTORY FEDERATED JOIN ==="
call show store~execute("SELECT live_players.name,live_players.strategy_type,live_players.strategy_objective,live_players.stack,SUM(hand_result.profit) AS historic_profit FROM live_players JOIN hand_result ON live_players.name=hand_result.player_name WHERE hand_result.experiment_id=" || experimentId || " GROUP BY live_players.name,live_players.strategy_type,live_players.strategy_objective,live_players.stack ORDER BY historic_profit DESC")
say ""
say "=== PSYCHIC CAPABILITIES AVAILABLE ==="
call show store~execute("SELECT observer_name,capability_type,COUNT(*) AS capabilities FROM psychic_capability WHERE experiment_id=" || experimentId || " GROUP BY observer_name,capability_type ORDER BY observer_name,capability_type")
say ""
say "=== PSYCHIC INFORMATION ACTUALLY CONSUMED ==="
call show store~execute("SELECT observer_name,observation_type,COUNT(*) AS observations FROM psychic_observation WHERE experiment_id=" || experimentId || " GROUP BY observer_name,observation_type ORDER BY observer_name,observation_type")
say ""
say "=== POT SETTLEMENT AUDIT ==="
call show store~execute("SELECT pot_type,COUNT(*) AS settlements,SUM(winner_share) AS distributed FROM pot_settlement WHERE experiment_id=" || experimentId || " GROUP BY pot_type ORDER BY pot_type")
say ""
say "=== ACTIONS BY STRATEGY FAMILY ==="
call show store~execute("SELECT strategy_type,action,COUNT(*) AS actions,AVG(equity) AS avg_equity,AVG(exploit_leverage) AS avg_exploit_leverage FROM action_log WHERE experiment_id=" || experimentId || " GROUP BY strategy_type,action ORDER BY strategy_type,action")
say ""
say "=== BB/100 BY STRATEGY FAMILY (SMALL-SAMPLE DIAGNOSTIC) ==="
call show store~execute("SELECT strategy_type,SUM(profit)*100.0/(COUNT(*)*" || config~bigBlind || ") AS bb_per_100 FROM hand_result WHERE experiment_id=" || experimentId || " GROUP BY strategy_type ORDER BY bb_per_100 DESC")
exit 0

show: procedure
  use arg r
  if r~status \= .Error~SUCCESS then do
    say "QUERY ERROR" r~error r~message
    return
  end
  do i = 1 to r~rows~items
    row = r~rows[i]
    names = row~values~allIndexes
    line = ""
    do n over names
      if line <> "" then line ||= " | "
      line ||= n || "=" || row[n]
    end
    say line
  end
  return

::requires "poker.cls"
::requires "experiment_store.cls"

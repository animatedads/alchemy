parse arg root
if root = "" then root = "/tmp/hardworld-report-scope-test"

cfg = .GameConfig~new(5,10,1000,4,111)
strategy = .PlayerStrategy~new("test",0.5,0,1)
players = .array~of(.Player~new("GROK",1000,strategy), .Player~new("A",1000,strategy))

s1 = .PokerExperimentStore~new(root, players)
s1~beginExperiment("scope-one")
row1 = .table~new
row1["experiment_id"] = s1~experimentId
row1["hand_no"] = 1; row1["seq"] = 1; row1["table_name"] = "t"; row1["street"] = "PREFLOP"
row1["player_name"] = "GROK"; row1["action"] = "FOLD"; row1["amount"] = 0
row1["equity"] = 0; row1["pot_odds"] = 0; row1["to_call"] = 10
row1["psychic"] = .false; row1["team"] = ""; row1["strategy_type"] = "AI_GROK"
row1["strategy_objective"] = "INDIVIDUAL_BANKROLL"; row1["exploit_leverage"] = 0
call insertRow s1~engine, "action_log", row1

s2 = .PokerExperimentStore~new(root, players)
s2~beginExperiment("scope-two")
row2 = .table~new
row2["experiment_id"] = s2~experimentId
row2["hand_no"] = 1; row2["seq"] = 1; row2["table_name"] = "t"; row2["street"] = "PREFLOP"
row2["player_name"] = "GROK"; row2["action"] = "RAISE"; row2["amount"] = 30
row2["equity"] = 0; row2["pot_odds"] = 0; row2["to_call"] = 10
row2["psychic"] = .false; row2["team"] = ""; row2["strategy_type"] = "AI_GROK"
row2["strategy_objective"] = "INDIVIDUAL_BANKROLL"; row2["exploit_leverage"] = 0
call insertRow s2~engine, "action_log", row2

q = "SELECT action FROM action_log WHERE experiment_id=" || s2~experimentId || " AND player_name='GROK' ORDER BY hand_no,seq"
r = s2~execute(q)
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("scoped report query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("scoped report leaked another experiment")
if r~rows[1]["action"] \= "RAISE" then raise syntax 93.900 array("wrong experiment action returned")
say "PASS report queries scoped by experiment_id"
exit 0

insertRow: procedure
  use arg engine, tableName, row
  r = engine~insert(tableName,row)
  if r~status \= .Error~SUCCESS then raise syntax 93.900 array("test insert failed")
  return 1

::requires "poker.cls"
::requires "experiment_store.cls"

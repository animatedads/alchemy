parse arg root
if root = "" then root = "/tmp/hardworld-oracle-v2-test"

call SysFileTree root || "/*", "oldFiles.", "FOS"
do i = 1 to oldFiles.0
  call SysFileDelete oldFiles.i
end
call SysFileTree root || "/*", "oldDirs.", "DOS"
do i = oldDirs.0 to 1 by -1
  call SysRmDir oldDirs.i
end
call SysRmDir root

cfg = .GameConfig~new(5,10,1000,8,111)
strategy = .PlayerStrategy~new("test",0.5,0.1,1)
players = .array~of(.Player~new("A",1000,strategy), .Player~new("B",1000,strategy))
store = .PokerExperimentStore~new(root,players)
store~beginExperiment("history")
eid = store~experimentId

/* Winner: a raise should acquire positive value. */
call addResult store,eid,1,"A",1000,120
call addAction store,eid,1,1,"A","PREFLOP","RAISE",30,0.70,0.25,10

/* Loser: same-state call must acquire negative value. */
call addResult store,eid,2,"B",1000,-180
call addAction store,eid,2,1,"B","PREFLOP","CALL",0,0.70,0.25,10

/* Small-loss fold is damage limitation, not a negative action merely because
   the hand ended below its starting stack. */
call addResult store,eid,3,"A",1000,-10
call addAction store,eid,3,1,"A","PREFLOP","FOLD",0,0.10,0.40,10

nextStore = .PokerExperimentStore~new(root,players)
nextStore~beginExperiment("oracle")
model = .OracleHistoryModel~new(nextStore,nextStore~experimentId)

if model~completedHands \= 3 then raise syntax 93.900 array("Oracle did not load all signed outcomes")
if model~learnedActions \= 3 then raise syntax 93.900 array("Oracle action count mismatch")

m = model~actionEvidence("PREFLOP",0.70,0.25,10,.true)
totals = m["totals"]; evidence = m["evidence"]
if totals["RAISE"] <= 0 then raise syntax 93.900 array("winning raise lacks positive value")
if totals["CALL"] >= 0 then raise syntax 93.900 array("losing call lacks negative value")

m2 = model~actionEvidence("PREFLOP",0.10,0.40,10,.true)
totals2 = m2["totals"]
if totals2["FOLD"] <= 0 then raise syntax 93.900 array("small-loss fold not credited as damage limitation")

say "PASS Oracle v2 signed action values and fold damage limitation"
exit 0

addResult: procedure
  use arg store,eid,handNo,name,startStack,profit
  row=.table~new
  row["experiment_id"]=eid; row["hand_no"]=handNo; row["table_name"]="t"
  row["player_name"]=name; row["psychic"]=.false; row["team"]=""; row["strategy_type"]="STANDARD"
  row["strategy_objective"]="INDIVIDUAL_BANKROLL"; row["start_stack"]=startStack
  row["end_stack"]=startStack+profit; row["profit"]=profit; row["finish_type"]="TEST"
  call insertRow store~engine,"hand_result",row
  return

addAction: procedure
  use arg store,eid,handNo,seq,name,street,action,amount,equity,potOdds,toCall
  row=.table~new
  row["experiment_id"]=eid; row["hand_no"]=handNo; row["seq"]=seq; row["table_name"]="t"
  row["street"]=street; row["player_name"]=name; row["action"]=action; row["amount"]=amount
  row["equity"]=equity; row["pot_odds"]=potOdds; row["to_call"]=toCall; row["psychic"]=.false
  row["team"]=""; row["strategy_type"]="STANDARD"; row["strategy_objective"]="INDIVIDUAL_BANKROLL"
  row["exploit_leverage"]=0
  call insertRow store~engine,"action_log",row
  return

insertRow: procedure
  use arg engine,tableName,row
  result=engine~insert(tableName,row)
  if result~status \= .Error~SUCCESS then raise syntax 93.900 array("test insert failed")
  return

::requires "poker.cls"
::requires "experiment_store.cls"

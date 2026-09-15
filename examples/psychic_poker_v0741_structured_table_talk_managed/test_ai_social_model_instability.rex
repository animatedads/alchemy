parse arg root
if root = "" then root = "/tmp/hardworld-ai-social-model-instability-test"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,733052)
ordinary = .PlayerStrategy~new("ordinary",0.5,0,1)

hugo1 = .Player~new("Hugo",1000,ordinary)
grok1 = .Player~new("GROK",1000,ordinary)
t1 = .PokerTable~new("instability-history",cfg)
t1~addPlayer(hugo1); t1~addPlayer(grok1)
store1 = .PokerExperimentStore~new(root,.array~of(hugo1,grok1))
store1~beginExperiment("instability-history")
entry = t1~talkLibrarian~classify("CALL_OUT")
store1~tableTalk(t1,hugo1,grok1,entry)
store1~actionTaken(t1,hugo1,.Decision~new("RAISE",25,0,0),10)

hugo2 = .Player~new("Hugo",1000,ordinary)
client = .UnstableSocialClient~new
grokStrategy = .GrokPokerStrategy~new(client,.AlwaysFoldFallback~new)
grok2 = .Player~new("GROK",1000,grokStrategy)
t2 = .PokerTable~new("instability-live",cfg)
t2~addPlayer(hugo2); t2~addPlayer(grok2)
store2 = .PokerExperimentStore~new(root,.array~of(hugo2,grok2))
store2~beginExperiment("instability-live")
t2~observer(store2)

oldShadow = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
call value "POKER_SOCIAL_SHADOW", "2", "ENVIRONMENT"
d = grok2~act(t2,10,10,.true)
call value "POKER_SOCIAL_SHADOW", oldShadow, "ENVIRONMENT"

if d~action \= "CALL" then raise syntax 93.900 array("main action should CALL")
if d~controlAction \= "RAISE" then raise syntax 93.900 array("same-prompt control should reveal instability")
if d~controlAmount \= 10 then raise syntax 93.900 array("control raise amount should normalize to minimum")
if d~shadowAction \= "FOLD" then raise syntax 93.900 array("shadow action should FOLD")
store2~actionTaken(t2,grok2,d,10)

r = store2~execute("SELECT probe_mode,control_matches_main,counterfactual_diff,effect_status,unattributed_social_effect FROM ai_social_effect WHERE experiment_id=2 ORDER BY seq")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_social_effect query failed")
row = r~rows[1]
if row["probe_mode"] \= 2 then raise syntax 93.900 array("triplet probe mode missing")
if translate(row["control_matches_main"]~string) \= "FALSE" then raise syntax 93.900 array("control mismatch not detected")
if translate(row["counterfactual_diff"]~string) \= "TRUE" then raise syntax 93.900 array("counterfactual difference should still be recorded")
if row["effect_status"] \= "MODEL_INSTABILITY" then raise syntax 93.900 array("unstable same-prompt outputs must block causal label")
if translate(row["unattributed_social_effect"]~string) \= "FALSE" then raise syntax 93.900 array("unstable result must not be promoted to unattributed effect")

say "PASS same-prompt control catches model instability before causal classification"
exit 0

cleanTree: procedure
  use arg root
  call SysFileTree root || "/*", "oldFiles.", "FOS"
  do i = 1 to oldFiles.0
    call SysFileDelete oldFiles.i
  end
  call SysFileTree root || "/*", "oldDirs.", "DOS"
  do i = oldDirs.0 to 1 by -1
    call SysRmDir oldDirs.i
  end
  call SysRmDir root
  return

::class UnstableSocialClient public
::attribute model get
::method init
  expose model socialCalls
  model = "fake-unstable-social"
  socialCalls = 0
::method decide
  use arg prompt
  return self~answer(prompt)
::method decideWithTemperature
  use arg prompt, temperature
  return self~answer(prompt)
::method answer private
  expose socialCalls
  use arg prompt
  d = .directory~new
  d["talk"] = "NONE"
  d["talk_target"] = "NONE"
  d["social_evidence"] = "NONE"
  d["amount"] = 0
  if prompt~pos("SOCIAL EVIDENCE DISABLED FOR COUNTERFACTUAL PROBE") > 0 then do
    d["action"] = "FOLD"
    return d
  end
  socialCalls += 1
  if socialCalls = 1 then d["action"] = "CALL"
  else do
    d["action"] = "RAISE"
    d["amount"] = 1
  end
  return d

::class AlwaysFoldFallback public subclass PlayerStrategy
::method init
  forward class (super) array("always-fold",0.5,0,1)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true
  if toCall = 0 then return .Decision~new("CHECK",0,0,0)
  return .Decision~new("FOLD",0,0,0)

::requires "poker.cls"
::requires "experiment_store.cls"

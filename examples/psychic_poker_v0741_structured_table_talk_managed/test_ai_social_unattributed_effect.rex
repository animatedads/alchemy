parse arg root
if root = "" then root = "/tmp/hardworld-ai-social-unattributed-effect-test"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,733041)
ordinary = .PlayerStrategy~new("ordinary",0.5,0,1)

/* Seed public history so the live decision receives at least one E-id. */
hugo1 = .Player~new("Hugo",1000,ordinary)
grok1 = .Player~new("GROK",1000,ordinary)
t1 = .PokerTable~new("unattributed-history",cfg)
t1~addPlayer(hugo1); t1~addPlayer(grok1)
store1 = .PokerExperimentStore~new(root,.array~of(hugo1,grok1))
store1~beginExperiment("unattributed-history")
entry = t1~talkLibrarian~classify("CALL_OUT")
store1~tableTalk(t1,hugo1,grok1,entry)
store1~actionTaken(t1,hugo1,.Decision~new("RAISE",25,0,0),10)

/* Main + identical-social control both CALL, no-social shadow FOLD, while the
   model explicitly says SOCIAL_EVIDENCE=NONE.  This is a stable but
   unattributed social effect, exactly the case seen in experiment 34. */
hugo2 = .Player~new("Hugo",1000,ordinary)
client = .NoneAttributionClient~new
grokStrategy = .GrokPokerStrategy~new(client,.AlwaysFoldFallback~new)
grok2 = .Player~new("GROK",1000,grokStrategy)
t2 = .PokerTable~new("unattributed-live",cfg)
t2~addPlayer(hugo2); t2~addPlayer(grok2)
store2 = .PokerExperimentStore~new(root,.array~of(hugo2,grok2))
store2~beginExperiment("unattributed-live")
t2~observer(store2)

oldShadow = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
call value "POKER_SOCIAL_SHADOW", "2", "ENVIRONMENT"
d = grok2~act(t2,10,10,.true)
call value "POKER_SOCIAL_SHADOW", oldShadow, "ENVIRONMENT"

if d~action \= "CALL" then raise syntax 93.900 array("main social action should CALL")
if d~socialEvidenceId \= "NONE" then raise syntax 93.900 array("model should explicitly decline attribution")
if d~controlAction \= "CALL" then raise syntax 93.900 array("same-social control should CALL")
if d~shadowAction \= "FOLD" then raise syntax 93.900 array("no-social counterfactual should FOLD")
store2~actionTaken(t2,grok2,d,10)

r = store2~execute("SELECT evidence_id,attribution_status,probe_mode,control_matches_main,counterfactual_diff,effect_status,unattributed_social_effect,evidence_count,evidence_snapshot FROM ai_social_effect WHERE experiment_id=2 ORDER BY seq")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_social_effect query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("expected one effect row")
row = r~rows[1]
if row["evidence_id"] \= "NONE" then raise syntax 93.900 array("NONE attribution not persisted")
if row["attribution_status"] \= "NONE" then raise syntax 93.900 array("NONE attribution status incorrect")
if row["probe_mode"] \= 2 then raise syntax 93.900 array("triplet probe mode missing")
if translate(row["control_matches_main"]~string) \= "TRUE" then raise syntax 93.900 array("same-social stability control failed")
if translate(row["counterfactual_diff"]~string) \= "TRUE" then raise syntax 93.900 array("no-social difference missing")
if row["effect_status"] \= "STABLE_SOCIAL_EFFECT" then raise syntax 93.900 array("stable social effect not classified")
if translate(row["unattributed_social_effect"]~string) \= "TRUE" then raise syntax 93.900 array("unattributed stable effect not flagged")
if row["evidence_count"] < 1 then raise syntax 93.900 array("decision-local evidence snapshot missing")
call assertContains row["evidence_snapshot"], "E1 Hugo CHALLENGE: n=1"

/* NONE is a valid protocol choice, but it is not a validated evidence ref. */
a = store2~execute("SELECT evidence_id,evidence_valid FROM ai_social_decision WHERE experiment_id=2 ORDER BY seq")
if a~rows[1]["evidence_id"] \= "NONE" then raise syntax 93.900 array("legacy audit NONE missing")
if translate(a~rows[1]["evidence_valid"]~string) \= "FALSE" then raise syntax 93.900 array("NONE must not masquerade as a validated E-id")

say "PASS stable social effect can be detected without a model evidence attribution"
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

assertContains: procedure
  use arg text, needle
  if text~pos(needle) = 0 then raise syntax 93.900 array("missing: " || needle)
  return 1

::class NoneAttributionClient public
::attribute model get
::method init
  expose model
  model = "fake-none-attribution"
::method decide
  use arg prompt
  return self~answer(prompt)
::method decideWithTemperature
  use arg prompt, temperature
  return self~answer(prompt)
::method answer private
  use arg prompt
  d = .directory~new
  d["amount"] = 0
  d["talk"] = "NONE"
  d["talk_target"] = "NONE"
  d["social_evidence"] = "NONE"
  if prompt~pos("SOCIAL EVIDENCE DISABLED FOR COUNTERFACTUAL PROBE") > 0 then d["action"] = "FOLD"
  else d["action"] = "CALL"
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

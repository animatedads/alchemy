parse arg root
if root = "" then root = "/tmp/hardworld-ai-social-attribution-test"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,732032)
ordinary = .PlayerStrategy~new("ordinary",0.5,0,1)

/* Experiment 1 creates one public, persisted Hugo CHALLENGE -> RAISE sample. */
hugo1 = .Player~new("Hugo",1000,ordinary)
grok1 = .Player~new("GROK",1000,ordinary)
t1 = .PokerTable~new("attr-history",cfg)
t1~addPlayer(hugo1); t1~addPlayer(grok1)
store1 = .PokerExperimentStore~new(root,.array~of(hugo1,grok1))
store1~beginExperiment("attr-history")
entry = t1~talkLibrarian~classify("CALL_OUT")
store1~tableTalk(t1,hugo1,grok1,entry)
store1~actionTaken(t1,hugo1,.Decision~new("RAISE",25,0,0),10)

/* Experiment 2 gives GROK the reconstructed E1 evidence.  In shadow mode the
   fake model deliberately CALLs with social evidence and FOLDs without it. */
hugo2 = .Player~new("Hugo",1000,ordinary)
noah2 = .Player~new("Noah",1000,.GeminiEmulatedStrategy~new)
client = .AttributionFakeClient~new
grokStrategy = .GrokPokerStrategy~new(client,.AlwaysFoldFallback~new)
grok2 = .Player~new("GROK",1000,grokStrategy)
t2 = .PokerTable~new("attr-live",cfg)
t2~addPlayer(hugo2); t2~addPlayer(grok2); t2~addPlayer(noah2)
store2 = .PokerExperimentStore~new(root,.array~of(hugo2,grok2,noah2))
store2~beginExperiment("attr-live")
t2~observer(store2)

prompt = t2~agentPrompt(grok2,10,10,.true)
call assertContains prompt,"E1 Hugo CHALLENGE: n=1"
call assertContains prompt,"SOCIAL_EVIDENCE=NONE|<one displayed E-id>"

oldShadow = value("POKER_SOCIAL_SHADOW",, "ENVIRONMENT")
call value "POKER_SOCIAL_SHADOW", "2", "ENVIRONMENT"
d = grok2~act(t2,10,10,.true)
call value "POKER_SOCIAL_SHADOW", oldShadow, "ENVIRONMENT"

if d~action \= "CALL" then raise syntax 93.900 array("social main action should CALL")
if d~socialEvidenceId \= "E1" then raise syntax 93.900 array("social evidence attribution E1 missing")
if d~shadowAction \= "FOLD" then raise syntax 93.900 array("counterfactual shadow action should FOLD")
if d~shadowAmount \= 0 then raise syntax 93.900 array("counterfactual shadow amount should be zero")
if d~controlAction \= "CALL" then raise syntax 93.900 array("identical-social control should reproduce CALL")
if d~controlAmount \= 0 then raise syntax 93.900 array("identical-social control amount should be zero")

store2~actionTaken(t2,grok2,d,10)
r = store2~execute("SELECT evidence_id,evidence_valid,evidence_speaker,evidence_class,evidence_n,evidence_confidence,shadow_action,shadow_available,action_changed,amount_changed FROM ai_social_decision WHERE experiment_id=2 ORDER BY seq")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_social_decision query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("expected one AI social audit row")
row = r~rows[1]
if row["evidence_id"] \= "E1" then raise syntax 93.900 array("stored evidence id mismatch")
if translate(row["evidence_valid"]~string) \= "TRUE" then raise syntax 93.900 array("valid E1 claim was rejected")
if row["evidence_speaker"] \= "Hugo" then raise syntax 93.900 array("evidence provenance speaker missing")
if row["evidence_class"] \= "CHALLENGE" then raise syntax 93.900 array("evidence provenance class missing")
if row["evidence_n"] \= 1 then raise syntax 93.900 array("evidence sample count mismatch")
if row["evidence_confidence"] \= "LOW" then raise syntax 93.900 array("evidence confidence mismatch")
if row["shadow_action"] \= "FOLD" then raise syntax 93.900 array("shadow action not persisted")
if translate(row["shadow_available"]~string) \= "TRUE" then raise syntax 93.900 array("shadow availability not persisted")
if translate(row["action_changed"]~string) \= "TRUE" then raise syntax 93.900 array("counterfactual action change not detected")
if translate(row["amount_changed"]~string) \= "FALSE" then raise syntax 93.900 array("equal zero sizing should not count as changed")

effectResult = store2~execute("SELECT probe_mode,social_present,evidence_count,evidence_id,attribution_status,control_action,control_available,control_matches_main,counterfactual_diff,effect_status,unattributed_social_effect,evidence_snapshot FROM ai_social_effect WHERE experiment_id=2 ORDER BY seq")
if effectResult~status \= .Error~SUCCESS then raise syntax 93.900 array("ai_social_effect query failed")
if effectResult~rows~items \= 1 then raise syntax 93.900 array("expected one social effect row")
effectRow = effectResult~rows[1]
if effectRow["probe_mode"] \= 2 then raise syntax 93.900 array("strict triplet probe mode missing")
if translate(effectRow["social_present"]~string) \= "TRUE" then raise syntax 93.900 array("social evidence availability not recorded")
if effectRow["evidence_count"] < 1 then raise syntax 93.900 array("decision-local evidence count missing")
if effectRow["attribution_status"] \= "VALID" then raise syntax 93.900 array("valid E1 attribution status missing")
if effectRow["control_action"] \= "CALL" then raise syntax 93.900 array("control action not persisted")
if translate(effectRow["control_available"]~string) \= "TRUE" then raise syntax 93.900 array("control availability not persisted")
if translate(effectRow["control_matches_main"]~string) \= "TRUE" then raise syntax 93.900 array("stable same-social control not detected")
if translate(effectRow["counterfactual_diff"]~string) \= "TRUE" then raise syntax 93.900 array("counterfactual difference not detected")
if effectRow["effect_status"] \= "STABLE_SOCIAL_EFFECT" then raise syntax 93.900 array("stable social effect classification missing")
if translate(effectRow["unattributed_social_effect"]~string) \= "FALSE" then raise syntax 93.900 array("valid E1 effect should be attributed")
call assertContains effectRow["evidence_snapshot"], "E1 Hugo CHALLENGE: n=1"

/* AI_GEMINI_EMULATED is a scripted strategy, not a live LLM inference. */
store2~actionTaken(t2,noah2,.Decision~new("CHECK",0,0,0),0)
rx = store2~execute("SELECT player_name FROM ai_social_decision WHERE experiment_id=2 ORDER BY seq")
if rx~rows~items \= 1 then raise syntax 93.900 array("scripted AI_GEMINI_EMULATED polluted live-LLM attribution table")

/* A hallucinated evidence ID is preserved as a claim but explicitly invalid. */
bad = .Decision~new("CHECK",0,0,0,0,"","","E99")
store2~actionTaken(t2,grok2,bad,0)
r2 = store2~execute("SELECT evidence_id,evidence_valid FROM ai_social_decision WHERE experiment_id=2 ORDER BY seq")
if r2~rows~items \= 2 then raise syntax 93.900 array("expected second AI social audit row")
badRow = r2~rows[2]
if badRow["evidence_id"] \= "E99" then raise syntax 93.900 array("invalid claim id not preserved")
if translate(badRow["evidence_valid"]~string) \= "FALSE" then raise syntax 93.900 array("hallucinated evidence id not rejected")

say "PASS AI social attribution, decision-local snapshots and stable triplet counterfactual"
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

::class AttributionFakeClient public
::attribute model get
::method init
  expose model
  model = "fake-social-attribution"
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
  if prompt~pos("SOCIAL EVIDENCE DISABLED FOR COUNTERFACTUAL PROBE") > 0 then do
    d["action"] = "FOLD"
    d["social_evidence"] = "NONE"
  end
  else do
    d["action"] = "CALL"
    d["social_evidence"] = "E1"
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

parse arg root
if root = "" then root = "/tmp/hardworld-social-evidence-test"

call cleanTree root

cfg = .GameConfig~new(5,10,1000,4,731031)
strategy = .PlayerStrategy~new("test",0.5,0,1)
hugo = .Player~new("Hugo",1000,strategy)
grok = .Player~new("GROK",1000,strategy)
players1 = .array~of(hugo,grok)
t1 = .PokerTable~new("social-one",cfg)
t1~addPlayer(hugo)
t1~addPlayer(grok)
store1 = .PokerExperimentStore~new(root,players1)
store1~beginExperiment("social-evidence-one")

entry = t1~talkLibrarian~classify("CALL_OUT")
if entry == .nil then raise syntax 93.900 array("CALL_OUT dictionary entry missing")
store1~tableTalk(t1,hugo,grok,entry)
raiseDecision = .Decision~new("RAISE",25,0.91,0.13)
store1~actionTaken(t1,hugo,raiseDecision,10)
foldDecision = .Decision~new("FOLD",0,0.02,0.40)
store1~actionTaken(t1,hugo,foldDecision,10)

evidence1 = store1~socialEvidenceFor(t1,grok)
call assertContains evidence1,"Hugo CHALLENGE (seen this hand): n=1"
call assertContains evidence1,"next{RAISE=1 CALL=0 CHECK=0 FOLD=0}"
call assertContains evidence1,"baseline_n=2"
call assertContains evidence1,"directed at you: n=1"
call assertAbsent evidence1,"0.91"
call assertAbsent evidence1,"0.13"

/* A fresh experiment must reconstruct the same evidence from persisted
   table_talk/action_log rows, not from transient Player psychology state. */
hugo2 = .Player~new("Hugo",1000,strategy)
grok2 = .Player~new("GROK",1000,strategy)
players2 = .array~of(hugo2,grok2)
t2 = .PokerTable~new("social-two",cfg)
t2~addPlayer(hugo2)
t2~addPlayer(grok2)
store2 = .PokerExperimentStore~new(root,players2)
if store2~experimentId <> 2 then raise syntax 93.900 array("expected second experiment id")
store2~beginExperiment("social-evidence-two")
t2~observer(store2)

evidence2 = store2~socialEvidenceFor(t2,grok2)
call assertContains evidence2,"Hugo CHALLENGE: n=1"
call assertAbsent evidence2,"seen this hand"
call assertContains evidence2,"baseline_n=2"
call assertContains evidence2,"directed at you: n=1"

prompt = t2~agentPrompt(grok2,10,10,.true)
call assertContains prompt,"SOCIAL EVIDENCE (PUBLIC EMPIRICAL HISTORY)"
call assertContains prompt,"Evidence only: speech is not assumed truthful"
call assertContains prompt,"Hugo CHALLENGE: n=1"
call assertContains prompt,"PUBLIC HAND HISTORY"

say "PASS social evidence persistence/public prompt model"
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
  use arg text,needle
  if text~pos(needle)=0 then raise syntax 93.900 array("missing social evidence: "||needle)
  return 1

assertAbsent: procedure
  use arg text,needle
  if text~pos(needle)>0 then raise syntax 93.900 array("private/numeric evidence leaked: "||needle)
  return 1

::requires "poker.cls"
::requires "experiment_store.cls"

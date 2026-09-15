parse arg root
if root = "" then root = "/tmp/hardworld-social-context-test"

call cleanTree root

strategy = .PlayerStrategy~new("test",0.5,0,1)
hugo = .Player~new("Hugo",1000,strategy)
grok = .Player~new("GROK",1000,strategy)
players1 = .array~of(hugo,grok)
t1 = .SocialTableStub~new("context-one",players1)
store1 = .PokerExperimentStore~new(root,players1)
store1~beginExperiment("social-context-one")

entry = .PokerTableTalkLibrarian~new~classify("CALL_OUT")
if entry == .nil then raise syntax 93.900 array("CALL_OUT dictionary entry missing")

/* Same class in two very different public betting contexts. */
t1~handNumber = 1
t1~street = "PREFLOP"
store1~tableTalk(t1,hugo,grok,entry)
store1~actionTaken(t1,hugo,.Decision~new("RAISE",25,0,0),10)
store1~actionTaken(t1,hugo,.Decision~new("FOLD",0,0,0),10)

t1~handNumber = 2
t1~street = "FLOP"
store1~tableTalk(t1,hugo,grok,entry)
store1~actionTaken(t1,hugo,.Decision~new("CHECK",0,0,0),0)
store1~actionTaken(t1,hugo,.Decision~new("RAISE",20,0,0),0)

/* Fresh experiment proves the matched-context statistics are reconstructed
   from persisted public action/talk rows rather than transient state. */
hugo2 = .Player~new("Hugo",1000,strategy)
grok2 = .Player~new("GROK",1000,strategy)
players2 = .array~of(hugo2,grok2)
t2 = .SocialTableStub~new("context-two",players2)
t2~handNumber = 1
t2~street = "PREFLOP"
store2 = .PokerExperimentStore~new(root,players2)
if store2~experimentId <> 2 then raise syntax 93.900 array("expected second experiment id")
store2~beginExperiment("social-context-two")

evidence = store2~socialEvidenceFor(t2,grok2)
call assertContains evidence,"Hugo CHALLENGE: n=2"
call assertContains evidence,"matched context PREFLOP/FACING: talk_n=1 next{RAISE=1 CALL=0 CHECK=0 FOLD=0} baseline_n=2 baseline{RAISE=1 CALL=0 CHECK=0 FOLD=1}"

/* A new current-hand talk/action pair should select the context that actually
   accompanied that most recent public utterance, not the historical default. */
t2~street = "FLOP"
store2~tableTalk(t2,hugo2,grok2,entry)
store2~actionTaken(t2,hugo2,.Decision~new("CHECK",0,0,0),0)
evidenceRecent = store2~socialEvidenceFor(t2,grok2)
call assertContains evidenceRecent,"Hugo CHALLENGE (seen this hand): n=3"
call assertContains evidenceRecent,"matched context FLOP/FREE: talk_n=2 next{RAISE=0 CALL=0 CHECK=2 FOLD=0} baseline_n=3 baseline{RAISE=1 CALL=0 CHECK=2 FOLD=0}"
call assertContains evidenceRecent,"directed at you: n=3"
call assertContains evidenceRecent,"same context: n=2 next{RAISE=0 CALL=0 CHECK=2 FOLD=0}"

say "PASS social evidence matched-context baseline/reconstruction"
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
  if text~pos(needle)=0 then do
    say "EXPECTED:" needle
    say "ACTUAL:"
    say text
    raise syntax 93.900 array("missing contextual social evidence")
  end
  return 1

::class SocialTableStub
::attribute name
::attribute players
::attribute handNumber
::attribute street
::method init
  expose name players handNumber street
  use arg name,players
  handNumber = 0
  street = "IDLE"

::requires "poker.cls"
::requires "experiment_store.cls"

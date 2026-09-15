parse arg root
if root = "" then root = "/tmp/hardworld-social-silent-baseline-test"

call cleanTree root

strategy = .PlayerStrategy~new("test",0.5,0,1)
hugo = .Player~new("Hugo",1000,strategy)
grok = .Player~new("GROK",1000,strategy)
players1 = .array~of(hugo,grok)
t1 = .SocialTableStub~new("silent-one",players1)
store1 = .PokerExperimentStore~new(root,players1)
store1~beginExperiment("social-silent-one")

entry = .PokerTableTalkLibrarian~new~classify("CALL_OUT")
if entry == .nil then raise syntax 93.900 array("CALL_OUT dictionary entry missing")

/* Three talk-conditioned PREFLOP/FACING actions. */
t1~street = "PREFLOP"
t1~handNumber = 1
store1~tableTalk(t1,hugo,grok,entry)
store1~actionTaken(t1,hugo,.Decision~new("RAISE",25,0,0),10)

t1~handNumber = 2
store1~tableTalk(t1,hugo,grok,entry)
store1~actionTaken(t1,hugo,.Decision~new("CALL",0,0,0),10)

t1~handNumber = 3
store1~tableTalk(t1,hugo,grok,entry)
store1~actionTaken(t1,hugo,.Decision~new("RAISE",25,0,0),10)

/* Three disjoint silent actions in exactly the same public context. */
do h = 4 to 6
  t1~handNumber = h
  store1~actionTaken(t1,hugo,.Decision~new("FOLD",0,0,0),10)
end

/* Reconstruct from persisted rows in a fresh experiment. */
hugo2 = .Player~new("Hugo",1000,strategy)
grok2 = .Player~new("GROK",1000,strategy)
players2 = .array~of(hugo2,grok2)
t2 = .SocialTableStub~new("silent-two",players2)
t2~street = "PREFLOP"
t2~handNumber = 1
store2 = .PokerExperimentStore~new(root,players2)
if store2~experimentId <> 2 then raise syntax 93.900 array("expected second experiment id")
store2~beginExperiment("social-silent-two")

evidence = store2~socialEvidenceFor(t2,grok2)
call assertContains evidence,"Hugo CHALLENGE: n=3"
call assertContains evidence,"matched context PREFLOP/FACING: talk_n=3 next{RAISE=2 CALL=1 CHECK=0 FOLD=0} baseline_n=6 baseline{RAISE=2 CALL=1 CHECK=0 FOLD=3}"
call assertContains evidence,"no_talk_n=3 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=3}"
call assertContains evidence,"delta_vs_no_talk{RAISE=+66.7pp CALL=+33.3pp CHECK=0.0pp FOLD=-100.0pp}"

/* A current silent action must enlarge only the no-talk baseline. */
store2~actionTaken(t2,hugo2,.Decision~new("FOLD",0,0,0),10)
evidenceSilent = store2~socialEvidenceFor(t2,grok2)
call assertContains evidenceSilent,"Hugo CHALLENGE: n=3"
call assertContains evidenceSilent,"no_talk_n=4 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=4}"

/* A current talk-conditioned action must enlarge the talk sample but not the
   disjoint silent baseline. */
t2~handNumber = 2
store2~tableTalk(t2,hugo2,grok2,entry)
store2~actionTaken(t2,hugo2,.Decision~new("RAISE",25,0,0),10)
evidenceTalk = store2~socialEvidenceFor(t2,grok2)
call assertContains evidenceTalk,"Hugo CHALLENGE (seen this hand): n=4"
call assertContains evidenceTalk,"no_talk_n=4 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=4}"
call assertContains evidenceTalk,"delta_vs_no_talk{RAISE=+75.0pp CALL=+25.0pp CHECK=0.0pp FOLD=-100.0pp}"

say "PASS social evidence disjoint no-talk baseline/deltas"
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
    raise syntax 93.900 array("missing silent-baseline evidence")
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

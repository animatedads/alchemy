parse arg root
if root = "" then root = "/tmp/hardworld-social-decision-unit-test"

call cleanTree root

strategy = .PlayerStrategy~new("test",0.5,0,1)
hugo = .Player~new("Hugo",1000,strategy)
grok = .Player~new("GROK",1000,strategy)
players1 = .array~of(hugo,grok)
t1 = .SocialTableStub~new("decision-unit-one",players1)
t1~street = "PREFLOP"
t1~handNumber = 1
store1 = .PokerExperimentStore~new(root,players1)
store1~beginExperiment("social-decision-unit-one")

entry = .PokerTableTalkLibrarian~new~classify("CALL_OUT")
if entry == .nil then raise syntax 93.900 array("CALL_OUT dictionary entry missing")

/* Three identical utterances precede ONE public betting decision.  All three
   remain table_talk rows, but CHALLENGE/CALL_OUT/directed outcome statistics
   must gain only one behavioural sample. */
do i = 1 to 3
  store1~tableTalk(t1,hugo,grok,entry)
end
store1~actionTaken(t1,hugo,.Decision~new("RAISE",25,0,0),10)

/* One silent action gives the same-context comparison population one sample. */
t1~handNumber = 2
store1~actionTaken(t1,hugo,.Decision~new("FOLD",0,0,0),10)

rows = store1~execute("SELECT token FROM table_talk WHERE experiment_id=1 ORDER BY seq")
if rows~status \= .Error~SUCCESS then raise syntax 93.900 array("table_talk query failed")
if rows~rows~items \= 3 then raise syntax 93.900 array("utterance persistence was deduplicated; expected 3 rows")

/* Fresh experiment proves historical reconstruction uses the same decision-unit
   rule rather than counting persisted utterance rows as independent samples. */
hugo2 = .Player~new("Hugo",1000,strategy)
grok2 = .Player~new("GROK",1000,strategy)
players2 = .array~of(hugo2,grok2)
t2 = .SocialTableStub~new("decision-unit-two",players2)
t2~street = "PREFLOP"
t2~handNumber = 1
store2 = .PokerExperimentStore~new(root,players2)
if store2~experimentId <> 2 then raise syntax 93.900 array("expected second experiment id")
store2~beginExperiment("social-decision-unit-two")

evidence = store2~socialEvidenceFor(t2,grok2)
call assertContains evidence,"Hugo CHALLENGE: n=1 confidence=LOW next{RAISE=1 CALL=0 CHECK=0 FOLD=0}"
call assertContains evidence,"matched context PREFLOP/FACING: talk_n=1 next{RAISE=1 CALL=0 CHECK=0 FOLD=0}"
call assertContains evidence,"no_talk_n=1 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=1}"
call assertContains evidence,"directed at you: n=1 next{RAISE=1 CALL=0 CHECK=0 FOLD=0}"

/* Repeat the same stress in live state: two more identical utterances before one
   CALL grow each statistic by exactly one, not by two. */
do i = 1 to 2
  store2~tableTalk(t2,hugo2,grok2,entry)
end
store2~actionTaken(t2,hugo2,.Decision~new("CALL",0,0,0),10)
evidence2 = store2~socialEvidenceFor(t2,grok2)
call assertContains evidence2,"Hugo CHALLENGE (seen this hand): n=2 confidence=LOW next{RAISE=1 CALL=1 CHECK=0 FOLD=0}"
call assertContains evidence2,"token CALL_OUT: n=2 next{RAISE=1 CALL=1 CHECK=0 FOLD=0}"
call assertContains evidence2,"directed at you: n=2 next{RAISE=1 CALL=1 CHECK=0 FOLD=0}"
call assertContains evidence2,"no_talk_n=1 no_talk{RAISE=0 CALL=0 CHECK=0 FOLD=1}"

say "PASS social evidence decision-unit de-duplication/persistence"
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
    raise syntax 93.900 array("missing decision-unit social evidence")
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

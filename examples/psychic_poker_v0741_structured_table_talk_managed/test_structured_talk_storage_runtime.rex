root = "/tmp/psychic-poker-structured-talk-runtime"
call cleanTree root

cfg = .GameConfig~new(5,10,1000,20,741001)
s1 = .PlayerStrategy~new("a",0.5,0.1,1)
s2 = .PlayerStrategy~new("b",0.5,0.1,1)
p1 = .Player~new("Frank",1000,s1)
p2 = .Player~new("GROK",1000,s2)
t = .PokerTable~new("structured-talk-store",cfg)
t~verbose = .false
t~addPlayer(p1); t~addPlayer(p2)
store = .PokerExperimentStore~new(root,.array~of(p1,p2))
store~beginExperiment("structured-talk")
t~observer(store)

entry = t~talkLibrarian~classify("CALL_OUT")
factory = t~structuredTalkFactory
u = factory~build("PP-TALK-RUNTIME-1",p1,p2,entry)
summary = factory~summary(u,entry)
store~tableTalk(t,p1,p2,entry,u,summary)

r = store~execute("SELECT utterance_id,schema_version,communicative_act,intended_act,intended_outcome,authority_kind,authority_id,sealed FROM table_talk_structured WHERE experiment_id=1")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("structured talk query failed")
if r~rows~items \= 1 then raise syntax 93.900 array("expected one structured talk row")
row = r~rows[1]
if row["utterance_id"] \= "PP-TALK-RUNTIME-1" then raise syntax 93.900 array("utterance id mismatch")
if row["communicative_act"] \= "CHALLENGE" then raise syntax 93.900 array("communicative act mismatch")
if row["intended_act"] \= "CALL_OUT" then raise syntax 93.900 array("intended act mismatch")
if row["authority_id"] \= "POKER_TABLE_TALK_LIBRARIAN" then raise syntax 93.900 array("authority id mismatch")
if translate(row["sealed"]~string) \= "TRUE" then raise syntax 93.900 array("sealed flag mismatch")

r2 = store~execute("SELECT token,talk_class,phrase FROM table_talk WHERE experiment_id=1")
if r2~rows~items \= 1 then raise syntax 93.900 array("legacy table_talk row missing")
if r2~rows[1]["phrase"] \= "I don't believe you." then raise syntax 93.900 array("legacy public phrase changed")

say "PASS structured table talk persists beside unchanged legacy evidence"
call cleanTree root
exit 0

cleanTree: procedure
  use arg root
  call SysFileTree root || "/*", "oldFiles.", "FOS"
  do i = 1 to oldFiles.0; call SysFileDelete oldFiles.i; end
  call SysFileTree root || "/*", "oldDirs.", "DOS"
  do i = oldDirs.0 to 1 by -1; call SysRmDir oldDirs.i; end
  call SysRmDir root
  return

::requires "poker.cls"
::requires "experiment_store.cls"

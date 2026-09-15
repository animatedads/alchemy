parse arg root hands
if root = "" then root = "/tmp/hardworld-nosql75-hand-stress"
if hands = "" then hands = 10
call cleanTree root

s = .PlayerStrategy~new("stress",0.5,0,1)
a = .Player~new("A",1000,s)
b = .Player~new("B",1000,s)
c = .Player~new("C",1000,s)
d = .Player~new("D",1000,s)
players = .array~of(a,b,c,d)
t = .StressTable~new("stress-table",players)
store = .PokerExperimentStore~new(root,players)
store~beginExperiment("nosql75-hand-completion-stress")

do h = 1 to hands
  t~handNumber = h
  store~handStarted(t)
  /* deterministic chip-conserving movement; no evaluator or betting required */
  a~stack -= 1
  b~stack += 1
  store~handCompleted(t,"SHOWDOWN")
end

r1 = store~execute("SELECT COUNT(*) AS n FROM hand_result WHERE experiment_id=" || store~experimentId)
if r1~status \= .Error~SUCCESS then raise syntax 93.900 array("hand_result count query failed")
expected = hands * 4
if r1~rows[1]["n"] \= expected then raise syntax 93.900 array("unexpected hand_result row count")
r2 = store~execute("SELECT COUNT(*) AS n FROM bankroll_sample WHERE experiment_id=" || store~experimentId)
if r2~status \= .Error~SUCCESS then raise syntax 93.900 array("bankroll_sample count query failed")
if r2~rows[1]["n"] \= expected then raise syntax 93.900 array("unexpected bankroll row count")

say "PASS NoSQLServer v0.75 repeated hand_result/bankroll_sample native inserts"
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

::class StressTable
::attribute name
::attribute players
::attribute handNumber
::method init
  expose name players handNumber
  use arg name,players
  handNumber = 0

::requires "poker.cls"
::requires "experiment_store.cls"

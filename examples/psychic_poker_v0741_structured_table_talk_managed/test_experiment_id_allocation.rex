parse arg root
if root = "" then root = "/tmp/hardworld-experiment-id-test"

call SysFileTree root || "/*", "oldFiles.", "FOS"
do i = 1 to oldFiles.0
  call SysFileDelete oldFiles.i
end
call SysFileTree root || "/*", "oldDirs.", "DOS"
do i = oldDirs.0 to 1 by -1
  call SysRmDir oldDirs.i
end
call SysRmDir root

cfg = .GameConfig~new(5,10,1000,4,111)
strategy = .PlayerStrategy~new("test",0.5,0,1)
players1 = .array~of(.Player~new("A",1000,strategy), .Player~new("B",1000,strategy))
s1 = .PokerExperimentStore~new(root, players1)
if s1~experimentId <> 1 then raise syntax 93.900 array("first experiment id was not 1")
s1~beginExperiment("first")

players2 = .array~of(.Player~new("A",1000,strategy), .Player~new("B",1000,strategy))
s2 = .PokerExperimentStore~new(root, players2)
if s2~experimentId <> 2 then raise syntax 93.900 array("second experiment id was not 2")
s2~beginExperiment("second")

r = s2~execute("SELECT experiment_id,label FROM experiment ORDER BY experiment_id")
if r~status \= .Error~SUCCESS then raise syntax 93.900 array("experiment query failed")
if r~rows~items <> 2 then raise syntax 93.900 array("expected two experiment rows")
say "PASS experiment id allocation across reruns"
exit 0

::requires "poker.cls"
::requires "experiment_store.cls"

source = charin("experiment_store.cls",1,chars("experiment_store.cls"))
call charin "experiment_store.cls",1,0

if source~caselessPos("model~successfulHands") > 0 then
  raise syntax 93.900 array("stale Oracle v1 successfulHands getter remains")
if source~caselessPos("model~successfulActions") > 0 then
  raise syntax 93.900 array("stale Oracle v1 successfulActions getter remains")
if source~caselessPos("model~completedHands") = 0 then
  raise syntax 93.900 array("Oracle v2 completedHands getter missing")
if source~caselessPos("model~learnedActions") = 0 then
  raise syntax 93.900 array("Oracle v2 learnedActions getter missing")

say "PASS Oracle snapshot v2 interface"
exit 0

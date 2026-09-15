source = charin("experiment_store.cls",1,chars("experiment_store.cls"))
call charin "experiment_store.cls",1,0
if source~caselessPos("CREATE TABLE table_talk_structured") = 0 then raise syntax 93.900 array("structured table-talk relation missing")
if source~caselessPos('sr["utterance_id"]') = 0 then raise syntax 93.900 array("structured utterance id is not persisted")
if source~caselessPos('sr["communicative_act"]') = 0 then raise syntax 93.900 array("communicative act is not persisted")
if source~caselessPos('sr["intended_outcome"]') = 0 then raise syntax 93.900 array("intended outcome is not persisted")
say "PASS structured table-talk evidence has additive persistent relation"
exit 0

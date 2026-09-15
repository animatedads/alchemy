source=charin("experiment_store.cls",1,chars("experiment_store.cls"))
call charin "experiment_store.cls",1,0
if source~caselessPos('CREATE TABLE table_talk')=0 then raise syntax 93.900 array("table_talk relation missing")
if source~caselessPos("::method tableTalk")=0 then raise syntax 93.900 array("tableTalk observer method missing")
say "PASS table-talk persistent relation"
exit 0

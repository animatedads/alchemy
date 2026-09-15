source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
if source~caselessPos('self~log("TALK" speaker~name "->" target~name "[" || entry~talkClass') = 0 then
  raise syntax 93.900 array("public TALK formatter changed")
if source~caselessPos("structuredSummary") = 0 then raise syntax 93.900 array("structured evidence path absent")
say "PASS structured evidence is additive to the existing public TALK line"
exit 0

lib = .PokerTableTalkLibrarian~new
if lib~classify("I CAN SAY WHATEVER I LIKE") \== .nil then
  raise syntax 93.900 array("free-form text entered Librarian dictionary")

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class PokerStructuredTalkFactory")
q = source~caselessPos("::class PlayerStrategy",p)
text = source~substr(p,q-p)
if text~caselessPos("entry~phrase") = 0 then raise syntax 93.900 array("factory does not source text from frozen entry")
if text~caselessPos("use strict arg utteranceId, speaker, target, entry") = 0 then
  raise syntax 93.900 array("factory acquired an uncontrolled free-text argument")

say "PASS StructuredUtterance layer introduces no free-text speech channel"
exit 0
::requires "poker.cls"

lib = .PokerTableTalkLibrarian~new
factory = .PokerStructuredTalkFactory~new
speaker = .Player~new("Frank",1000,.PlayerStrategy~new("s",0.5,0.1,1.0))
target = .Player~new("GROK",1000,.PlayerStrategy~new("t",0.5,0.1,1.0))
entry = lib~classify("CALL_OUT")
u = factory~build("PP-TALK-TEST-1",speaker,target,entry)

if \u~sealed then raise syntax 93.900 array("structured table talk was not sealed")
if u~segments~items \= 1 then raise syntax 93.900 array("wrong segment count")
if u~acts~items \= 1 then raise syntax 93.900 array("wrong communicative-act count")
if u~generationIntents~items \= 1 then raise syntax 93.900 array("wrong generation-intent count")

seg = u~segments[1]
if seg~text \= "I don't believe you." then raise syntax 93.900 array("dictionary phrase changed")
if seg~primaryPurpose \= "CHALLENGE" then raise syntax 93.900 array("talk class not preserved as purpose")
act = u~acts[1]
if act~kind \= "CHALLENGE" then raise syntax 93.900 array("communicative act wrong")
intent = u~generationIntents[1]
if intent~intendedAct \= "CALL_OUT" then raise syntax 93.900 array("dictionary token not preserved as intended act")
if intent~intendedOutcome \= "CHALLENGE" then raise syntax 93.900 array("social intent outcome wrong")

say "PASS constrained table talk becomes sealed StructuredUtterance evidence"
exit 0
::requires "poker.cls"

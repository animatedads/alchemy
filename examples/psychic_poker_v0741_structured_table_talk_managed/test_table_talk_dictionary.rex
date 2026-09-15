lib = .PokerTableTalkLibrarian~new
if lib~tokenCount \= 12 then raise syntax 93.900 array("wrong table-talk dictionary size")
e = lib~classify("HARD_WORD")
if e == .nil then raise syntax 93.900 array("HARD_WORD missing")
if e~talkClass \= "PRESSURE" then raise syntax 93.900 array("HARD_WORD class wrong")
if lib~classify("SAY_ANYTHING_I_WANT") \== .nil then raise syntax 93.900 array("free text token accepted")
firstToken = lib~tokenAt(1)
if firstToken \= "HARD_WORD" then raise syntax 93.900 array("tokenAt no longer returns the frozen token")
firstEntry = lib~entryAt(1)
if firstEntry == .nil then raise syntax 93.900 array("entryAt failed")
if firstEntry~token \= firstToken then raise syntax 93.900 array("entryAt/tokenAt mismatch")
if firstEntry~pressureDelta <= 0 then raise syntax 93.900 array("entryAt did not return a classified entry")
say "PASS constrained table-talk dictionary"
exit 0
::requires "poker.cls"

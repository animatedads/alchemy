s = .ApexStrategy~new
p = .Player~new("Apex", 1000, s)
o = .Player~new("Needler", 1000, .PlayerStrategy~new("ordinary", 0.5, 0.1, 1.0))
t = .ApexTalkTestTable~new

needle = t~talkLibrarian~classify("TAKE_TIME")
p~receiveTableTalk(needle, o)
if p~lastTalkEntry \== needle then raise syntax 93.900 array("Apex lost talk entry provenance")
if p~lastTalkSpeaker \== o then raise syntax 93.900 array("Apex lost talk speaker provenance")

reply = s~chooseTalk(p, t, 10)
if \reply~hasMethod("ENTRY") then raise syntax 93.900 array("Apex retaliation did not return a table-talk choice")
if reply~entry~token \= "NOT_SCARED" then raise syntax 93.900 array("Apex did not counter a NEEDLE")
if reply~target \== o then raise syntax 93.900 array("Apex counter-talk did not target the offender")
if \p~lastTalkAnswered then raise syntax 93.900 array("Apex did not consume the retaliation trigger")

/* A challenge can lower the bounded aggression threshold without falsifying
   the equity value itself.  0.67 is below Apex's base 0.68 threshold. */
challenge = t~talkLibrarian~classify("CALL_OUT")
p~receiveTableTalk(challenge, o)
t~fixedEquity = 0.67
d = s~decide(p, t, 10, 20, .true)
if d~action \= "RAISE" then raise syntax 93.900 array("Apex did not convert bounded provocation into counter-aggression")
if d~equity \= 0.67 then raise syntax 93.900 array("Apex corrupted measured equity while reacting to talk")

/* Heavy turn action still has a hard anti-calling-station gate. */
t~fixedEquity = 0.49
t~fixedPot = 100
t~fixedStreet = "TURN"
d = s~decide(p, t, 80, 20, .true)
if d~action \= "FOLD" then raise syntax 93.900 array("Apex heavy-action gate failed")

say "PASS Apex v2 consumes talk provenance, counters the offender, and keeps discipline"
exit 0

::class ApexTalkTestTable public
::attribute fixedEquity
::attribute fixedPot
::attribute fixedStreet
::method init
  expose fixedEquity fixedPot fixedStreet librarian board
  fixedEquity = 0.67
  fixedPot = 100
  fixedStreet = "FLOP"
  librarian = .PokerTableTalkLibrarian~new
  board = .array~new
::method estimateEquity
  expose fixedEquity
  use arg player
  return fixedEquity
::method pot
  expose fixedPot
  return fixedPot
::method street
  expose fixedStreet
  return fixedStreet
::method board
  expose board
  return board
::method talkLibrarian
  expose librarian
  return librarian
::method randomInt
  use arg lo, hi
  return lo

::requires "poker.cls"

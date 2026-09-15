cfg = .GameConfig~new(5,10,1000,8,424242)
t = .PokerTable~new("ai-prompt",cfg)
fallback = .PlayerStrategy~new("fallback",0.5,0.05,1)
g = .Player~new("GEMINI",1000,fallback)
a = .Player~new("Ada",1000,fallback)
t~addPlayer(g); t~addPlayer(a)
g~receiveCard(.Card~new("A","S")); g~receiveCard(.Card~new("K","S"))
p = t~agentPrompt(g,10,10,.true)
if p~pos("You are GEMINI") = 0 then raise syntax 93.900 array("agent name not parameterized")
if p~caselessPos("psychic") > 0 then raise syntax 93.900 array("blind prompt leaked psychic term")
if p~caselessPos("team=") > 0 then raise syntax 93.900 array("blind prompt leaked team term")
say "PASS generic blind AI prompt"
exit 0
::requires "poker.cls"

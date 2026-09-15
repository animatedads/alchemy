config = .GameConfig~new(5,10,1000,8,424242)
t = .PokerTable~new("test", config)
fallback = .PlayerStrategy~new("fallback",0.5,0.05,1.0)
client = .GrokAPIClient~new("grok-4.5")
gs = .GrokPokerStrategy~new(client,fallback)
g = .Player~new("GROK",1000,gs)
a = .Player~new("Ada",1000,fallback)
t~addPlayer(g); t~addPlayer(a)
g~receiveCard(.Card~new("A","S")); g~receiveCard(.Card~new("K","S"))
p = t~agentPrompt(g,10,10,.true)
call assertContains p, "small blind: 5"
call assertContains p, "big blind: 10"
call assertContains p, "your cards: AS KS"
call assertContains p, "amount to call: 10"
call assertContains p, "raising permitted: YES"
call assertContains p, "ACTION=FOLD|CHECK|CALL|RAISE"
call assertContains p, "TALK=NONE|<one frozen token above>"
call assertContains p, "TALK_TARGET=NONE|<active opponent name>"
call assertContains p, "SOCIAL_EVIDENCE=NONE|<one displayed E-id>"
call assertContains p, "CALL_OUT [CHALLENGE]"
call assertAbsent p, "psychic"
call assertAbsent p, "non-psychic"
call assertAbsent p, "collusion"
call assertAbsent p, "cheating"
call assertAbsent p, "information advantage"
call assertAbsent p, "team="
call assertAbsent p, "strategy_type"
say "PASS Grok blind prompt contract"
exit 0
assertAbsent: procedure
  use arg text, needle
  if text~caselessPos(needle)>0 then raise syntax 93.900 array("forbidden prompt disclosure: "||needle)
  return 1

assertContains: procedure
  use arg text, needle
  if text~pos(needle)=0 then raise syntax 93.900 array("missing prompt field: "||needle)
  return 1
::requires "poker.cls"
::requires "ai_grok.cls"

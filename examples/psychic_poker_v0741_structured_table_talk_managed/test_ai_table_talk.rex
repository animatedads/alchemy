/* Live-agent table talk is selected by the same model decision, then constrained
   by PokerTableTalkLibrarian before anything reaches public hand history. */

cfg = .GameConfig~new(5, 10, 1000, 8, 62001)
t = .PokerTable~new("ai-talk", cfg)
t~verbose = .false
fallback = .AlwaysCallStrategy~new
client = .TalkFakeClient~new("CALL_OUT", "Ada")
grokStrategy = .GrokPokerStrategy~new(client, fallback)
grok = .Player~new("GROK", 1000, grokStrategy)
ada = .Player~new("Ada", 1000, fallback)
t~addPlayer(grok)
t~addPlayer(ada)
t~playHand

/* If the AI talk came from the same inference it must be in public history,
   addressed to the requested active target, and translated through Librarian. */
prompt = t~agentPrompt(grok, 0, 10, .true)
needle = 'TALK GROK -> Ada [CHALLENGE] "I don''t believe you."'
if prompt~pos(needle) = 0 then raise syntax 93.900 array("GROK model-selected table talk missing from public history")

/* Fallback decisions do not inherit PlayerStrategy random chatter. */
t2 = .PokerTable~new("ai-fallback-silent", .GameConfig~new(5, 10, 1000, 8, 62002))
t2~verbose = .false
nilClient = .NilFakeClient~new
fallback2 = .AlwaysCallStrategy~new
g2 = .Player~new("GROK", 1000, .GrokPokerStrategy~new(nilClient, fallback2))
a2 = .Player~new("Ada", 1000, fallback2)
t2~addPlayer(g2)
t2~addPlayer(a2)
t2~playHand
p2 = t2~agentPrompt(g2, 0, 10, .true)
if p2~pos("TALK GROK ->") > 0 then raise syntax 93.900 array("fallback puppet-GROK emitted random table talk")

/* Free-form/unknown tokens are rejected rather than becoming arbitrary speech. */
t3 = .PokerTable~new("ai-talk-reject", .GameConfig~new(5, 10, 1000, 8, 62003))
t3~verbose = .false
badClient = .TalkFakeClient~new("YOU_ARE_TERRIBLE", "Ada")
g3 = .Player~new("GROK", 1000, .GrokPokerStrategy~new(badClient, .AlwaysCallStrategy~new))
a3 = .Player~new("Ada", 1000, .AlwaysCallStrategy~new)
t3~addPlayer(g3)
t3~addPlayer(a3)
t3~playHand
p3 = t3~agentPrompt(g3, 0, 10, .true)
if p3~pos("YOU_ARE_TERRIBLE") > 0 then raise syntax 93.900 array("unknown/free-form AI talk escaped Librarian constraint")

/* Gemini uses the identical Decision talk channel. */
t4 = .PokerTable~new("gemini-talk", .GameConfig~new(5, 10, 1000, 8, 62004))
t4~verbose = .false
gemClient = .TalkFakeClient~new("NICE_HAND", "Ada")
gem = .Player~new("GEMINI", 1000, .GeminiPokerStrategy~new(gemClient, .AlwaysCallStrategy~new))
a4 = .Player~new("Ada", 1000, .AlwaysCallStrategy~new)
t4~addPlayer(gem)
t4~addPlayer(a4)
t4~playHand
p4 = t4~agentPrompt(gem, 0, 10, .true)
if p4~pos('TALK GEMINI -> Ada [RESPECT] "Nice hand."') = 0 then raise syntax 93.900 array("GEMINI model-selected table talk missing from public history")

say "PASS GROK/GEMINI same-inference constrained table-talk channel and silent fallback"
exit 0

::class TalkFakeClient public
::attribute model get
::method init
  expose model token target
  use arg token, target
  model = "fake-talk-model"
::method decide
  expose token target
  use arg prompt
  d = .directory~new
  d["action"] = "CALL"
  d["amount"] = 0
  d["talk"] = token
  d["talk_target"] = target
  return d

::class NilFakeClient public
::attribute model get
::method init
  expose model
  model = "fake-nil-model"
::method decide
  use arg prompt
  return .nil

::class AlwaysCallStrategy public subclass PlayerStrategy
::method init
  forward class (super) array("always-call", 0.5, 0, 1.0)
::method decide
  use arg player, table, toCall, minRaise, canRaise = .true
  if toCall = 0 then return .Decision~new("CHECK", 0, 0.5, 0)
  return .Decision~new("CALL", toCall, 0.5, 0)

::requires "poker.cls"
::requires "ai_gemini.cls"

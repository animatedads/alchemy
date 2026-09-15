env = .PokerPromptEnvelope~new("GROK")
env~append("GAME.POT", "PUBLIC", "pot: 50" || "0a"x)
env~append("SELF.HOLE_CARDS", "CUSTOMER", "your cards: AS KS" || "0a"x)
prompt = env~finalize
audit = env~auditSummary
if audit["boundary_status"] \= "PASS" then raise syntax 93.900 array("prompt boundary did not pass")
if audit["field_count"] \= 2 then raise syntax 93.900 array("prompt field count wrong")
if audit["public_fields"] \= 1 then raise syntax 93.900 array("public prompt field count wrong")
if audit["customer_fields"] \= 1 then raise syntax 93.900 array("viewer-private prompt field count wrong")
if audit["rejected_fields"] \= 0 then raise syntax 93.900 array("clean prompt recorded rejected fields")
if audit["prompt_length"] \= prompt~length then raise syntax 93.900 array("prompt length evidence mismatch")

if \expectRejected(.PokerPromptEnvelope~new("GROK"), "RNG.STATE", "SECRET", "12345") then
  raise syntax 93.900 array("SECRET RNG state was not rejected")
if \expectRejected(.PokerPromptEnvelope~new("GROK"), "OBSERVER.SEAT_CARDS", "PUBLIC", "seat 2 cards=AH AD") then
  raise syntax 93.900 array("observer provenance was not rejected")
if \expectRejected(.PokerPromptEnvelope~new("GROK"), "PUBLIC.HISTORY.EVENT", "PUBLIC", "  seat 2 cards=AH AD") then
  raise syntax 93.900 array("observer-style cards material was not rejected from public history")
if \expectRejected(.PokerPromptEnvelope~new("GROK"), "OTHER_PRIVATE.HOLE_CARDS", "CUSTOMER", "AH AD") then
  raise syntax 93.900 array("other-player private state was not rejected")

cfg = .GameConfig~new(5,10,100,10,12345)
t = .PokerTable~new("prompt-boundary", cfg)
t~verbose = .false
s1 = .PromptCaptureStrategy~new
s2 = .PromptCaptureStrategy~new
t~addPlayer(.Player~new("A",100,s1))
t~addPlayer(.Player~new("B",100,s2))
t~playHand
captured = s1~lastPrompt
viewer = "A"
if captured = "" then do
  captured = s2~lastPrompt
  viewer = "B"
end
if captured = "" then raise syntax 93.900 array("runtime prompt not captured")
runtimeAudit = t~promptAuditFor(viewer, .true)
if runtimeAudit == .nil then raise syntax 93.900 array("runtime prompt audit missing")
if runtimeAudit["boundary_status"] \= "PASS" then raise syntax 93.900 array("runtime prompt boundary failed")
if runtimeAudit["customer_fields"] \= 1 then raise syntax 93.900 array("runtime prompt should contain exactly one CUSTOMER field: viewer hole cards")
if runtimeAudit["rejected_fields"] \= 0 then raise syntax 93.900 array("runtime prompt admitted rejected material")
if runtimeAudit["history_fields"] < 1 then raise syntax 93.900 array("runtime public history was not provenance-counted")
if runtimeAudit["prompt_length"] \= captured~length then raise syntax 93.900 array("runtime prompt length evidence mismatch")
if t~promptStrongDigestFor(viewer,.true) \= .SHA512~new(captured)~digest then raise syntax 93.900 array("runtime strong prompt digest does not identify captured bytes")
if captured~caselessPos("  seat") > 0 then raise syntax 93.900 array("observer seat narration leaked into runtime prompt")

say "PASS fail-closed AI prompt disclosure/provenance boundary"
exit 0

expectRejected: procedure
  use arg envelope, source, disclosure, text
  signal on syntax name rejected
  envelope~append(source, disclosure, text)
  signal off syntax
  return .false
rejected:
  signal off syntax
  return .true

::class PromptCaptureStrategy public subclass PlayerStrategy
::attribute lastPrompt get
::method init
  expose lastPrompt
  forward class (super) array("prompt-capture",0.5,0,1.0) continue
  lastPrompt = ""
::method decide
  expose lastPrompt
  use arg player, table, toCall, minRaise, canRaise=.true
  lastPrompt = table~agentPrompt(player,toCall,minRaise,canRaise)
  if toCall > 0 then return .Decision~new("FOLD",0,0.5,0)
  return .Decision~new("CHECK",0,0.5,0)

::requires "poker.cls"

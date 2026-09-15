/* Quick Gemini prompt / API probe.
   Prints exactly what GEMINI would see in a representative preflop spot.
   If GEMINI_API_KEY is set, also sends the prompt to the real Gemini client. */

cfg = .GameConfig~new(5, 10, 1000, 8, 987654)
table = .PokerTable~new("gemini-prompt-probe", cfg)

fallback = .ResourceAwareStrategy~new
geminiClient = .GeminiAPIClient~new
geminiStrategy = .GeminiPokerStrategy~new(geminiClient, fallback)

ada = .Player~new("Ada", 1000, .PlayerStrategy~new("balanced", 0.50, 0.08, 1.00))
grok = .Player~new("GROK", 1000, .PlayerStrategy~new("balanced", 0.50, 0.08, 1.00))
gemini = .Player~new("GEMINI", 1000, geminiStrategy)
hugo = .Player~new("Hugo", 1000, .AggressiveStrategy~new)
eve = .PsychicPlayer~new("Eve", 1000, .PsychicTeamStrategy~new("psi-team", 0.55, 0.10, 1.10), "RED")
frank = .PsychicPlayer~new("Frank", 1000, .PsychicTeamStrategy~new("psi-team", 0.55, 0.10, 1.10), "RED")

table~addPlayer(ada)
table~addPlayer(grok)
table~addPlayer(gemini)
table~addPlayer(hugo)
table~addPlayer(eve)
table~addPlayer(frank)

/* Representative state:
   GEMINI holds Qs Jh, faces 10 chips to call preflop. */
gemini~receiveCard(.Card~new("Q", "S"))
gemini~receiveCard(.Card~new("J", "H"))

prompt = table~agentPrompt(gemini, 10, 10, .true)

say "=== GEMINI PROMPT ==="
say prompt
say "=== END PROMPT ==="
say ""

forbidden = .array~of("psychic", "non-psychic", "team=", "collusion", "cheating")
do term over forbidden
  if prompt~caselessPos(term) > 0 then do
    say "FAIL prompt leaks forbidden term:" term
    exit 1
  end
end

if prompt~pos("your cards: QS JH") = 0 then do
  say "FAIL expected hole cards missing"
  exit 1
end
if prompt~pos("small blind: 5") = 0 | prompt~pos("big blind: 10") = 0 then do
  say "FAIL blind values missing"
  exit 1
end
if prompt~pos("amount to call: 10") = 0 then do
  say "FAIL to-call value missing"
  exit 1
end
if prompt~pos("TALK=NONE|<one frozen token above>") = 0 then do
  say "FAIL table-talk token contract missing"
  exit 1
end
if prompt~pos("TALK_TARGET=NONE|<active opponent name>") = 0 then do
  say "FAIL table-talk target contract missing"
  exit 1
end
if prompt~pos("SOCIAL_EVIDENCE=NONE|<one displayed E-id>") = 0 then do
  say "FAIL social-evidence attribution contract missing"
  exit 1
end

say "PASS prompt contract"
say ""

apiKey = value("GEMINI_API_KEY",, "ENVIRONMENT")
if apiKey = "" then do
  say "GEMINI_API_KEY not set; live API call skipped."
  exit 0
end

say "=== LIVE GEMINI RESPONSE ==="
reply = geminiClient~decide(prompt)
if reply == .nil then do
  say "FAIL Gemini API/client returned no parsed decision."
  exit 2
end

say "ACTION=" || reply["action"]
say "AMOUNT=" || reply["amount"]
say "TALK=" || reply["talk"]
say "TALK_TARGET=" || reply["talk_target"]
say "PASS live Gemini prompt probe"
exit 0

::requires "poker.cls"
::requires "ai_gemini.cls"

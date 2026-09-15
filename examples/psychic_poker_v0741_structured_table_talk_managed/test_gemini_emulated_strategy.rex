s = .GeminiEmulatedStrategy~new
if s~strategyType \= "AI_GEMINI_EMULATED" then
  raise syntax 93.900 array("wrong emulated Gemini strategy type")
if s~risk \= 0.45 then raise syntax 93.900 array("wrong risk")
if s~bluff \= 0.15 then raise syntax 93.900 array("wrong bluff")
if s~aggression \= 1.40 then raise syntax 93.900 array("wrong aggression")
say "PASS Gemini emulated strategy parameters"
exit 0
::requires "poker.cls"

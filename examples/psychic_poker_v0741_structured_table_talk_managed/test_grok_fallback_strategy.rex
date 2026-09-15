s = .GrokFallbackStrategy~new
if s~strategyType \= "GROK_FALLBACK" then raise syntax 93.900 array("wrong GROK fallback type")
if s~risk \= 0.22 then raise syntax 93.900 array("wrong fallback risk")
if s~bluff \= 0.03 then raise syntax 93.900 array("wrong fallback bluff")
if s~aggression \= 1.15 then raise syntax 93.900 array("wrong fallback aggression")

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class GrokFallbackStrategy")
q = source~caselessPos("::class GrokPokerStrategy",p)
frag = source~substr(p,q-p)
if frag~pos(" & ") > 0 then raise syntax 93.900 array("fallback contains non-short-circuit & guard")
if frag~pos(" | ") > 0 then raise syntax 93.900 array("fallback contains non-short-circuit | guard")
runner = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0
if runner~caselessPos("grokFallback = .GrokFallbackStrategy~new") = 0 then raise syntax 93.900 array("runner not wired to fallback")
if source~caselessPos('GROK FALLBACK active') = 0 then raise syntax 93.900 array("fallback marker missing")

say "PASS GROK fallback parameters, guard safety and wiring"
exit 0
::requires "poker.cls"

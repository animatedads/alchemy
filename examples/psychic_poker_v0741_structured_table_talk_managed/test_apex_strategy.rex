s = .ApexStrategy~new
if s~strategyType \= "APEX" then raise syntax 93.900 array("wrong Apex strategy type")
if s~risk \= 0.45 then raise syntax 93.900 array("wrong Apex risk")
if s~bluff \= 0.15 then raise syntax 93.900 array("wrong Apex bluff")
if s~aggression \= 1.40 then raise syntax 93.900 array("wrong Apex aggression")

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class ApexStrategy")
q = source~caselessPos("::class GeminiEmulatedStrategy", p)
apexText = source~substr(p, q - p)
if apexText~pos(" & ") > 0 then raise syntax 93.900 array("Apex contains non-short-circuit & guard")
if apexText~pos(" | ") > 0 then raise syntax 93.900 array("Apex contains non-short-circuit | guard")

if \s~handlesTableTalkPsychology then raise syntax 93.900 array("Apex must own its table-talk psychology")
say "PASS Apex v2 parameters, psychology ownership and guard safety"
exit 0
::requires "poker.cls"

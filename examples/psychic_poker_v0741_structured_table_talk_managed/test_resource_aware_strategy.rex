s = .ResourceAwareStrategy~new
if s~strategyType \= "RESOURCE_AWARE" then raise syntax 93.900 array("wrong resource-aware type")
if s~risk \= 0.50 then raise syntax 93.900 array("wrong resource-aware risk")
if s~bluff \= 0.25 then raise syntax 93.900 array("wrong resource-aware bluff")
if s~aggression \= 1.10 then raise syntax 93.900 array("wrong resource-aware aggression")
say "PASS resource-aware strategy parameters"
exit 0
::requires "poker.cls"

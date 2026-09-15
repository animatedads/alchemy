s = .AggressiveStrategy~new
if s~strategyType <> "AGGRESSIVE" then raise syntax 93.900 array("wrong strategy type")
if s~risk <> 0.72 then raise syntax 93.900 array("wrong risk")
if s~bluff <> 0.38 then raise syntax 93.900 array("wrong bluff")
if s~aggression <> 1.65 then raise syntax 93.900 array("wrong aggression")
say "PASS aggressive strategy parameters"
exit 0
::requires "poker.cls"

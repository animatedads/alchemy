s = .PsychicAggressiveStrategy~new
if s~strategyType <> "PSYCHIC_AGGRESSIVE" then raise syntax 93.900 array("wrong strategy type")
if s~risk <> 0.68 then raise syntax 93.900 array("wrong risk")
if s~bluff <> 0.30 then raise syntax 93.900 array("wrong bluff")
if s~aggression <> 1.55 then raise syntax 93.900 array("wrong aggression")
say "PASS psychic aggressive strategy parameters"
exit 0
::requires "poker.cls"

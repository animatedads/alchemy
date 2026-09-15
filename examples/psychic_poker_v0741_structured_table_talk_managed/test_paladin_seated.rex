source = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0
if source~caselessPos('paladin = .Player~new("Paladin", 1000, paladinStrategy)') = 0 then raise syntax 93.900 array("Paladin player missing")
if source~caselessPos('apexBot, paladin, benny') = 0 then raise syntax 93.900 array("Paladin not in randomized seat candidates")
s = .PaladinStrategy~new
if s~strategyType \= "PALADIN" then raise syntax 93.900 array("wrong Paladin strategy type")
say "PASS Paladin seated contract"
::requires "poker.cls"

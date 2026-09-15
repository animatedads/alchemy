s = .BlindPsychicStrategy~new
if s~strategyType \= "BLIND_PSYCHIC" then raise syntax 93.900 array("wrong Benny strategy type")

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class BlindPsychicStrategy")
q = source~caselessPos("::class PsychicEquityStrategy",p)
bennyText = source~substr(p,q-p)

if bennyText~caselessPos("player~hole") > 0 then
  raise syntax 93.900 array("Blind Benny strategy reads own hole cards")
if bennyText~caselessPos("estimateBlindPsychicEquity") = 0 then
  raise syntax 93.900 array("Blind Benny does not use blind equity estimator")

say "PASS Blind Benny own-card blindness contract"
exit 0
::requires "poker.cls"

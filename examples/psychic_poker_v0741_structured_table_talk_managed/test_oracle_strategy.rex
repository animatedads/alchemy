s = .OracleStrategy~new
if s~strategyType \= "THE_ORACLE" then raise syntax 93.900 array("wrong Oracle strategy type")

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0
p = source~caselessPos("::class OracleHistoryModel")
q = source~caselessPos("::class ApexStrategy",p)
oracleText = source~substr(p,q-p)

if oracleText~caselessPos("ORACLE_ACTION_VALUE_V2") = 0 then
  raise syntax 93.900 array("Oracle v2 model marker missing")
if oracleText~caselessPos("profit>0") > 0 then
  raise syntax 93.900 array("Oracle still learns winners only")
if oracleText~caselessPos("knownCardsFor") > 0 then
  raise syntax 93.900 array("Oracle reads privileged current cards")
if oracleText~caselessPos("psychicObservation") > 0 then
  raise syntax 93.900 array("Oracle reads psychic observations")
if oracleText~caselessPos("historyModel~refresh") = 0 then
  raise syntax 93.900 array("Oracle is not adaptive within experiment")

say "PASS Oracle v2 signed-history, honesty and adaptive refresh"
exit 0
::requires "poker.cls"

source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0

p = source~caselessPos("::class OracleHistoryModel")
q = source~caselessPos("::class OracleStrategy",p)
if p = 0 | q = 0 then raise syntax 93.900 array("OracleHistoryModel source region missing")
text = source~substr(p,q-p)

if text~pos('if row["psychic"] then') > 0 then
  raise syntax 93.900 array("Oracle uses database boolean directly as Rexx logical")

if text~caselessPos('psychicValue = translate(strip("" || row["psychic"]))') = 0 then
  raise syntax 93.900 array("Oracle database boolean normalization missing")

if text~caselessPos('psychicValue = "TRUE"') = 0 then
  raise syntax 93.900 array("Oracle TRUE-string handling missing")

if text~caselessPos('psychicValue = "1"') = 0 then
  raise syntax 93.900 array("Oracle numeric-boolean handling missing")

say "PASS Oracle database boolean normalization"
exit 0

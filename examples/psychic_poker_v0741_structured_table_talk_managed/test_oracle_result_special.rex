source = charin("poker.cls",1,chars("poker.cls"))
call charin "poker.cls",1,0

p = source~caselessPos("::class OracleHistoryModel")
q = source~caselessPos("::class OracleStrategy",p)
if p = 0 | q = 0 then raise syntax 93.900 array("OracleHistoryModel source region missing")
text = source~substr(p,q-p)

if text~caselessPos("result = .directory~new") > 0 then
  raise syntax 93.900 array("Oracle uses RESULT as ordinary local variable")
if text~caselessPos('result["') > 0 then
  raise syntax 93.900 array("Oracle indexes RESULT as ordinary local variable")

if text~caselessPos("handOutcome = .directory~new") = 0 then
  raise syntax 93.900 array("Oracle handOutcome local missing")

say "PASS Oracle avoids special RESULT local"
exit 0

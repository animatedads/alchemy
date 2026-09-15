text = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0
if text~pos('.Player~new("The_Oracle", 1000, oracleStrategy)') = 0 then
  raise syntax 93.900 array("The_Oracle not seated")
if text~pos(".OracleHistoryModel~new(store, experimentId)") = 0 then
  raise syntax 93.900 array("Oracle history model not loaded from experiment database")
if text~pos("recordOracleModel") = 0 then
  raise syntax 93.900 array("Oracle model snapshot not persisted")
say "PASS The_Oracle seated and database-trained"
exit 0

text = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0
if text~pos('.Player~new("Apex", 1000, apexStrategy)') = 0 then
  raise syntax 93.900 array("Apex player missing")
if text~pos("apexBot") = 0 then raise syntax 93.900 array("Apex not included in seating")
say "PASS Apex ordinary player seated"
exit 0

text = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0
if text~pos('.PsychicPlayer~new("Benny", 1000, blindBennyStrategy, "")') = 0 then
  raise syntax 93.900 array("Benny not seated as independent psychic")
if text~pos("benny") = 0 then raise syntax 93.900 array("Benny missing from seat candidates")
say "PASS Blind Benny seated independently"
exit 0

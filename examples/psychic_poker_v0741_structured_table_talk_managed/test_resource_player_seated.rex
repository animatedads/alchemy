text = charin("grok_experiment.rex",1,chars("grok_experiment.rex"))
call charin "grok_experiment.rex",1,0

if text~pos('.Player~new("Rosa", 1000, resourceAwareStrategy)') = 0 then
  raise syntax 93.900 array("Rosa resource-aware player missing")
if text~pos("ResourceAwareStrategy~new") = 0 then
  raise syntax 93.900 array("ResourceAwareStrategy not instantiated")
if text~pos("rosa") = 0 then
  raise syntax 93.900 array("Rosa not included in runner")

say "PASS resource-aware ordinary player seated"
exit 0

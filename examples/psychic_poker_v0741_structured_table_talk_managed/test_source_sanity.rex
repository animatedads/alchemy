files = .array~of("grok_experiment.rex","experiment.rex","batch_experiment.rex")
do f over files
  if stream(f,"c","query exists") = "" then iterate
  text = charin(f,1,chars(f))
  call charin f,1,0
  if text~pos("\n") > 0 then do
    say "FAIL literal backslash-n in" f
    exit 1
  end
end
say "PASS source sanity"
exit 0

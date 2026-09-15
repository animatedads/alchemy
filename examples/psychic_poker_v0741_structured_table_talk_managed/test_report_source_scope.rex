files = .array~of("grok_experiment.rex","experiment.rex","batch_experiment.rex")
tables = .array~of("action_log","hand_result","psychic_capability","psychic_observation","pot_settlement")
do file over files
  if stream(file,"c","query exists") = "" then iterate
  text = charin(file,1,chars(file))
  call charin file,1,0
  do table over tables
    pos = 1
    do forever
      p = text~caselessPos("FROM " || table, pos)
      if p = 0 then leave
      e = text~pos('")', p)
      if e = 0 then e = min(text~length, p + 1000)
      fragment = text~substr(p, e-p+1)
      if fragment~caselessPos("experiment_id") = 0 then do
        say "FAIL unscoped report:" file table
        exit 1
      end
      pos = p + 1
    end
  end
end
say "PASS report source scope"
exit 0

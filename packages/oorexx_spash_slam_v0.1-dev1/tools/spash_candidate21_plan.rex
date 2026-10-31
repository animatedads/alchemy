/* SPASH: use the *existing* Audio V9 ooRexx virtual mic writer. */
parse arg inputPath outputPath
if inputPath='' | outputPath='' then do
  say 'usage: spash_candidate21_plan.rex SPECTRAL_TRACKS.tsv PLAN.tsv'
  exit 2
end
writer=.AudioV9VirtualMicPlanWriter~new
count=writer~writeFromSpectralTracks(inputPath,outputPath)
if count<1 then do
  say 'NOT_APPLICABLE no admitted measured coherent-path plan points'
  exit 3
end
say 'PASS SPASH source-measured plan points='count
exit 0
::requires 'AudioV9Multipath.cls'

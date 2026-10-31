/* SPASH: delegate exact-path planning to Audio V9 Candidate21.
 * Source data and measured spectral trajectory are produced by owner native code.
 */
parse arg inputPath outputPath
if inputPath='' | outputPath='' then do
  say 'usage: spash_candidate21_plan.rex TRACKS.tsv PLAN.tsv'
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

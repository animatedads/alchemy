/* Bounded original video PTS to four native movement-window views. */
parse arg raw run out
if raw=='' | run=='' | out=='' then do
  say 'Usage: rexx spash_raw_visual_stream.rex SOURCE.samples.tsv SOURCE.run.tsv OUTPUT.tsv'
  exit 2
end
job=.SpashRawVisualStream~new
result=job~scan(raw,run,out)
say 'SPASH_PTS_STREAM_PASS SAMPLES='job~count 'WINDOWS='result 'AUDIO_CLOCK=NOT_ALIGNED'
exit 0
::requires 'SpashRawVisualStream.cls'
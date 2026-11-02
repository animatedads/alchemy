/* Usage rexx measure_ptz_cycle.rex decoded_96x54_1fps.gray */
parse arg raw
if raw='' then do
 say 'Usage: rexx measure_ptz_cycle.rex 1fps_96x54.gray'
 exit 2
end
c=.HarbourPtzCycle~new
n=c~readRaw(raw)
r=c~estimate(150,185,60)
say 'source_frames='n
say 'period_seconds='r['PERIOD_SECONDS']
say 'mean_abs_8bit='r['MEAN_ABS_8BIT']
say 'runner_up_mean_abs_8bit='r['RUNNER_UP_MEAN_ABS_8BIT']
say 'overlap_pairs='r['OVERLAP_PAIRS']
say 'status='r['STATUS']
if n<200 | r['PERIOD_SECONDS']=0 then exit 2

::requires 'SlamHarbourPtzCycle.cls'
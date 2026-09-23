numeric digits 30
parse arg aPath bPath outF32 planPath
if planPath='' then do
  say 'usage: render_reconstruction_chunk.rex FC.f32 FD.f32 OUT.f32 PLAN.tsv'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
provider=.AudioV9SpatialNativeProvider~new(root||'/run/native/av9_spatial.bridge.json')
aBytes=stream(aPath,'C','QUERY SIZE'); bBytes=stream(bPath,'C','QUERY SIZE')
if aBytes<=0 | bBytes<=0 then do; say 'FAIL empty reconstruction input'; exit 2; end
if aBytes<>bBytes then do; say 'FAIL paired reconstruction geometry differs'; exit 2; end
if aBytes//4<>0 then do; say 'FAIL f32 geometry not divisible by 4'; exit 2; end
samples=aBytes/4
/* Production reconstruction is deliberately local.  Eight-second evidence windows
 * advance every two seconds so clock/TDOA drift is re-estimated continuously and
 * no campaign-global file-edge correction is required for dual-feed fusion. */
scan=provider~scan(aPath,bPath,8000,8000,2000,500,25)
policy=.AudioV9SoftReconstructionPolicy~new(.06,.92,32,0,.15,.35,7,3)
plan=.AudioV9SoftReconstructionPlanner~new(policy)~fromScan(scan,samples)
plan~write(planPath)
provider~renderPlan(aPath,bPath,planPath,outF32,800)
if stream(outF32,'C','QUERY SIZE')<>aBytes then do; say 'FAIL reconstruction changed sample geometry'; exit 2; end
say 'PASS reconstruction render samples='||samples||' rows='||plan~items||' out='||outF32||' plan='||planPath
exit 0
::requires 'AudioV9SoftReconstruction.cls'

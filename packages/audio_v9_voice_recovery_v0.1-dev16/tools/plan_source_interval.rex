numeric digits 30
parse arg feed startSecond endSecond edgeMapPath
if feed='' | startSecond='' | endSecond='' then do
  say 'usage: plan_source_interval.rex FC|FD START_SERIAL END_SERIAL [FILE_EDGE_CALIBRATION.tsv]'
  exit 2
end
root=value('AUDIO_V9_VOICE_ROOT',,'ENVIRONMENT'); if root='' then root='.'
f=feed~lower
if f='fc' then listPath=root||'/campaign/FC_FILES.txt'
else if f='fd' then listPath=root||'/campaign/FD_FILES.txt'
else do; say 'FAIL feed must be FC or FD'; exit 2; end
names=.array~new
do while lines(listPath)>0; line=linein(listPath)~strip; if line<>'' then names~append(line); end
call stream listPath,'C','CLOSE'
if edgeMapPath='' then edgeMapPath=value('AUDIO_V9_FILE_EDGE_MAP',,'ENVIRONMENT')
if edgeMapPath='' then do
  candidate=root||'/campaign/FILE_EDGE_CALIBRATION.tsv'
  if stream(candidate,'C','QUERY EXISTS')<>'' then edgeMapPath=candidate
end
if edgeMapPath<>'' then edgeMap=.AudioV9FileEdgeCalibrationMap~fromFile(edgeMapPath)
else edgeMap=.AudioV9FileEdgeCalibrationMap~new
clock=.AudioV9CalibratedSourceClock~new(f,names,8000,edgeMap)
slices=clock~slices(startSecond+0,endSecond+0)
say 'feed'||'09'x||'name'||'09'x||'nominal_source_start'||'09'x||'effective_source_start_sample'||'09'x||'slice_start_sample'||'09'x||'slice_end_sample'||'09'x||'offset_samples'||'09'x||'expected_samples'||'09'x||'correction_samples'||'09'x||'edge_status'
do s over slices
  say s~feed||'09'x||s~name||'09'x||s~nominalSourceStart||'09'x||s~effectiveSourceStartSample||'09'x||s~sliceStartSample||'09'x||s~sliceEndSample||'09'x||s~offsetSamples||'09'x||s~expectedSamples||'09'x||s~correctionSamples||'09'x||s~edgeStatus
end
exit 0
::requires 'AudioV9FileEdgeCalibration.cls'

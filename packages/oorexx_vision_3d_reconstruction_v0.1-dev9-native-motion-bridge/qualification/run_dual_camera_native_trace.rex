parse arg traceFile
if traceFile='' then traceFile='DUAL_CAMERA_NATIVE_5BIT_TRACE.json'
root=.json~fromJsonFile(traceFile)
a=root['video_A']; b=root['video_B']
adapter=.VisionRecordedMotionTraceAdapter~new
/* Keep the replay smoke bounded; the retained JSON contains the complete trace. */
limit=180
ca=adapter~constraintsFromVideoNode(a,limit)
cb=adapter~constraintsFromVideoNode(b,limit)
say 'A fps' a['fps'] 'constraints' ca~items
say 'B fps' b['fps'] 'constraints' cb~items
say 'fuzzy lag A-after-B' root['consensus_lag_frames_A_after_B']
if ca~items<>limit | cb~items<>limit then do; say 'FAIL trace replay count'; exit 1; end
if ca[1]~maxDistanceM>3*a['steps'][1]['dt']+0.000001 then do; say 'FAIL A speed envelope'; exit 1; end
if cb[1]~maxDistanceM>3*b['steps'][1]['dt']+0.000001 then do; say 'FAIL B speed envelope'; exit 1; end
say 'PASS recorded native trace replay'
::requires 'Vision3DNativeMotion.cls'
::requires 'json.cls'

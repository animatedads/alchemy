/* Single-file FC camera-event worker entry point. */
parse arg sourcePath outputPrefix .
if sourcePath == '' | outputPrefix == '' then do
  say 'usage: rexx analyse_fc_camera_events.rex INPUT.mp4 OUTPUT_PREFIX'
  say 'writes .camera_events.tsv .events.tsv .samples.tsv .scene.tsv .window.tsv .reflections.tsv .run.tsv'
  exit 2
end

cfg = .FCVehicleMotionConfig~new
analyzer = .FCVehicleMotionAnalyzer~new(sourcePath,cfg)
analysis = analyzer~analyze
if analysis~status \== 'OK' then do
  say 'FC_CAMERA_EVENTS_ERROR status=' || analysis~status || ' source=' || sourcePath
  exit 3
end
paths = .FCVehicleMotionAnalyzer~writeOutputs(analysis,outputPrefix)
say 'FC_CAMERA_EVENTS_OK source=' || analysis~sourceName ||,
    ' traffic=' || analysis~eventCount ||,
    ' window_intervals=' || analysis~windowIntervalCount ||,
    ' reflections=' || analysis~reflectionEventCount ||,
    ' uncertain_motion=' || analysis~uncertainCount ||,
    ' duration_ms=' || trunc(analysis~lastRelativeMs+0.5)
exit 0

::requires 'FCVehicleMotion.cls'

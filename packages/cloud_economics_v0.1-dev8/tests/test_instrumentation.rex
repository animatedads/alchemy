identity=.InstrumentationCodec~identity('alchemy','cloud-economics','cloud-economics-test','test-host','','Cloud Economics')
telemetry=.CloudEconomicsInstrumentation~new(identity)
telemetry~observed(2,21)
d=.directory~new; d['status']='PAPER_BUY'
telemetry~evaluated(d)
d['status']='PAPER_HOLD'; telemetry~evaluated(d)
d['status']='NO_ELIGIBLE_OPTION'; telemetry~evaluated(d)
snapshot=telemetry~snapshot('2026-10-08T11:00:00Z')
if snapshot['samples']~items<8 then do
  say 'FAIL Cloud Economics instrumentation missing metrics'; exit 1
end
if snapshot['identity']['instance_id']\='cloud-economics-test' then do
  say 'FAIL Cloud Economics instrumentation identity'; exit 1
end
say 'PASS instrumentation.mesh/0.1 Cloud Economics optional adapter'
exit 0
::requires 'CloudEconomicsInstrumentation.cls'
::requires 'InstrumentationMesh.cls'

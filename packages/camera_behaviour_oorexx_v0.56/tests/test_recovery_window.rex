/* All timing and track inputs below are synthetic. */
gate=.CameraRecoveryWindow~new(5,100)
rows=.array~new
do i=1 to 5
  rows~append(makeRow(i*33,'SYNTHETIC-A','G1','T1'))
end
call expect gate~inspect(rows), 'ADMITTED', 'SOURCE_NATIVE_TRACK'
rows[3]['GENERATION']='G2'
call expect gate~inspect(rows), 'REJECTED', 'GENERATION_BARRIER'
rows[3]['GENERATION']='G1'
rows[3]['SOURCE']='SYNTHETIC-B'
call expect gate~inspect(rows), 'REJECTED', 'SOURCE_BARRIER'
rows[3]['SOURCE']='SYNTHETIC-A'
rows[3]['TRACK']='T2'
call expect gate~inspect(rows), 'REJECTED', 'TRACK_CHANGE'
rows[3]['TRACK']='T1'
rows[3]['PTS_MS']=rows[2]['PTS_MS']
call expect gate~inspect(rows), 'REJECTED', 'NONMONOTONIC_PTS'
rows[3]['PTS_MS']=500
call expect gate~inspect(rows), 'REJECTED', 'TEMPORAL_GAP'
rows[3]['PTS_MS']=99
rows[3]['ADMITTED']=.false
call expect gate~inspect(rows), 'REJECTED', 'TRACK_NOT_ADMITTED'
rows[3]['ADMITTED']=.true
short=.array~of(rows[1],rows[2])
call expect gate~inspect(short), 'REJECTED', 'INSUFFICIENT_FRAMES'
say 'CAMERA_RECOVERY_WINDOW 8/8 PASS'
exit 0
::routine makeRow
  use strict arg pts,source,generation,track
  r=.directory~new
  r['PTS_MS']=pts
  r['SOURCE']=source
  r['GENERATION']=generation
  r['TRACK']=track
  r['ADMITTED']=.true
  return r
::routine expect
  use strict arg decision, status, reason
  if decision~status<>status then raise syntax 93.900 array('FAIL status',status,decision~status)
  if decision~reason<>reason then raise syntax 93.900 array('FAIL reason',reason,decision~reason)
::requires 'CameraRecoveryWindow.cls'

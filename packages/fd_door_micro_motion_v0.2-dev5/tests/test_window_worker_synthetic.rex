/* Exercise seeked analysis window plus an absolute-wall exclusion. */
parse arg root .
if root='' then root='.'
source=root||'/tests/synthetic_night_tiny.mp4'
prefix=root||'/qualification/window_synthetic'
stateDir=root||'/qualification/window_synthetic_state'
address system 'rm -rf '||quote(stateDir)||' '||quote(prefix)||'.*'
cfg=.FDDoorMicroMotionConfig~nightF11
cfg~setWallWindow('2023-10-10T00:00:00','2023-10-10T00:00:01','2023-10-10T00:00:05')
cfg~addWallExclusion('FDXTEST','2023-10-10T00:00:02','2023-10-10T00:00:03','USER_DECLARED_SCENE_OCCLUSION')
w=.FDDoorMicroMotionWorker~new(source,cfg,prefix,stateDir,'test:window-synthetic')
status=w~run
if status<>'OK' then call fail 'worker status='||status

run=readOne(prefix||'.run.tsv')
if run==.nil then call fail 'run missing'
if run['analysis_start_ms']<>1000 then call fail 'run analysis start='||run['analysis_start_ms']
if run['analysis_end_ms']<>5000 then call fail 'run analysis end='||run['analysis_end_ms']
if run['wall_clock_origin']<>'2023-10-10T00:00:00.000' then call fail 'run wall origin='||run['wall_clock_origin']
if (run['excluded_frames']+0)<=0 then call fail 'no excluded frames'

inp=.CSVStream~new(prefix||'.samples.tsv',.false); inp~delimiter='09'x; inp~open('read')
if inp~state<>'READY' then call fail 'samples open'
header=inp~csvLineIn; timeCol=findCol(header,'time_ms')
rows=0
do while inp~chars>0
  row=inp~csvLineIn
  if row==.nil | row~items<timeCol then iterate
  t=row[timeCol]+0; rows+=1
  if t<1000 | t>=5000 then call fail 'sample outside window t='||t
  if t>=2000 & t<3000 then call fail 'sample inside exclusion t='||t
end
inp~close
if rows=0 then call fail 'no samples in window'
say 'PASS synthetic wall window rows='rows 'excluded_frames='run['excluded_frames']
exit 0

readOne: procedure
  use arg path
  inp=.CSVStream~new(path,.false); inp~delimiter='09'x; inp~open('read')
  if inp~state<>'READY' then return .nil
  header=inp~csvLineIn; row=inp~csvLineIn; inp~close
  if header==.nil | row==.nil then return .nil
  d=.directory~new
  do i=1 to header~items
    v=''; if row~items>=i then v=row[i]
    d[header[i]]=v
  end
  return d
findCol: procedure
  use arg row,name
  do i=1 to row~items; if row[i]=name then return i; end
  call fail 'column not found '||name
quote: procedure
  parse arg x
  return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
  parse arg m
  say 'FAIL' m
  exit 1
::requires 'csvStream.cls'
::requires 'FDDoorMicroMotion.cls'

parse arg specPath
spec=.FDControlFile~read(specPath)
if spec==.nil then exit 2
stateDir=spec~get('state_dir','')
countPath=spec~get('test_counter_path','')
if stateDir='' | countPath='' then exit 3
count=0
if stream(countPath,'C','QUERY EXISTS')<>'' then do; count=linein(countPath)+0; call stream countPath,'C','CLOSE'; end
call lineout countPath,count+1; call stream countPath,'C','CLOSE'
st=.FDCheckpointState~new
st~put('status','RUNNING'); st~put('source_path',spec~get('source_path','')); st~put('source_name','fake'); st~put('part_no','1'); st~put('checkpoint_generation','0'); st~put('last_pts','0'); st~put('last_ms','0')
.FDControlFile~write(stateDir||'/running.tsv',st)
call SysSleep 2
exit 0
::requires 'FDDoorMicroMotion.cls'

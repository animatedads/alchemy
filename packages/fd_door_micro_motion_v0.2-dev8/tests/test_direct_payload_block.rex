parse arg root .
if root='' then root='.'
q=root||'/qualification/direct-block'
address system 'rm -rf -- '||quote(q)
address system 'mkdir -p -- '||quote(q)
s=.FDCheckpointState~new
s~put('source_path',root||'/tests/synthetic_night_tiny.mp4'); s~put('profile','FD_NIGHT_F11'); s~put('output_prefix',q||'/analysis'); s~put('state_dir',q||'/state'); s~put('source_evidence_ref','sha256:test'); s~put('wall_clock_origin','2023-10-10T00:00:00'); s~put('analysis_wall_start','2023-10-10T00:00:00'); s~put('analysis_wall_end','2023-10-10T00:00:01'); s~put('exclusion_count','0')
spec=q||'/legacy-direct.tsv'; .FDControlFile~write(spec,s)
address system 'rexx '||quote(root||'/tools/run_fd_worker.rex')||' '||quote(spec)||' > '||quote(q||'/out.txt')||' 2>&1'
if rc<>66 then call fail 'legacy direct worker rc='||rc
text=''; do while lines(q||'/out.txt')>0; text=text||linein(q||'/out.txt'); end; call stream q||'/out.txt','C','CLOSE'
if \text~contains('direct payload launch prohibited') then call fail 'missing direct-launch diagnostic'
say 'PASS direct payload entry is blocked; NEW must use standard starter'
exit 0
quote: procedure
 parse arg x
 return "'"||x~changestr("'","'\\''")||"'"
fail: procedure
 parse arg m
 say 'FAIL' m
 exit 1
::requires 'FDDoorMicroMotion.cls'

call rxfuncadd 'SysLoadFuncs','RexxUtil','SysLoadFuncs'; call SysLoadFuncs
parse source . . here
base=filespec('D',here) || filespec('P',here)
log=base || 'fake_colab.log'; call SysFileDelete log
call value 'FAKE_COLAB_LOG',log,'ENVIRONMENT'
cli=.ColabCliAdapter~new(base || 'fake_colab.sh')
req=.ColabJobRequirement~new('GPU','T4',.false,16384,30720,.true,.true)
inputs=.array~of(.ColabInputFile~new(base || 'corpus_bundle.zip','corpus_bundle.zip'))
outputs=.array~of(.ColabOutputFile~new('outputs/training-report.json',base || 'got-report.json',.true))
spec=.ColabJobSpec~new('gemma-oorexx-100-step',req,base || 'workload.py',.array~of('--recovery-steps','100'),.directory~new,.array~of('torch','transformers'),inputs,outputs,600,.false)
r=.ColabJobRunner~new(cli)~run(spec)
call assert r~success, 'job should succeed'
call assert r~code='COMPLETED','completion code'
text=readAll(log)
call assert pos('new',text)>0,'allocated'
call assert pos('--gpu T4',text)>0,'explicit T4 required'
call assert pos('upload',text)>0,'uploads'
call assert pos('install',text)>0,'dependencies'
call assert pos('exec',text)>0,'execution'
call assert pos('download',text)>0,'download'
call assert pos('rm',text)>0,'remote cleanup'
call assert pos('stop',text)>0,'stop'
call assert stream(base || 'got-report.json','C','QUERY EXISTS')<>'','artifact downloaded'
call assert r~artifacts~items=1,'one verified artifact receipt'
call assert r~artifacts[1]~remoteName='outputs/training-report.json','receipt remote name'
call assert r~artifacts[1]~sizeBytes=9,'receipt size'
call assert r~artifacts[1]~sha256='5b3513f580c8397212ff2c8f459c199efc0c90e4354a5f3533adf0a3fff3a530','receipt sha256'
call assert pos('RESULT_MANIFEST_DOWNLOAD',r~evidence~canonical)>0,'manifest retrieval evidenced'
call assert pos('VERIFY|OK|outputs/training-report.json',r~evidence~canonical)>0,'artifact verification evidenced'

/* CPU thrift: no accelerator flag may appear. */
call SysFileDelete log
cpu=.ColabJobRequirement~new('CPU','',.false,1024,1024,.false,.false)
spec2=.ColabJobSpec~new('cpu-small',cpu,base || 'workload.py',.nil,.nil,.nil,.nil,.nil,60,.false)
r2=.ColabJobRunner~new(cli)~run(spec2)
call assert r2~success,'CPU job succeeds'
text=readAll(log)
call assert pos('--gpu',text)=0,'CPU job must not demand GPU'
call assert pos('--tpu',text)=0,'CPU job must not demand TPU'

/* Validate before allocation. */
call SysFileDelete log
bad=.ColabJobSpec~new('bad',cpu,base || 'missing.py')
r3=.ColabJobRunner~new(cli)~run(bad)
call assert \r3~success,'missing entrypoint fails'
call assert r3~code='ENTRYPOINT_MISSING','missing entrypoint code'
call assert stream(log,'C','QUERY EXISTS')='','no Colab call before local validation'
/* Remote path citizenship is local validation and must reject traversal. */
signal on syntax name unsafePathRejected
unsafe=.ColabInputFile~new(base || 'corpus_bundle.zip','../escape.zip')
signal off syntax
call fail 'unsafe remote path was accepted'
unsafePathRejected:
signal off syntax
call SysFileDelete log

/* Execution failure still retrieves log and stops the allocation. */
call SysFileDelete log
call value 'FAKE_COLAB_FAIL_CMD','exec','ENVIRONMENT'
r4=.ColabJobRunner~new(cli)~run(spec2)
call value 'FAKE_COLAB_FAIL_CMD','','ENVIRONMENT'
call assert \r4~success,'forced exec failure fails job'
text=readAll(log)
call assert pos('stop',text)>0,'failure path still stops session'
call assert pos('log',text)>0,'failure path still retrieves log'

say 'PASS Colab Job core lifecycle/resource citizenship'
exit 0

fail: procedure
  use arg msg
  say 'FAIL:' msg
  exit 1
assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
readAll: procedure
  use arg path
  if stream(path,'C','QUERY EXISTS')='' then return ''
  s=.stream~new(path); s~open('READ'); out=''
  do while s~lines>0; out=out || s~lineIn || '0a'x; end
  s~close; return out
::requires '../src/ColabJob.cls'

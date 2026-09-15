parse source . . here
base=filespec('D',here) || filespec('P',here)
secret='HF_TEST_TOKEN_9B7D_DO_NOT_LEAK'

/* 1. Obvious secret environment names must not be accepted as literals. */
exec1=.SecretCapturingExecutor~new(secret)
cli1=.ColabCliAdapter~new('colab',exec1)
cpu=.ColabJobRequirement~new('CPU','',.false,1024,1024,.true,.false)
env=.directory~new; env['HF_TOKEN']=secret
literal=.ColabJobSpec~new('literal-secret',cpu,base || 'workload.py',.nil,env)
r1=.ColabJobRunner~new(cli1)~run(literal)
call assert \r1~success,'literal HF_TOKEN rejected'
call assert r1~code='SECRET_LITERAL_FORBIDDEN','literal secret rejection code'
call assert exec1~callCount=0,'literal rejected before Colab allocation'
call assert pos(secret,r1~evidence~canonical)=0,'literal secret absent from evidence'

/* 2. A secret binding requires the Secret Broker seam. */
bindings=.array~of(.ColabSecretBinding~new('HF_TOKEN','huggingface.primary'))
needsBroker=.ColabJobSpec~new('needs-broker',cpu,base || 'workload.py',.nil,.nil,.nil,.nil,.nil,60,.false,bindings)
exec2=.SecretCapturingExecutor~new(secret)
r2=.ColabJobRunner~new(.ColabCliAdapter~new('colab',exec2))~run(needsBroker)
call assert \r2~success,'secret binding without broker fails'
call assert r2~code='SECRET_BROKER_REQUIRED','broker required code'
call assert exec2~callCount=0,'no allocation without broker'

/* 3. Missing reference also fails before allocation. */
emptyProvider=.TestSecretProvider~new
emptyBroker=.SecretBroker~new(emptyProvider)
exec3=.SecretCapturingExecutor~new(secret)
r3=.ColabJobRunner~new(.ColabCliAdapter~new('colab',exec3),emptyBroker)~run(needsBroker)
call assert \r3~success,'missing reference fails'
call assert r3~code='SECRET_UNAVAILABLE','missing reference code'
call assert exec3~callCount=0,'missing secret burns no Colab resource'
call assert emptyBroker~activeLeaseCount=0,'failed secret lease not active'

/* 4. Proper reference -> lease -> private materialization -> upload -> driver env. */
provider=.TestSecretProvider~new
call assert provider~put('huggingface.primary',secret),'test provider put'
broker=.SecretBroker~new(provider)
exec4=.SecretCapturingExecutor~new(secret)
cli4=.ColabCliAdapter~new('colab',exec4)
plain=.directory~new; plain['HF_HOME']='/content/hf-cache'
spec=.ColabJobSpec~new('secret-job',cpu,base || 'workload.py',.nil,plain,.nil,.nil,.nil,60,.false,bindings)
r4=.ColabJobRunner~new(cli4,broker)~run(spec)
call assert r4~success,'reference-backed secret job succeeds'
call assert r4~code='COMPLETED','secret job completion code'
call assert exec4~capturedSecret==secret,'secret file carried broker value'
call assert exec4~secretFileMode='-rw-------','local secret file was 0600'
call assert exec4~secretDirMode='drwx------','local secret directory was 0700'
call assert pos(secret,exec4~commandTranscript)=0,'secret absent from CLI argv transcript'
call assert pos(secret,exec4~driverTranscript)=0,'secret absent from generated driver source'
call assert pos('HF_TOKEN',exec4~driverTranscript)>0,'driver binds HF_TOKEN'
call assert pos('/.secrets/s1',exec4~driverTranscript)>0,'driver consumes ordinal remote secret file'
call assert pos('huggingface.primary',exec4~driverTranscript)=0,'secret reference not sent to remote driver'
call assert pos(secret,r4~evidence~canonical)=0,'secret absent from job evidence'
call assert pos('<SECRET>',r4~evidence~canonical)>0,'evidence records redaction marker'
call assert pos(secret,r4~executionResult~stdout)=0,'secret removed from execution stdout'
call assert pos(secret,r4~executionResult~stderr)=0,'secret removed from execution stderr'
call assert pos('<SECRET>',r4~executionResult~stdout)>0,'stdout redaction visible'
call assert broker~activeLeaseCount=0,'secret lease retired after job'
call assert exec4~secretLocalPath<>'' ,'test observed local secret path'
call assert stream(exec4~secretLocalPath,'C','QUERY EXISTS')='','local secret file deleted after upload'
logPath='/tmp/colab-job-secret-job.jsonl'
logText=readAll(logPath)
call assert pos(secret,logText)=0,'exported Colab log scrubbed'
call assert pos('<SECRET>',logText)>0,'exported Colab log contains redaction marker'
call SysFileDelete logPath

/* 5. Session retention must never retain the remote secret directory. */
provider2=.TestSecretProvider~new; provider2~put('huggingface.primary',secret)
broker2=.SecretBroker~new(provider2)
exec5=.SecretCapturingExecutor~new(secret)
retained=.ColabJobSpec~new('retained-secret',cpu,base || 'workload.py',.nil,.nil,.nil,.nil,.nil,60,.true,bindings)
r5=.ColabJobRunner~new(.ColabCliAdapter~new('colab',exec5),broker2)~run(retained)
call assert r5~success,'retained session secret job succeeds'
call assert pos(' rm ', ' ' || exec5~commandTranscript || ' ')>0,'secret cleanup uses remote rm even when retained'
call assert pos('/.secrets',exec5~commandTranscript)>0,'remote secret directory cleanup recorded'
call assert pos(' stop ', ' ' || exec5~commandTranscript || ' ')=0,'retained session not stopped'
call assert broker2~activeLeaseCount=0,'retained session still retires local lease'

say 'PASS Colab Job Secret Broker reference seam / HF_TOKEN redaction'
exit 0

assert: procedure
  use arg ok,msg
  if \ok then do; say 'FAIL:' msg; exit 1; end
  return
readAll: procedure
  use arg path
  if stream(path,'C','QUERY EXISTS')='' then return ''
  s=.stream~new(path); s~open('READ'); out=s~charIn(1,s~chars); s~close; return out

::class SecretCapturingExecutor public subclass ColabCommandExecutor
::attribute callCount get
::attribute capturedSecret get
::attribute commandTranscript get
::attribute driverTranscript get
::attribute secretLocalPath get
::attribute secretFileMode get
::attribute secretDirMode get
::method init
  expose expectedSecret callCount capturedSecret commandTranscript driverTranscript secretLocalPath secretFileMode secretDirMode execCount
  use arg expectedArg
  expectedSecret=expectedArg; callCount=0; capturedSecret=''; commandTranscript=''; driverTranscript=''; secretLocalPath=''; secretFileMode=''; secretDirMode=''; execCount=0
::method run
  expose expectedSecret callCount capturedSecret commandTranscript driverTranscript secretLocalPath secretFileMode secretDirMode execCount
  use arg argv
  callCount+=1
  line=''
  do a over argv
    if line<>'' then line=line || ' '
    line=line || a
  end
  commandTranscript=commandTranscript || line || '0a'x
  cmd=''
  do a over argv
    if a='new' | a='upload' | a='download' | a='install' | a='exec' | a='log' | a='rm' | a='stop' | a='status' then do; cmd=a; leave; end
  end
  if cmd='upload' then do
    localPath=argv[argv~items-1]
    if pos('oorexx-colab-secret-',localPath)>0 then do
      secretLocalPath=localPath
      s=.stream~new(localPath); s~open('READ'); capturedSecret=s~charIn(1,s~chars); s~close
      rows=.array~new; call SysFileTree localPath, rows, 'F'
      if rows~items>0 then secretFileMode=word(rows[1],4)
      dir=strip(filespec('D',localPath) || filespec('P',localPath),'T','/')
      drows=.array~new; call SysFileTree dir, drows, 'D'
      if drows~items>0 then secretDirMode=word(drows[1],4)
    end
  end
  if cmd='exec' then do
    execCount+=1
    filePath=''
    do i=1 to argv~items-1
      if argv[i]='-f' then do; filePath=argv[i+1]; leave; end
    end
    if filePath<>'' then do
      s=.stream~new(filePath); s~open('READ'); text=s~charIn(1,s~chars); s~close
      driverTranscript=driverTranscript || text || '0a'x
    end
    if execCount=2 then return .ColabCommandResult~new(0,'workload printed ' || expectedSecret,'stderr ' || expectedSecret,line)
  end
  if cmd='log' then do
    outPath=argv[argv~items]
    s=.stream~new(outPath); s~open('WRITE REPLACE'); s~charOut('{"output":"' || expectedSecret || '"}' || '0a'x); s~close
  end
  return .ColabCommandResult~new(0,'','',line)

::requires '../src/ColabJob.cls'
::requires 'SecretBroker.cls'

/* ooRexx Colab Job v0.3-dev1
 * Generic, resource-thrifty managed execution over google-colab-cli.
 * Colab is an execution target, not an AI provider.
 */

::class ColabJobBuild public
::constant VERSION "0.3-dev1"
::constant API "colab.job/0.3"

::class ColabJobRequirement public
::attribute accelerator get
::attribute acceleratorModel get
::attribute highMemory get
::attribute minimumMemoryMiB get
::attribute minimumDiskMiB get
::attribute networkEgress get
::attribute checkpointable get
::method init
  expose accelerator acceleratorModel highMemory minimumMemoryMiB minimumDiskMiB networkEgress checkpointable
  use arg accelArg="CPU", modelArg="", highMemArg=.false, minMemArg=0, minDiskArg=0, egressArg=.false, checkpointArg=.false
  accelerator=accelArg~string~strip~upper
  acceleratorModel=modelArg~string~strip~upper
  highMemory=(highMemArg==.true)
  minimumMemoryMiB=minMemArg+0; minimumDiskMiB=minDiskArg+0
  networkEgress=(egressArg==.true); checkpointable=(checkpointArg==.true)
  if accelerator<>"CPU" & accelerator<>"GPU" & accelerator<>"TPU" then raise syntax 88.900 array("accelerator must be CPU, GPU or TPU")
  if accelerator="CPU" & acceleratorModel<>"" then raise syntax 88.900 array("CPU jobs must not request an accelerator model")
  if accelerator<>"CPU" & acceleratorModel="" then raise syntax 88.900 array("GPU/TPU jobs must explicitly name the required model")
::method canonical
  expose accelerator acceleratorModel highMemory minimumMemoryMiB minimumDiskMiB networkEgress checkpointable
  return "accelerator="accelerator";model="acceleratorModel";highMem="highMemory";minMem="minimumMemoryMiB";minDisk="minimumDiskMiB";egress="networkEgress";checkpointable="checkpointable

::class ColabRemotePath public
::method valid class
  use arg pathArg
  p=pathArg~string
  if p="" then return .false
  if left(p,1)="/" | left(p,1)="\\" then return .false
  if pos("\\",p)>0 then return .false
  do while pos("//",p)>0; p=changestr("//",p,"/"); end
  parts=p~makeArray("/")
  do part over parts
    if part="" | part="." | part=".." then return .false
  end
  return .true

::class ColabArtifactReceipt public
::attribute remoteName get
::attribute localPath get
::attribute sizeBytes get
::attribute sha256 get
::method init
  expose remoteName localPath sizeBytes sha256
  use arg remoteArg,localArg,sizeArg,digestArg
  remoteName=remoteArg~string; localPath=localArg~string; sizeBytes=sizeArg+0; sha256=digestArg~string~lower

::class ColabInputFile public
::attribute localPath get
::attribute remoteName get
::method init
  expose localPath remoteName
  use arg localArg, remoteArg=""
  localPath=localArg~string
  if remoteArg="" then remoteName=filespec("N",localPath); else remoteName=remoteArg~string
  if localPath="" | remoteName="" then raise syntax 88.900 array("input localPath and remoteName must not be empty")
  if \.ColabRemotePath~valid(remoteName) then raise syntax 88.900 array("input remoteName must be a safe relative path")

::class ColabOutputFile public
::attribute remoteName get
::attribute localPath get
::attribute required get
::method init
  expose remoteName localPath required
  use arg remoteArg, localArg, requiredArg=.true
  remoteName=remoteArg~string; localPath=localArg~string; required=(requiredArg==.true)
  if remoteName="" | localPath="" then raise syntax 88.900 array("output remoteName and localPath must not be empty")
  if \.ColabRemotePath~valid(remoteName) then raise syntax 88.900 array("output remoteName must be a safe relative path")

::class ColabSecretBinding public
::attribute environmentName get
::attribute reference get
::method init
  expose environmentName reference
  use arg envArg, referenceArg
  environmentName=envArg~string~strip~upper
  reference=referenceArg~string~strip
  if environmentName="" | reference="" then raise syntax 88.900 array("secret environmentName and reference must not be empty")
  if \.ColabSecretBinding~validEnvironmentName(environmentName) then raise syntax 88.900 array("secret environmentName is not a valid environment variable name")
::method validEnvironmentName class
  use arg nameArg
  name=nameArg~string
  if name="" then return .false
  first=name~substr(1,1)
  if \datatype(first,"M") & first<>"_" then return .false
  do i=2 to name~length
    c=name~substr(i,1)
    if \datatype(c,"M") & \datatype(c,"N") & c<>"_" then return .false
  end
  return .true
::method looksSensitiveEnvironmentName class
  use arg nameArg
  name=nameArg~string~strip~upper
  if name="HF_TOKEN" then return .true
  if name~length>=6 & name~right(6)="_TOKEN" then return .true
  if name~length>=7 & name~right(7)="_SECRET" then return .true
  if name~length>=9 & name~right(9)="_PASSWORD" then return .true
  if name~length>=8 & name~right(8)="_API_KEY" then return .true
  if name="AWS_SECRET_ACCESS_KEY" then return .true
  return .false

::class ColabJobSpec public
::attribute jobId get
::attribute requirement get
::attribute entrypoint get
::attribute arguments get
::attribute environment get
::attribute dependencies get
::attribute inputs get
::attribute outputs get
::attribute timeoutSeconds get
::attribute retainSession get
::attribute secretBindings get
::method init
  expose jobId requirement entrypoint arguments environment dependencies inputs outputs timeoutSeconds retainSession secretBindings
  use arg jobIdArg, reqArg, entryArg, argsArg=.nil, envArg=.nil, depsArg=.nil, inputsArg=.nil, outputsArg=.nil, timeoutArg=3600, retainArg=.false, secretBindingsArg=.nil
  jobId=jobIdArg~string~strip; requirement=reqArg; entrypoint=entryArg~string
  if jobId="" then raise syntax 88.900 array("jobId must not be empty")
  if requirement==.nil then raise syntax 88.900 array("requirement is mandatory")
  if entrypoint="" then raise syntax 88.900 array("entrypoint is mandatory")
  if argsArg==.nil then arguments=.array~new; else arguments=argsArg
  if envArg==.nil then environment=.directory~new; else environment=envArg
  if depsArg==.nil then dependencies=.array~new; else dependencies=depsArg
  if inputsArg==.nil then inputs=.array~new; else inputs=inputsArg
  if outputsArg==.nil then outputs=.array~new; else outputs=outputsArg
  if secretBindingsArg==.nil then secretBindings=.array~new; else secretBindings=secretBindingsArg
  timeoutSeconds=timeoutArg+0; retainSession=(retainArg==.true)
  if timeoutSeconds<=0 then raise syntax 88.900 array("timeoutSeconds must be positive")

::class ColabCommandResult public
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute command get
::method init
  expose rc stdout stderr command
  use arg rcArg, outArg="", errArg="", cmdArg=""
  rc=rcArg+0; stdout=outArg~string; stderr=errArg~string; command=cmdArg~string
::method ok
  expose rc
  return rc=0

::class ColabCommandExecutor public
::method run abstract

::class ColabSystemCommandExecutor public subclass ColabCommandExecutor
::attribute sequence
::method init
  expose sequence
  sequence=0
::method run
  expose sequence
  use arg argv
  sequence+=1
  stem=value("TMPDIR",,"ENVIRONMENT"); if stem="" then stem="/tmp"
  dir=stem || "/oorexx_colab_job_" || time("S") || "_" || sequence
  address system "mkdir -m 700 " || .ColabShell~quote(dir)
  if rc<>0 then return .ColabCommandResult~new(rc,"","unable to create private command capture directory",.ColabShell~argv(argv))
  outFile=dir || "/stdout"; errFile=dir || "/stderr"
  cmd=.ColabShell~argv(argv) || " >" || .ColabShell~quote(outFile) || " 2>" || .ColabShell~quote(errFile)
  address system cmd
  resultRc=rc
  out=self~readAll(outFile); err=self~readAll(errFile)
  address system "rm -rf " || .ColabShell~quote(dir)
  return .ColabCommandResult~new(resultRc,out,err,.ColabShell~argv(argv))
::method readAll private
  use arg path
  if stream(path,"C","QUERY EXISTS")="" then return ""
  s=.stream~new(path); s~open("READ")
  text=""
  do while s~lines>0
    line=s~lineIn
    if text="" then text=line; else text=text || "0a"x || line
  end
  s~close
  return text

::class ColabShell public
::method quote class
  use arg text
  t=text~string
  q="27"x; dq="22"x; rep=q || dq || q || dq || q
  return q || changestr(q,t,rep) || q
::method argv class
  use arg args
  out=""
  do a over args
    if out<>"" then out=out || " "
    out=out || self~quote(a)
  end
  return out

::class ColabCliAdapter public
::attribute binary get
::attribute executor get
::attribute authMode get
::attribute configPath get
::method init
  expose binary executor authMode configPath
  use arg binaryArg="colab", executorArg=.nil, authArg="", configArg=""
  binary=binaryArg~string
  if executorArg==.nil then executor=.ColabSystemCommandExecutor~new; else executor=executorArg
  authMode=authArg~string~strip; configPath=configArg~string
::method invoke
  expose binary executor authMode configPath
  use arg commandArgs
  argv=.array~new; argv~append(binary)
  if authMode<>"" then do; argv~append("--auth"); argv~append(authMode); end
  if configPath<>"" then do; argv~append("--config"); argv~append(configPath); end
  do a over commandArgs; argv~append(a); end
  return executor~run(argv)
::method newSession
  use arg name, requirement
  a=.array~of("new","-s",name)
  select
    when requirement~accelerator="GPU" then do; a~append("--gpu"); a~append(requirement~acceleratorModel); end
    when requirement~accelerator="TPU" then do; a~append("--tpu"); a~append(requirement~acceleratorModel); end
    otherwise nop
  end
  if requirement~highMemory then a~append("--high-mem")
  return self~invoke(a)
::method upload
  use arg name, localPath, remotePath
  return self~invoke(.array~of("upload","-s",name,localPath,remotePath))
::method download
  use arg name, remotePath, localPath
  return self~invoke(.array~of("download","-s",name,remotePath,localPath))
::method install
  use arg name, packages
  a=.array~of("install","-s",name)
  do p over packages; a~append(p); end
  return self~invoke(a)
::method execFile
  use arg name, localDriver, timeoutSeconds, environment=.nil
  a=.array~of("exec","-s",name,"-f",localDriver,"--timeout",timeoutSeconds~string)
  if environment<>.nil then do key over environment~allIndexes
    a~append("--env"); a~append(key || "=" || environment[key])
  end
  return self~invoke(a)
::method log
  use arg name, outputPath
  return self~invoke(.array~of("log","-s",name,"-o",outputPath))
::method remove
  use arg name, remotePath
  return self~invoke(.array~of("rm","-s",name,remotePath))
::method stop
  use arg name
  return self~invoke(.array~of("stop","-s",name))
::method status
  use arg name
  return self~invoke(.array~of("status","-s",name))

::class ColabJobEvidence public
::attribute events get
::method init
  expose events
  events=.array~new
::method add
  expose events
  use arg phase, code, detail=""
  events~append(phase || "|" || code || "|" || detail)
  return self
::method canonical
  expose events
  out=""
  do e over events
    if out<>"" then out=out || "0a"x
    out=out || e
  end
  return out

::class ColabJobResult public
::attribute success get
::attribute code get
::attribute sessionName get
::attribute evidence get
::attribute executionResult get
::attribute cleanupResult get
::attribute artifacts get
::method init
  expose success code sessionName evidence executionResult cleanupResult artifacts
  use arg okArg, codeArg, sessionArg, evidenceArg, execArg=.nil, cleanupArg=.nil, artifactsArg=.nil
  success=okArg; code=codeArg~string; sessionName=sessionArg~string; evidence=evidenceArg; executionResult=execArg; cleanupResult=cleanupArg
  if artifactsArg==.nil then artifacts=.array~new; else artifacts=artifactsArg

::class ColabJobRunner public
::attribute cli get
::attribute secretBroker get
::method init
  expose cli secretBroker
  use arg cliArg=.nil, secretBrokerArg=.nil
  if cliArg==.nil then cli=.ColabCliAdapter~new; else cli=cliArg
  secretBroker=secretBrokerArg
::method run
  expose cli secretBroker
  use arg spec
  ev=.ColabJobEvidence~new
  session=""; remoteRoot=""; driver=""; prepare=""
  leases=.array~new; localSecretPaths=.array~new
  allocated=.false; execResult=.nil; cleanup=.nil; jobResult=.nil; artifacts=.array~new; manifestPath=""
  signal on syntax name unexpected

  /* Good-citizen rule: fail all local validation before any resource allocation. */
  if stream(spec~entrypoint,"C","QUERY EXISTS")="" then return .ColabJobResult~new(.false,"ENTRYPOINT_MISSING","",ev~add("VALIDATE","ENTRYPOINT_MISSING",spec~entrypoint))
  do f over spec~inputs
    if stream(f~localPath,"C","QUERY EXISTS")="" then return .ColabJobResult~new(.false,"INPUT_MISSING","",ev~add("VALIDATE","INPUT_MISSING",f~localPath))
  end
  validation=self~validateSecretContract(spec,ev)
  if validation<>"OK" then return .ColabJobResult~new(.false,validation,"",ev)

  /* Acquire references before allocation so an unavailable credential never burns VM time.
   * The lease, not the job spec, is the only in-process holder of secret material. */
  if spec~secretBindings~items>0 then do
    do binding over spec~secretBindings
      lease=secretBroker~acquire(binding~reference)
      if lease==.nil then do
        ev~add("SECRET_ACQUIRE","SECRET_UNAVAILABLE","env=" || binding~environmentName || ";reference=" || binding~reference)
        self~retireLeases(leases,ev)
        return .ColabJobResult~new(.false,"SECRET_UNAVAILABLE","",ev)
      end
      if \lease~hasMethod("OK") then do
        ev~add("SECRET_ACQUIRE","SECRET_LEASE_INTERFACE_INVALID","env=" || binding~environmentName || ";reference=" || binding~reference)
        self~retireLeases(leases,ev)
        return .ColabJobResult~new(.false,"SECRET_LEASE_INTERFACE_INVALID","",ev)
      end
      if \lease~ok then do
        ev~add("SECRET_ACQUIRE","SECRET_UNAVAILABLE","env=" || binding~environmentName || ";reference=" || binding~reference)
        if lease~hasMethod("RETIRE") then lease~retire
        self~retireLeases(leases,ev)
        return .ColabJobResult~new(.false,"SECRET_UNAVAILABLE","",ev)
      end
      if \lease~hasMethod("SECRETFORTRUSTEDCONSUMER") then do
        leases~append(lease)
        ev~add("SECRET_ACQUIRE","SECRET_LEASE_INTERFACE_INVALID","env=" || binding~environmentName || ";reference=" || binding~reference)
        self~retireLeases(leases,ev)
        return .ColabJobResult~new(.false,"SECRET_LEASE_INTERFACE_INVALID","",ev)
      end
      leases~append(lease)
      ev~add("SECRET_ACQUIRE","OK","env=" || binding~environmentName || ";reference=" || binding~reference || ";value=<REDACTED>")
    end
  end

  session=self~sessionName(spec~jobId)
  driver=self~makeDriver(spec,session)
  prepare=self~makePrepare(spec)
  remoteRoot="/content/oorexx-job-" || self~safeId(spec~jobId)

  r=cli~newSession(session,spec~requirement)
  ev~add("ALLOCATE",r~rc,self~redact(r~stderr,leases))
  if \r~ok then do; jobResult=.ColabJobResult~new(.false,"ALLOCATE_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end
  allocated=.true

  /* Create an isolated remote workspace and a 0700 secret subdirectory when required. */
  r=cli~execFile(session,prepare,30,.nil); ev~add("PREPARE",r~rc,self~redact(r~stderr,leases))
  if \r~ok then do; jobResult=.ColabJobResult~new(.false,"PREPARE_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end

  /* Secret references are materialized only now, after allocation, into a private local directory.
   * The CLI sees only a filename; the remote driver sees only an ordinal secret path. */
  if spec~secretBindings~items>0 then do
    ordinal=0
    do binding over spec~secretBindings
      ordinal+=1
      lease=leases[ordinal]
      valueResult=lease~secretForTrustedConsumer
      if valueResult==.nil then do
        ev~add("SECRET_MATERIALIZE","SECRET_UNAVAILABLE","env=" || binding~environmentName || ";reference=" || binding~reference)
        jobResult=.ColabJobResult~new(.false,"SECRET_UNAVAILABLE",session,ev)
        signal finish
      end
      if \valueResult~hasMethod("OK") then do
        ev~add("SECRET_MATERIALIZE","SECRET_LEASE_INTERFACE_INVALID","env=" || binding~environmentName || ";reference=" || binding~reference)
        jobResult=.ColabJobResult~new(.false,"SECRET_LEASE_INTERFACE_INVALID",session,ev)
        signal finish
      end
      if \valueResult~ok then do
        ev~add("SECRET_MATERIALIZE","SECRET_UNAVAILABLE","env=" || binding~environmentName || ";reference=" || binding~reference)
        jobResult=.ColabJobResult~new(.false,"SECRET_UNAVAILABLE",session,ev)
        signal finish
      end
      localSecret=self~writeSecretTemp(spec~jobId,ordinal,valueResult~value)
      if localSecret="" then do
        ev~add("SECRET_MATERIALIZE","LOCAL_SECRET_MATERIALIZATION_FAILED","env=" || binding~environmentName || ";reference=" || binding~reference)
        jobResult=.ColabJobResult~new(.false,"LOCAL_SECRET_MATERIALIZATION_FAILED",session,ev)
        signal finish
      end
      localSecretPaths~append(localSecret)
      remoteSecret=remoteRoot || "/.secrets/s" || ordinal
      r=cli~upload(session,localSecret,remoteSecret)
      self~deleteSecretTemp(localSecret)
      ev~add("SECRET_STAGE",r~rc,"env=" || binding~environmentName || ";reference=" || binding~reference || ";value=<REDACTED>")
      if \r~ok then do; jobResult=.ColabJobResult~new(.false,"SECRET_UPLOAD_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end
    end
  end

  /* Stage the authoritative entrypoint plus declared data files. */
  r=cli~upload(session,spec~entrypoint,remoteRoot || "/entrypoint.py")
  ev~add("UPLOAD_ENTRYPOINT",r~rc,self~redact(r~stderr,leases))
  if \r~ok then do; jobResult=.ColabJobResult~new(.false,"UPLOAD_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end
  do f over spec~inputs
    r=cli~upload(session,f~localPath,remoteRoot || "/" || f~remoteName)
    ev~add("UPLOAD",r~rc,f~remoteName)
    if \r~ok then do; jobResult=.ColabJobResult~new(.false,"UPLOAD_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end
  end
  if spec~dependencies~items>0 then do
    r=cli~install(session,spec~dependencies); ev~add("INSTALL",r~rc,self~redact(r~stderr,leases))
    if \r~ok then do; jobResult=.ColabJobResult~new(.false,"INSTALL_FAILED",session,ev,self~redactResult(r,leases)); signal finish; end
  end

  /* Plain environment variables may still use --env. Secret-bound values never do. */
  rawExec=cli~execFile(session,driver,spec~timeoutSeconds,spec~environment)
  execResult=self~redactResult(rawExec,leases)
  ev~add("EXECUTE",execResult~rc,execResult~stderr)
  if \execResult~ok then do; jobResult=.ColabJobResult~new(.false,"EXECUTION_FAILED",session,ev,execResult); signal finish; end
  manifest=.directory~new
  if spec~outputs~items>0 then do
    manifestPath="/tmp/colab-result-manifest-" || self~safeId(spec~jobId) || ".tsv"
    mr=cli~download(session,remoteRoot || "/.oorexx-results.sha256",manifestPath)
    ev~add("RESULT_MANIFEST_DOWNLOAD",mr~rc,".oorexx-results.sha256")
    if \mr~ok then do; jobResult=.ColabJobResult~new(.false,"RESULT_MANIFEST_MISSING",session,ev,self~redactResult(mr,leases)); signal finish; end
    manifest=self~readResultManifest(manifestPath)
    if manifest==.nil then do; jobResult=.ColabJobResult~new(.false,"RESULT_MANIFEST_INVALID",session,ev); signal finish; end
  end
  do o over spec~outputs
    r=cli~download(session,remoteRoot || "/" || o~remoteName,o~localPath)
    ev~add("DOWNLOAD",r~rc,o~remoteName)
    if \r~ok & o~required then do; jobResult=.ColabJobResult~new(.false,"OUTPUT_MISSING",session,ev,self~redactResult(r,leases)); signal finish; end
    if r~ok then do
      receipt=manifest~at(o~remoteName)
      if receipt==.nil then do
        if o~required then do; jobResult=.ColabJobResult~new(.false,"OUTPUT_RECEIPT_MISSING",session,ev); signal finish; end
      end
      else do
        actual=self~fileSha256(o~localPath)
        if actual="" then do; jobResult=.ColabJobResult~new(.false,"OUTPUT_HASH_FAILED",session,ev); signal finish; end
        if actual<>receipt[2] then do
          ev~add("VERIFY","SHA256_MISMATCH",o~remoteName)
          jobResult=.ColabJobResult~new(.false,"OUTPUT_SHA256_MISMATCH",session,ev)
          signal finish
        end
        size=self~fileSize(o~localPath)
        if size<>receipt[1] then do
          ev~add("VERIFY","SIZE_MISMATCH",o~remoteName)
          jobResult=.ColabJobResult~new(.false,"OUTPUT_SIZE_MISMATCH",session,ev)
          signal finish
        end
        artifacts~append(.ColabArtifactReceipt~new(o~remoteName,o~localPath,size,actual))
        ev~add("VERIFY","OK",o~remoteName || ":sha256=" || actual || ":bytes=" || size)
      end
    end
  end
  jobResult=.ColabJobResult~new(.true,"COMPLETED",session,ev,execResult,.nil,artifacts)
  signal finish
unexpected:
  ev~add("EXCEPTION","SYNTAX",self~redact(condition("D"),leases))
  if jobResult==.nil then jobResult=.ColabJobResult~new(.false,"INTERNAL_ERROR",session,ev,execResult)
finish:
  /* Retrieval evidence is best-effort and occurs before teardown. */
  if allocated then do
    logPath=self~localLogPath(spec~jobId)
    lr=cli~log(session,logPath); ev~add("LOG",lr~rc,logPath)
    if stream(logPath,"C","QUERY EXISTS")<>"" then self~redactFile(logPath,leases)

    /* Secret storage is never retained, even when the caller explicitly retains the Colab session. */
    if spec~secretBindings~items>0 & remoteRoot<>"" then do
      sr=cli~remove(session,remoteRoot || "/.secrets")
      ev~add("SECRET_REMOTE_CLEAN",sr~rc,"secret-directory=<REDACTED>")
    end

    if \spec~retainSession then do
      rr=cli~remove(session,remoteRoot); ev~add("REMOTE_CLEAN",rr~rc,remoteRoot)
      cleanup=cli~stop(session); ev~add("STOP",cleanup~rc,self~redact(cleanup~stderr,leases))
      if \cleanup~ok & jobResult~success then jobResult=.ColabJobResult~new(.false,"CLEANUP_FAILED",session,ev,execResult,self~redactResult(cleanup,leases),artifacts)
    end
    else ev~add("STOP","SKIPPED_RETAIN_SESSION",session)
  end

  do localSecret over localSecretPaths; self~deleteSecretTemp(localSecret); end
  if manifestPath<>"" then call SysFileDelete manifestPath
  self~retireLeases(leases,ev)
  if driver<>"" | prepare<>"" then address system "rm -f " || .ColabShell~quote(driver) || " " || .ColabShell~quote(prepare)
  if jobResult==.nil then jobResult=.ColabJobResult~new(.false,"INTERNAL_ERROR",session,ev,execResult)
  return jobResult

::method validateSecretContract private
  expose secretBroker
  use arg spec,ev
  seen=.directory~new
  do key over spec~environment~allIndexes
    upperKey=key~string~upper
    if .ColabSecretBinding~looksSensitiveEnvironmentName(upperKey) then do
      ev~add("VALIDATE","SECRET_LITERAL_FORBIDDEN","env=" || upperKey || ";use=ColabSecretBinding")
      return "SECRET_LITERAL_FORBIDDEN"
    end
  end
  if spec~secretBindings~items=0 then return "OK"
  if secretBroker==.nil then do
    ev~add("VALIDATE","SECRET_BROKER_REQUIRED","secretBindings=" || spec~secretBindings~items)
    return "SECRET_BROKER_REQUIRED"
  end
  if \secretBroker~hasMethod("ACQUIRE") then do
    ev~add("VALIDATE","SECRET_BROKER_REQUIRED","secretBindings=" || spec~secretBindings~items)
    return "SECRET_BROKER_REQUIRED"
  end
  do binding over spec~secretBindings
    if \binding~hasMethod("ENVIRONMENTNAME") | \binding~hasMethod("REFERENCE") then do
      ev~add("VALIDATE","SECRET_BINDING_INVALID","")
      return "SECRET_BINDING_INVALID"
    end
    envName=binding~environmentName~upper
    if seen~hasIndex(envName) then do
      ev~add("VALIDATE","SECRET_BINDING_DUPLICATE","env=" || envName)
      return "SECRET_BINDING_DUPLICATE"
    end
    seen[envName]=.true
    if spec~environment~hasIndex(envName) then do
      ev~add("VALIDATE","SECRET_ENVIRONMENT_COLLISION","env=" || envName)
      return "SECRET_ENVIRONMENT_COLLISION"
    end
  end
  return "OK"

::method writeSecretTemp private
  use arg jobId,ordinal,secretValue
  stem=value("TMPDIR",,"ENVIRONMENT"); if stem="" then stem="/tmp"
  dir=stem || "/oorexx-colab-secret-" || self~safeId(jobId) || "-" || time("S") || "-" || ordinal
  address system "mkdir -m 700 " || .ColabShell~quote(dir)
  if rc<>0 then return ""
  path=dir || "/value"
  s=.stream~new(path); s~open("WRITE REPLACE")
  s~charOut(secretValue~string)
  s~close
  address system "chmod 600 " || .ColabShell~quote(path)
  if rc<>0 then do; address system "rm -rf " || .ColabShell~quote(dir); return ""; end
  return path

::method deleteSecretTemp private
  use arg path
  if path==.nil | path="" then return .true
  dir=filespec("D",path) || filespec("P",path)
  address system "rm -f " || .ColabShell~quote(path)
  address system "rmdir " || .ColabShell~quote(dir) || " >/dev/null 2>&1"
  return .true

::method retireLeases private
  use arg leases,ev
  do lease over leases
    if lease<>.nil then if lease~hasMethod("RETIRE") then do
      if lease~retire then ev~add("SECRET_RETIRE","OK","reference=" || lease~reference || ";value=<REDACTED>")
    end
  end
  return .true

::method redact private
  use arg textArg,leases
  text=textArg~string
  do lease over leases
    if lease==.nil then iterate
    if \lease~hasMethod("SECRETFORTRUSTEDCONSUMER") then iterate
    out=lease~secretForTrustedConsumer
    if out<>.nil then if out~hasMethod("OK") then if out~ok then do
      secret=out~value~string
      if secret<>"" then text=changestr(secret,text,"<SECRET>")
    end
  end
  return text

::method redactResult private
  use arg resultArg,leases
  if resultArg==.nil then return .nil
  return .ColabCommandResult~new(resultArg~rc,self~redact(resultArg~stdout,leases),self~redact(resultArg~stderr,leases),self~redact(resultArg~command,leases))

::method redactFile private
  use arg path,leases
  if stream(path,"C","QUERY EXISTS")="" then return .false
  s=.stream~new(path); s~open("READ")
  data=s~charIn(1,s~chars); s~close
  data=self~redact(data,leases)
  s=.stream~new(path); s~open("WRITE REPLACE"); s~charOut(data); s~close
  return .true

::method sessionName private
  use arg jobId
  return "oorexx-" || self~safeId(jobId)
::method safeId private
  use arg valueArg
  s=valueArg~string~lower; out=""
  do i=1 to s~length
    c=s~substr(i,1)
    if datatype(c,"M") | datatype(c,"N") | c="-" then out=out || c
    else out=out || "-"
  end
  if out~length>40 then out=out~left(40)
  return out
::method localLogPath private
  use arg jobId
  return "/tmp/colab-job-" || self~safeId(jobId) || ".jsonl"
::method makePrepare private
  use arg spec
  path="/tmp/colab-prepare-" || self~safeId(spec~jobId) || ".py"
  remoteRoot="/content/oorexx-job-" || self~safeId(spec~jobId)
  s=.stream~new(path); s~open("WRITE REPLACE")
  s~lineOut("from pathlib import Path")
  s~lineOut("import os")
  s~lineOut("Path(" || self~pyQuote(remoteRoot) || ").mkdir(parents=True, exist_ok=True)")
  if spec~secretBindings~items>0 then do
    secretRoot=remoteRoot || "/.secrets"
    s~lineOut("Path(" || self~pyQuote(secretRoot) || ").mkdir(parents=True, exist_ok=True)")
    s~lineOut("os.chmod(" || self~pyQuote(secretRoot) || ", 0o700)")
  end
  s~close
  return path
::method makeDriver private
  use arg spec, session
  path="/tmp/colab-driver-" || self~safeId(spec~jobId) || ".py"
  remoteRoot="/content/oorexx-job-" || self~safeId(spec~jobId)
  s=.stream~new(path); s~open("WRITE REPLACE")
  s~lineOut("import hashlib, os, runpy, sys")
  s~lineOut("from pathlib import Path")
  s~lineOut("os.makedirs(" || self~pyQuote(remoteRoot) || ", exist_ok=True)")
  s~lineOut("os.chdir(" || self~pyQuote(remoteRoot) || ")")
  if spec~secretBindings~items>0 then do
    ordinal=0
    do binding over spec~secretBindings
      ordinal+=1
      secretPath=remoteRoot || "/.secrets/s" || ordinal
      pyVar="_oorexx_secret_" || ordinal
      s~lineOut(pyVar || " = Path(" || self~pyQuote(secretPath) || ")")
      s~lineOut("os.chmod(" || pyVar || ", 0o600)")
      s~lineOut("os.environ[" || self~pyQuote(binding~environmentName) || "] = " || pyVar || ".read_text(encoding='utf-8')")
      s~lineOut(pyVar || ".unlink(missing_ok=True)")
    end
    s~lineOut("try:")
    s~lineOut("    Path(" || self~pyQuote(remoteRoot || "/.secrets") || ").rmdir()")
    s~lineOut("except OSError:")
    s~lineOut("    pass")
  end
  argText=self~pyQuote("entrypoint.py")
  do a over spec~arguments; argText=argText || ", " || self~pyQuote(a); end
  s~lineOut("sys.argv = [" || argText || "]")
  s~lineOut("runpy.run_path(" || self~pyQuote(remoteRoot || "/entrypoint.py") || ", run_name='__main__')")
  if spec~outputs~items>0 then do
    s~lineOut("_manifest = []")
    do o over spec~outputs
      rp=remoteRoot || "/" || o~remoteName
      s~lineOut("_p = Path(" || self~pyQuote(rp) || ")")
      s~lineOut("if _p.is_file():")
      s~lineOut("    _h = hashlib.sha256()")
      s~lineOut("    with _p.open('rb') as _f:")
      s~lineOut("        for _b in iter(lambda: _f.read(1024*1024), b''):")
      s~lineOut("            _h.update(_b)")
      s~lineOut("    _manifest.append((" || self~pyQuote(o~remoteName) || ", _p.stat().st_size, _h.hexdigest()))")
    end
    s~lineOut("with open(" || self~pyQuote(remoteRoot || "/.oorexx-results.sha256") || ", 'w', encoding='ascii') as _mf:")
    s~lineOut("    for _name, _size, _sha in _manifest:")
    s~lineOut("        _mf.write(_name.encode('utf-8').hex() + '\\t' + str(_size) + '\\t' + _sha + '\\n')")
  end
  s~close
  return path
::method readResultManifest private
  use arg path
  if stream(path,"C","QUERY EXISTS")="" then return .nil
  d=.directory~new
  s=.stream~new(path); if s~open("READ")<>"READY:" then return .nil
  do while s~lines>0
    line=s~lineIn
    parse var line nameHex "09"x sizeText "09"x digest
    if nameHex="" | sizeText="" | digest="" then do; s~close; return .nil; end
    if verify(nameHex,"0123456789abcdefABCDEF")<>0 | nameHex~length//2<>0 then do; s~close; return .nil; end
    name=x2c(nameHex)
    if \.ColabRemotePath~valid(name) then do; s~close; return .nil; end
    if \datatype(sizeText,"W") | sizeText<0 then do; s~close; return .nil; end
    digest=digest~strip~lower
    if digest~length<>64 | verify(digest,"0123456789abcdef")<>0 then do; s~close; return .nil; end
    d[name]=.array~of(sizeText+0,digest)
  end
  s~close
  return d
::method fileSize private
  use arg path
  s=.stream~new(path); if s~open("READ")<>"READY:" then return -1
  n=s~chars; s~close; return n
::method fileSha256 private
  use arg path
  s=.stream~new(path); if s~open("READ")<>"READY:" then return ""
  h=.SHA256~new
  do while s~chars>0
    n=s~chars; if n>1048576 then n=1048576
    h~update(s~charIn(,n))
  end
  s~close
  return h~digest

::method pyQuote private
  use arg text
  t=text~string
  t=changestr("\\",t,"\\\\")
  t=changestr("'",t,"\\'")
  return "'" || t || "'"


::requires "crypto.cls"

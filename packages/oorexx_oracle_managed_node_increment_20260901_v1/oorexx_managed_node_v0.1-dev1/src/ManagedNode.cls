/* ooRexx Managed Node v0.1-dev1
 * Durable-node execution core for allocator-selected work.
 *
 * Placement, Queue Fabric transport, WLU admission and API egress remain
 * independent authorities. This package owns only execution on one node.
 */

::class ManagedNodeBuild public
::constant VERSION "0.1-dev1"
::constant API "managed.node/0.1"

::class ManagedTaskKind public
::constant COMMAND "COMMAND"
::constant TEST "TEST"
::constant COMPUTE "COMPUTE"
::constant FETCH "FETCH"
::constant SERVICE "SERVICE"
::method requiredAbility class
  use strict arg kindArg
  k=kindArg~string~upper
  select
    when k=self~COMMAND then return "COMMAND_EXECUTION"
    when k=self~TEST then return "TEST_EXECUTION"
    when k=self~COMPUTE then return "COMPUTE_EXECUTION"
    when k=self~FETCH then return "FETCH_EXECUTION"
    when k=self~SERVICE then return "SERVICE_HOSTING"
    otherwise return ""
  end

::class ManagedTaskPriority public
::constant BACKGROUND 10
::constant NORMAL 50
::constant INTERACTIVE 100
::constant CONTROL 1000

::class ManagedTaskSpec public
::attribute taskId get
::attribute kind get
::attribute bundleRef get
::attribute runtimeId get
::attribute entrypoint get
::attribute arguments get
::attribute timeoutSeconds get
::attribute resultQueue get
::attribute maxOutputBytes get
::method init
  expose taskId kind bundleRef runtimeId entrypoint arguments timeoutSeconds resultQueue maxOutputBytes
  use arg taskArg="",kindArg="",bundleArg=.nil,runtimeArg="",entryArg="",argsArg=.nil,timeoutArg=300,resultQueueArg="",maxOutputArg=1048576
  taskId=taskArg~string; kind=kindArg~string~upper; bundleRef=bundleArg; runtimeId=runtimeArg~string~upper; entrypoint=entryArg~string
  if argsArg==.nil then arguments=.array~new; else arguments=argsArg
  timeoutSeconds=timeoutArg+0; resultQueue=resultQueueArg~string; maxOutputBytes=maxOutputArg+0
  if taskId="" then raise syntax 88.900 array("taskId must not be empty")
  if .ManagedTaskKind~requiredAbility(kind)="" then raise syntax 88.900 array("unsupported managed task kind: "||kind)
  if bundleRef==.nil then raise syntax 88.900 array("bundleRef is mandatory")
  if runtimeId="" then raise syntax 88.900 array("runtimeId is mandatory")
  if \ .WorkBundlePath~safeRelative(entrypoint) then raise syntax 88.900 array("unsafe managed task entrypoint")
  if timeoutSeconds<=0 then raise syntax 88.900 array("timeoutSeconds must be positive")
  if resultQueue="" then raise syntax 88.900 array("resultQueue is mandatory")
  if maxOutputBytes<1 then raise syntax 88.900 array("maxOutputBytes must be positive")
::method requiredAbility
  expose kind
  return .ManagedTaskKind~requiredAbility(kind)
::method orderedArgs private
  expose arguments
  out=""
  do i=1 to arguments~items
    if i>1 then out=out||"," 
    out=out||arguments[i]~string~c2x~lower
  end
  return out
::method canonical
  expose taskId kind bundleRef runtimeId entrypoint timeoutSeconds resultQueue maxOutputBytes
  return "managed.task/0.1;task="||taskId~c2x~lower||";kind="||kind||";bundle={"||bundleRef~canonical||"};runtime="||runtimeId||";entry="||entrypoint~c2x~lower||";args="||self~orderedArgs||";timeout="||timeoutSeconds||";resultQueue="||resultQueue~c2x~lower||";maxOutput="||maxOutputBytes
::method queuePersistentType
  return "managed.task.spec/0.1"
::method queuePersistentState
  expose taskId kind bundleRef runtimeId entrypoint arguments timeoutSeconds resultQueue maxOutputBytes
  t=.table~new; t["taskId"]=taskId; t["kind"]=kind; t["bundleRef"]=bundleRef; t["runtimeId"]=runtimeId; t["entrypoint"]=entrypoint; t["arguments"]=arguments; t["timeoutSeconds"]=timeoutSeconds; t["resultQueue"]=resultQueue; t["maxOutputBytes"]=maxOutputBytes; return t
::method queueRestoreState
  expose taskId kind bundleRef runtimeId entrypoint arguments timeoutSeconds resultQueue maxOutputBytes
  use strict arg state
  taskId=state["taskId"]~string; kind=state["kind"]~string; bundleRef=state["bundleRef"]; runtimeId=state["runtimeId"]~string; entrypoint=state["entrypoint"]~string; arguments=state["arguments"]; timeoutSeconds=state["timeoutSeconds"]+0; resultQueue=state["resultQueue"]~string; maxOutputBytes=state["maxOutputBytes"]+0; return self

::class ManagedTaskSpecFactory public
::method newBlank
  /* queueRestoreState replaces all fields; placeholder values only */
  return .ManagedTaskSpec~new("BLANK","COMMAND",.WorkBundleRef~new("","0000000000000000000000000000000000000000000000000000000000000000","",""),"BLANK","blank",.array~new,1,"BLANK",1)

::class ManagedTaskAuthorization public
::attribute authorityId get
::attribute keyId get
::attribute jobId get
::attribute placementId get
::attribute ownershipEpoch get
::attribute taskDigest get
::attribute bundleDigest get
::attribute issuedEpochMs get
::attribute expiresEpochMs get
::attribute signature
::method init
  expose authorityId keyId jobId placementId ownershipEpoch taskDigest bundleDigest issuedEpochMs expiresEpochMs signature
  use arg authorityArg="",keyArg="",jobArg="",placementArg="",epochArg=0,taskDigestArg="",bundleDigestArg="",issuedArg=0,expiresArg=0,signatureArg=""
  authorityId=authorityArg~string; keyId=keyArg~string; jobId=jobArg~string; placementId=placementArg~string; ownershipEpoch=epochArg+0; taskDigest=taskDigestArg~string; bundleDigest=bundleDigestArg~string; issuedEpochMs=issuedArg+0; expiresEpochMs=expiresArg+0; signature=signatureArg~string
::method canonical
  expose authorityId keyId jobId placementId ownershipEpoch taskDigest bundleDigest issuedEpochMs expiresEpochMs
  return "managed.task.authorization/0.1;authority="||authorityId~c2x~lower||";key="||keyId~c2x~lower||";job="||jobId~c2x~lower||";placement="||placementId~c2x~lower||";epoch="||ownershipEpoch||";taskDigest="||taskDigest||";bundleDigest="||bundleDigest||";issued="||issuedEpochMs||";expires="||expiresEpochMs
::method isExpired
  expose expiresEpochMs
  use strict arg nowEpochMs
  return expiresEpochMs<=0 | nowEpochMs+0>=expiresEpochMs
::method queuePersistentType
  return "managed.task.authorization/0.1"
::method queuePersistentState
  expose authorityId keyId jobId placementId ownershipEpoch taskDigest bundleDigest issuedEpochMs expiresEpochMs signature
  t=.table~new; t["authorityId"]=authorityId; t["keyId"]=keyId; t["jobId"]=jobId; t["placementId"]=placementId; t["ownershipEpoch"]=ownershipEpoch; t["taskDigest"]=taskDigest; t["bundleDigest"]=bundleDigest; t["issuedEpochMs"]=issuedEpochMs; t["expiresEpochMs"]=expiresEpochMs; t["signature"]=signature; return t
::method queueRestoreState
  expose authorityId keyId jobId placementId ownershipEpoch taskDigest bundleDigest issuedEpochMs expiresEpochMs signature
  use strict arg state
  authorityId=state["authorityId"]~string; keyId=state["keyId"]~string; jobId=state["jobId"]~string; placementId=state["placementId"]~string; ownershipEpoch=state["ownershipEpoch"]+0; taskDigest=state["taskDigest"]~string; bundleDigest=state["bundleDigest"]~string; issuedEpochMs=state["issuedEpochMs"]+0; expiresEpochMs=state["expiresEpochMs"]+0; signature=state["signature"]~string; return self

::class ManagedTaskAuthorizationFactory public
::method newBlank
  return .ManagedTaskAuthorization~new

::class ManagedTaskAuthorizer public
::method init
  expose digestProvider proofAuthority authorityId keyId
  use strict arg digestArg,proofArg,authorityArg,keyArg
  digestProvider=digestArg; proofAuthority=proofArg; authorityId=authorityArg~string; keyId=keyArg~string
::method issue
  expose digestProvider proofAuthority authorityId keyId
  use strict arg spec,lease,issuedEpochMs,expiresEpochMs=0
  if expiresEpochMs<=0 | expiresEpochMs>lease~expiresEpochMs then expiresEpochMs=lease~expiresEpochMs
  td=digestProvider~digestText(spec~canonical)
  a=.ManagedTaskAuthorization~new(authorityId,keyId,lease~jobId,lease~placementId,lease~ownershipEpoch,td,spec~bundleRef~digest,issuedEpochMs,expiresEpochMs,"")
  a~signature=proofAuthority~sign(authorityId,keyId,a~canonical)
  if a~signature="" then raise syntax 88.900 array("task authority refused to sign")
  return a

::class ManagedTaskAuthorizationVerifier public
::method init
  expose digestProvider proofAuthority
  use strict arg digestArg,proofArg
  digestProvider=digestArg; proofAuthority=proofArg
::method verify
  expose digestProvider proofAuthority
  use strict arg authorization,spec,lease,nowEpochMs
  if authorization==.nil then return "TASK_AUTHORIZATION_MISSING"
  if authorization~jobId<>lease~jobId | authorization~placementId<>lease~placementId | authorization~ownershipEpoch<>lease~ownershipEpoch then return "TASK_AUTHORIZATION_PLACEMENT_MISMATCH"
  if authorization~bundleDigest<>spec~bundleRef~digest then return "TASK_AUTHORIZATION_BUNDLE_MISMATCH"
  if authorization~taskDigest<>digestProvider~digestText(spec~canonical) then return "TASK_AUTHORIZATION_TASK_MISMATCH"
  if authorization~isExpired(nowEpochMs) then return "TASK_AUTHORIZATION_EXPIRED"
  if authorization~expiresEpochMs>lease~expiresEpochMs then return "TASK_AUTHORIZATION_OUTLIVES_PLACEMENT"
  if \proofAuthority~verify(authorization~authorityId,authorization~keyId,authorization~canonical,authorization~signature) then return "TASK_AUTHORIZATION_PROOF_INVALID"
  return "OK"

::class ManagedTaskRequest public
::attribute spec get
::attribute authorization get
::method init
  expose spec authorization
  use arg specArg=.nil,authArg=.nil
  spec=specArg; authorization=authArg
::method queuePersistentType
  return "managed.task.request/0.1"
::method queuePersistentState
  expose spec authorization
  t=.table~new; t["spec"]=spec; t["authorization"]=authorization; return t
::method queueRestoreState
  expose spec authorization
  use strict arg state
  spec=state["spec"]; authorization=state["authorization"]; return self

::class ManagedTaskRequestFactory public
::method newBlank
  return .ManagedTaskRequest~new

/* Persistable queue payload that deliberately preserves the allocator lease
 * exactly while avoiding changes to JobNodeDispatchEnvelope itself. */
::class ManagedNodeDispatchEnvelope public
::attribute jobId get
::attribute ownerNodeId get
::attribute executionNodeId get
::attribute placementId get
::attribute placementLease get
::attribute payload get
::method init
  expose jobId ownerNodeId executionNodeId placementId placementLease payload
  use arg leaseArg=.nil,payloadArg=.nil
  placementLease=leaseArg; payload=payloadArg
  if leaseArg==.nil then do; jobId=""; ownerNodeId=""; executionNodeId=""; placementId=""; return; end
  jobId=leaseArg~jobId; ownerNodeId=leaseArg~ownerNodeId; executionNodeId=leaseArg~nodeId; placementId=leaseArg~placementId
::method canonicalHeader
  expose jobId ownerNodeId executionNodeId placementId
  return "job="||jobId||";owner="||ownerNodeId||";execution="||executionNodeId||";placement="||placementId
::method queuePersistentType
  return "managed.node.dispatch/0.1"
::method queuePersistentState
  expose placementLease payload
  l=placementLease
  ls=.table~new
  ls["placementId"]=l~placementId; ls["jobId"]=l~jobId; ls["nodeId"]=l~nodeId; ls["ownerNodeId"]=l~ownerNodeId
  ls["capabilityGeneration"]=l~capabilityGeneration; ls["capacityObservationGeneration"]=l~capacityObservationGeneration; ls["issuedEpochMs"]=l~issuedEpochMs; ls["expiresEpochMs"]=l~expiresEpochMs
  ls["requirementDigest"]=l~requirementDigest; ls["capabilityDigest"]=l~capabilityDigest; ls["capacityDigest"]=l~capacityDigest; ls["allocationPolicyGeneration"]=l~allocationPolicyGeneration
  ls["proofRef"]=l~proofRef; ls["reservationRef"]=l~reservationRef; ls["signature"]=l~signature; ls["ownershipEpoch"]=l~ownershipEpoch; ls["renewalSequence"]=l~renewalSequence; ls["supersedesPlacementId"]=l~supersedesPlacementId
  t=.table~new; t["lease"]=ls; t["payload"]=payload; return t
::method queueRestoreState
  expose jobId ownerNodeId executionNodeId placementId placementLease payload
  use strict arg state
  l=state["lease"]
  placementLease=.JobNodePlacementLease~new(l["placementId"],l["jobId"],l["nodeId"],l["ownerNodeId"],l["capabilityGeneration"],l["capacityObservationGeneration"],l["issuedEpochMs"],l["expiresEpochMs"],l["requirementDigest"],l["capabilityDigest"],l["capacityDigest"],l["allocationPolicyGeneration"],l["proofRef"],l["reservationRef"],l["signature"],l["ownershipEpoch"],l["renewalSequence"],l["supersedesPlacementId"])
  jobId=placementLease~jobId; ownerNodeId=placementLease~ownerNodeId; executionNodeId=placementLease~nodeId; placementId=placementLease~placementId; payload=state["payload"]; return self

::class ManagedNodeDispatchEnvelopeFactory public
::method newBlank
  return .ManagedNodeDispatchEnvelope~new

::class ManagedPlacementVerifier public
::method init
  expose proofAuthority requireProof
  use arg proofArg=.nil,requireProofArg=.true
  proofAuthority=proofArg; requireProof=(requireProofArg==.true)
::method verify
  expose proofAuthority requireProof
  use strict arg envelope,nodeId,nowEpochMs
  if envelope==.nil | envelope~placementLease==.nil then return "PLACEMENT_LEASE_MISSING"
  l=envelope~placementLease
  if envelope~jobId<>l~jobId | envelope~placementId<>l~placementId | envelope~executionNodeId<>l~nodeId then return "PLACEMENT_ENVELOPE_MISMATCH"
  if l~nodeId<>nodeId~string then return "PLACEMENT_WRONG_NODE"
  if l~isExpired(nowEpochMs) then return "PLACEMENT_LEASE_EXPIRED"
  if requireProof then do
    if proofAuthority==.nil | l~signature="" then return "PLACEMENT_PROOF_REQUIRED"
    if \proofAuthority~verify(l~canonical,l~signature) then return "PLACEMENT_PROOF_INVALID"
  end
  return "OK"

/* Destination-side monotonic fence. It complements, but does not replace, the
 * allocator's authoritative JobNodeOwnershipRegistry. */
::class ManagedNodeAttemptFence public
::method init
  expose epochs renewals
  epochs=.directory~new; renewals=.directory~new
::method accept guarded
  expose epochs renewals
  use strict arg lease
  known=epochs[lease~jobId]; if known==.nil then known=-1
  if lease~ownershipEpoch<known then return .false
  if lease~ownershipEpoch>known then epochs[lease~jobId]=lease~ownershipEpoch
  rk=lease~placementId
  prior=renewals[rk]; if prior==.nil then prior=-1
  if lease~renewalSequence<prior then return .false
  if lease~renewalSequence>prior then renewals[rk]=lease~renewalSequence
  return .true

::class ManagedRuntimeRegistry public
::method init
  expose runtimes
  runtimes=.directory~new
::method register
  expose runtimes
  use strict arg runtimeId, executable
  runtimes[runtimeId~string~upper]=executable~string
  return self
::method executable
  expose runtimes
  use strict arg runtimeId
  return runtimes[runtimeId~string~upper]

::class ManagedShell public
::method quote class
  use strict arg text
  t=text~string; q="27"x; dq="22"x; rep=q||dq||q||dq||q
  return q||changestr(q,t,rep)||q
::method safeId class
  use strict arg valueArg
  s=valueArg~string; out=""
  do i=1 to s~length
    c=s~substr(i,1)
    if datatype(c,"M") | datatype(c,"N") | c="-" | c="_" then out=out||c
    else out=out||"-"
  end
  if out="" then out="task"
  if out~length>80 then out=out~left(80)
  return out

::class ManagedCommandExecutionResult public
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute timedOut get
::attribute outputTruncated get
::method init
  expose rc stdout stderr timedOut outputTruncated
  use strict arg rcArg,outArg="",errArg="",timeoutArg=.false,truncatedArg=.false
  rc=rcArg+0; stdout=outArg~string; stderr=errArg~string; timedOut=(timeoutArg==.true); outputTruncated=(truncatedArg==.true)

::class ManagedSystemExecutor public
::attribute sequence
::method init
  expose sequence
  sequence=0
::method run
  expose sequence
  use strict arg executable,entrypoint,arguments,workingDirectory,timeoutSeconds,maxOutputBytes
  sequence+=1
  stem=value("TMPDIR",,"ENVIRONMENT"); if stem="" then stem="/tmp"
  base=stem||"/oorexx_managed_node_"||time("S")||"_"||sequence
  outFile=base||".out"; errFile=base||".err"
  cmd="cd "||.ManagedShell~quote(workingDirectory)||" && /usr/bin/timeout --signal=TERM "||timeoutSeconds||" "||.ManagedShell~quote(executable)||" "||.ManagedShell~quote(entrypoint)
  do a over arguments; cmd=cmd||" "||.ManagedShell~quote(a); end
  cmd=cmd||" >"||.ManagedShell~quote(outFile)||" 2>"||.ManagedShell~quote(errFile)
  address system cmd
  resultRc=rc
  o=self~readLimited(outFile,maxOutputBytes); e=self~readLimited(errFile,maxOutputBytes)
  address system "rm -f "||.ManagedShell~quote(outFile)||" "||.ManagedShell~quote(errFile)
  return .ManagedCommandExecutionResult~new(resultRc,o[1],e[1],resultRc=124,o[2] | e[2])
::method readLimited private
  use strict arg path,maxBytes
  if stream(path,"C","QUERY EXISTS")="" then return .array~of("",.false)
  s=.stream~new(path); s~open("READ"); n=s~chars; take=n; if take>maxBytes then take=maxBytes
  text=""; if take>0 then text=s~charin(,take); s~close
  return .array~of(text,n>maxBytes)

::class ManagedStageResult public
::attribute ok get
::attribute code get
::attribute root get
::attribute detail get
::method init
  expose ok code root detail
  use strict arg okArg,codeArg,rootArg="",detailArg=""
  ok=(okArg==.true); code=codeArg~string; root=rootArg~string; detail=detailArg~string

::class ManagedBundleStager public
::method init
  expose baseRoot digestProvider
  use strict arg baseRootArg,digestArg
  baseRoot=baseRootArg~string; digestProvider=digestArg
  if baseRoot="" | baseRoot="/" then raise syntax 88.900 array("unsafe managed-node staging root")
::method stage
  expose baseRoot digestProvider
  use strict arg bundle,attemptId
  root=baseRoot||"/"||.ManagedShell~safeId(attemptId)
  address system "rm -rf "||.ManagedShell~quote(root)||" && mkdir -p "||.ManagedShell~quote(root)
  if rc<>0 then return .ManagedStageResult~new(.false,"STAGE_ROOT_FAILED",root)
  do f over bundle~manifest~files
    dst=.WorkBundlePath~join(root,f~relativePath)
    slash=dst~lastPos("/"); parent=dst~left(slash-1)
    address system "mkdir -p "||.ManagedShell~quote(parent)
    if rc<>0 then return .ManagedStageResult~new(.false,"STAGE_DIRECTORY_FAILED",root,f~relativePath)
    s=.stream~new(f~sourcePath); s~open("READ"); n=s~chars; data=""; if n>0 then data=s~charin(,n); s~close
    d=.stream~new(dst); d~open("WRITE REPLACE"); if data~length>0 then d~charout(data); d~close
    if digestProvider~digestFile(dst)<>f~sha256 then return .ManagedStageResult~new(.false,"STAGED_FILE_DIGEST_MISMATCH",root,f~relativePath)
  end
  return .ManagedStageResult~new(.true,"OK",root)
::method clean
  expose baseRoot
  use strict arg root
  if root="" | root=baseRoot | \root~startsWith(baseRoot||"/") then return .false
  address system "rm -rf "||.ManagedShell~quote(root)
  return rc=0

::class ManagedTaskResult public
::attribute success get
::attribute code get
::attribute jobId get
::attribute taskId get
::attribute placementId get
::attribute ownershipEpoch get
::attribute attemptId get
::attribute nodeId get
::attribute bundleDigest get
::attribute rc get
::attribute stdout get
::attribute stderr get
::attribute outputTruncated get
::attribute cleanupOk get
::method init
  expose success code jobId taskId placementId ownershipEpoch attemptId nodeId bundleDigest rc stdout stderr outputTruncated cleanupOk
  use arg okArg=.false,codeArg="",jobArg="",taskArg="",placementArg="",epochArg=0,attemptArg="",nodeArg="",bundleDigestArg="",rcArg=0,outArg="",errArg="",truncatedArg=.false,cleanupArg=.true
  success=(okArg==.true); code=codeArg~string; jobId=jobArg~string; taskId=taskArg~string; placementId=placementArg~string; ownershipEpoch=epochArg+0; attemptId=attemptArg~string; nodeId=nodeArg~string; bundleDigest=bundleDigestArg~string; rc=rcArg+0; stdout=outArg~string; stderr=errArg~string; outputTruncated=(truncatedArg==.true); cleanupOk=(cleanupArg==.true)
::method queuePersistentType
  return "managed.task.result/0.1"
::method queuePersistentState
  expose success code jobId taskId placementId ownershipEpoch attemptId nodeId bundleDigest rc stdout stderr outputTruncated cleanupOk
  t=.table~new; t["success"]=success; t["code"]=code; t["jobId"]=jobId; t["taskId"]=taskId; t["placementId"]=placementId; t["ownershipEpoch"]=ownershipEpoch; t["attemptId"]=attemptId; t["nodeId"]=nodeId; t["bundleDigest"]=bundleDigest; t["rc"]=rc; t["stdout"]=stdout; t["stderr"]=stderr; t["outputTruncated"]=outputTruncated; t["cleanupOk"]=cleanupOk; return t
::method queueRestoreState
  expose success code jobId taskId placementId ownershipEpoch attemptId nodeId bundleDigest rc stdout stderr outputTruncated cleanupOk
  use strict arg s
  success=(s["success"]==.true); code=s["code"]~string; jobId=s["jobId"]~string; taskId=s["taskId"]~string; placementId=s["placementId"]~string; ownershipEpoch=s["ownershipEpoch"]+0; attemptId=s["attemptId"]~string; nodeId=s["nodeId"]~string; bundleDigest=s["bundleDigest"]~string; rc=s["rc"]+0; stdout=s["stdout"]~string; stderr=s["stderr"]~string; outputTruncated=(s["outputTruncated"]==.true); cleanupOk=(s["cleanupOk"]==.true); return self

::class ManagedTaskResultFactory public
::method newBlank
  return .ManagedTaskResult~new

::class ManagedAgentCycleResult public
::attribute ok get
::attribute code get
::attribute result get
::method init
  expose ok code result
  use strict arg okArg,codeArg,resultArg=.nil
  ok=(okArg==.true); code=codeArg~string; result=resultArg

::class ManagedNodeAgent public
::method init
  expose nodeId queueManager workQueue principal bundleRepository bundleVerifier taskAuthVerifier placementVerifier runtimeRegistry stager executor fence attempts resultPersistent
  use strict arg nodeArg,managerArg,workQueueArg,principalArg,bundleRepoArg,bundleVerifierArg,taskAuthVerifierArg,placementVerifierArg,runtimeRegistryArg,stagerArg,executorArg=.nil,fenceArg=.nil,resultPersistentArg=.true
  nodeId=nodeArg~string; queueManager=managerArg; workQueue=workQueueArg~string; principal=principalArg~string; bundleRepository=bundleRepoArg; bundleVerifier=bundleVerifierArg; taskAuthVerifier=taskAuthVerifierArg; placementVerifier=placementVerifierArg; runtimeRegistry=runtimeRegistryArg; stager=stagerArg
  if executorArg==.nil then executor=.ManagedSystemExecutor~new; else executor=executorArg
  if fenceArg==.nil then fence=.ManagedNodeAttemptFence~new; else fence=fenceArg
  attempts=.directory~new; resultPersistent=(resultPersistentArg==.true)
::method runOnce
  expose nodeId queueManager workQueue principal attempts resultPersistent
  use strict arg nowEpochMs
  claimed=queueManager~claim(workQueue,principal)
  if \claimed~ok then do
    if claimed~code="QUEUE_EMPTY" then return .ManagedAgentCycleResult~new(.true,"IDLE")
    return .ManagedAgentCycleResult~new(.false,"CLAIM_FAILED")
  end
  pkg=claimed~value
  taskResult=self~process(pkg~payload,nowEpochMs)
  if taskResult==.nil then do; ignore=queueManager~nack(workQueue,pkg~packageId,pkg~claimToken,principal); return .ManagedAgentCycleResult~new(.false,"INVALID_DISPATCH"); end
  opts=.table~new; opts["correlationId"]=taskResult~placementId; opts["persistent"]=resultPersistent; opts["priority"]=.ManagedTaskPriority~CONTROL
  delivered=queueManager~put(pkg~payload~payload~spec~resultQueue,taskResult,opts,principal)
  if \delivered~ok then do
    ignore=queueManager~nack(workQueue,pkg~packageId,pkg~claimToken,principal)
    return .ManagedAgentCycleResult~new(.false,"RESULT_DELIVERY_FAILED",taskResult)
  end
  acked=queueManager~ack(workQueue,pkg~packageId,pkg~claimToken,principal)
  if \acked~ok then return .ManagedAgentCycleResult~new(.false,"ACK_FAILED",taskResult)
  return .ManagedAgentCycleResult~new(.true,"PROCESSED",taskResult)
::method process private
  expose nodeId bundleRepository bundleVerifier taskAuthVerifier placementVerifier runtimeRegistry stager executor fence attempts
  use strict arg envelope,nowEpochMs
  if envelope==.nil | \envelope~hasMethod("PLACEMENTLEASE") | \envelope~hasMethod("PAYLOAD") then return .nil
  lease=envelope~placementLease
  code=placementVerifier~verify(envelope,nodeId,nowEpochMs)
  if code<>"OK" then return self~failure(envelope,code)
  if \fence~accept(lease) then return self~failure(envelope,"PLACEMENT_FENCED")
  request=envelope~payload
  if request==.nil | request~spec==.nil then return self~failure(envelope,"TASK_REQUEST_MISSING")
  spec=request~spec
  if spec~taskId<>lease~jobId then return self~failure(envelope,"TASK_JOB_MISMATCH")
  code=taskAuthVerifier~verify(request~authorization,spec,lease,nowEpochMs)
  if code<>"OK" then return self~failure(envelope,code)
  bundle=bundleRepository~fetch(spec~bundleRef)
  if bundle==.nil then return self~failure(envelope,"BUNDLE_NOT_FOUND")
  checked=bundleVerifier~verify(bundle,nowEpochMs)
  if \checked~ok then return self~failure(envelope,checked~code)
  if bundle~digest<>spec~bundleRef~digest then return self~failure(envelope,"BUNDLE_REFERENCE_MISMATCH")
  if \bundle~manifest~hasEntrypoint(spec~entrypoint) then return self~failure(envelope,"ENTRYPOINT_NOT_DECLARED")
  if \bundle~manifest~permitsKind(spec~kind) then return self~failure(envelope,"TASK_KIND_NOT_PERMITTED")
  if \bundle~manifest~requiresRuntime(spec~runtimeId) then return self~failure(envelope,"RUNTIME_NOT_PERMITTED")
  /* FETCH remains API Client-owned and SERVICE requires desired-state
   * reconciliation. Do not emulate either through the generic command path. */
  if spec~kind=.ManagedTaskKind~FETCH then return self~failure(envelope,"FETCH_RUNNER_NOT_IMPLEMENTED")
  if spec~kind=.ManagedTaskKind~SERVICE then return self~failure(envelope,"SERVICE_RECONCILER_NOT_IMPLEMENTED")
  executable=runtimeRegistry~executable(spec~runtimeId)
  if executable==.nil then return self~failure(envelope,"RUNTIME_UNAVAILABLE")
  attemptId=lease~placementId||":"||lease~ownershipEpoch||":"||spec~taskId
  prior=attempts[attemptId]
  if prior<>.nil then return prior
  staged=stager~stage(bundle,attemptId)
  if \staged~ok then do; taskResult=self~failure(envelope,staged~code); attempts[attemptId]=taskResult; return taskResult; end
  execResult=executor~run(executable,spec~entrypoint,spec~arguments,staged~root,spec~timeoutSeconds,spec~maxOutputBytes)
  cleanupOk=stager~clean(staged~root)
  if execResult~timedOut then taskResult=.ManagedTaskResult~new(.false,"TIMED_OUT",lease~jobId,spec~taskId,lease~placementId,lease~ownershipEpoch,attemptId,nodeId,bundle~digest,execResult~rc,execResult~stdout,execResult~stderr,execResult~outputTruncated,cleanupOk)
  else if execResult~rc=0 then taskResult=.ManagedTaskResult~new(.true,"COMPLETED",lease~jobId,spec~taskId,lease~placementId,lease~ownershipEpoch,attemptId,nodeId,bundle~digest,execResult~rc,execResult~stdout,execResult~stderr,execResult~outputTruncated,cleanupOk)
  else taskResult=.ManagedTaskResult~new(.false,"EXECUTION_FAILED",lease~jobId,spec~taskId,lease~placementId,lease~ownershipEpoch,attemptId,nodeId,bundle~digest,execResult~rc,execResult~stdout,execResult~stderr,execResult~outputTruncated,cleanupOk)
  if \cleanupOk & taskResult~success then taskResult=.ManagedTaskResult~new(.false,"CLEANUP_FAILED",lease~jobId,spec~taskId,lease~placementId,lease~ownershipEpoch,attemptId,nodeId,bundle~digest,execResult~rc,execResult~stdout,execResult~stderr,execResult~outputTruncated,.false)
  attempts[attemptId]=taskResult
  return taskResult
::method failure private
  expose nodeId
  use strict arg envelope,code
  lease=.nil; request=.nil; spec=.nil
  if envelope<>.nil then do; lease=envelope~placementLease; request=envelope~payload; end
  task=""; digest=""; placement=""; job=""; epoch=0; attempt=""
  if lease<>.nil then do; placement=lease~placementId; job=lease~jobId; epoch=lease~ownershipEpoch; end
  if request<>.nil then if request~spec<>.nil then do; spec=request~spec; task=spec~taskId; digest=spec~bundleRef~digest; end
  if placement<>"" & task<>"" then attempt=placement||":"||epoch||":"||task
  return .ManagedTaskResult~new(.false,code,job,task,placement,epoch,attempt,nodeId,digest)

::class ManagedNodeQueueTypes public
::method register class
  use strict arg payloadCodec
  if payloadCodec==.nil | \payloadCodec~hasMethod("TYPEREGISTRY") then return .false
  ignore=.WorkBundleQueueTypes~register(payloadCodec)
  r=payloadCodec~typeRegistry
  r~register("managed.task.spec/0.1",.ManagedTaskSpecFactory~new)
  r~register("managed.task.authorization/0.1",.ManagedTaskAuthorizationFactory~new)
  r~register("managed.task.request/0.1",.ManagedTaskRequestFactory~new)
  r~register("managed.node.dispatch/0.1",.ManagedNodeDispatchEnvelopeFactory~new)
  r~register("managed.task.result/0.1",.ManagedTaskResultFactory~new)
  return .true

::requires "WorkBundle.cls"
::requires "JobNodeAllocator.cls"
::requires "ObjectQueueFabric.cls"

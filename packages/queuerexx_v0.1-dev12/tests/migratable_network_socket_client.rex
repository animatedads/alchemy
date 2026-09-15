bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPortFile serverPortFile resultFile keyHex
call prepareQueueRoot root
qid="FD-NETWORK-MANAGED-1"
call writeRunning root,qid
codec=.QueueGraphPayloadCodec~new
manager=.ObjectQueueManager~new(root||"/fabric",codec,"A-admin")
transport=.QueueSocketClientTransport~new("A-admin",codec)
fabric=.QueueChannelFabric~new("NODE-A",manager,transport,"A-admin")
listener=.QueueSocketListener~new("NODE-A","127.0.0.1",0,fabric,codec)
mesh=.QueueRexxPeerMeshRuntime~new("A",root,"NODE-A",manager,fabric,transport,listener,"A-admin",.TestDigest~new)
ignore=listener~trustPeer("NODE-B","mesh-ab","k1",keyHex,.array~of("127.0.0.1"))
if \mesh~startListener then do; say "FAIL client listener" listener~lastError; exit 71; end
call lineout clientPortFile,listener~port; call lineout clientPortFile
serverPort=""
do i=1 to 400
  if stream(serverPortFile,"c","query exists")<>"" then do
    f=.stream~new(serverPortFile); f~open("read"); serverPort=f~linein~strip; f~close
    if serverPort<>"" then leave
  end
  call SysSleep 0.025
end
if serverPort="" then do; say "FAIL server port"; exit 72; end
peer=mesh~bindSocketPeer("B","NODE-B","127.0.0.1",serverPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),.array~of(.QueueRexxPeerOperation~HEALTH),10000)
call must peer,"bind peer"
health=mesh~client~request("B",.QueueRexxPeerOperation~HEALTH,.directory~new,.directory~new,0,0,"mj-health")
call must health,"mesh health"
call assert health~value["decision"]="APPROVE","health approval"
created=.QueueRexxJobNodePeerClientFactory~create(mesh,"B","FD-CLIENT","JNA.REPLY.FD-CLIENT","jna-client","JNA.REQUEST")
call must created,"network1 client"
call assert created~value["client"]~isA(.JobNodeNetworkAllocatorClient),"exact JobNodeNetworkAllocatorClient"
proxy=created~value["allocator_proxy"]

/* The FD side has the workload definition and queue state, but no local
 * JobNodeAllocator, NodeCapabilityRegistry authority, or ownership registry. */
placement=.JobPlacementRequest~new(qid,.JobNodeRequirement~new,"FD-OWNER",1000,1000)
definition=.MigratableJobDefinition~new(qid,placement,"definition:fd-network","P1","FD-OWNER","OOREXX","5.3-r13196","fd-rev1")
app=.PrivateFDStartApplication~new(definition,root)
digest=.TestDigest~new
receipts=.MigratableJobStartReceiptStore~new(root||"/start.receipts",digest)
starter=.MigratableJobStarter~new(app,receipts)
intent=.QueueRexxMigratableStartIntentStore~new(root)
placedExecutor=.QueueRexxPlacedStartExecutor~new(starter,app,proxy,root,.AllowPolicy~new,.nil,intent)
remoteTool=.QueueRexxRemoteManagedPlacementTool~new(app,proxy,placedExecutor,.nil,digest)
managed=.QueueRexxManagedPlacementFacade~new(remoteTool,intent)
startReq=.MigratableJobStartRequest~new("FD-NET-START-1","NEW",qid,definition~definitionRef,definition~partitionId,"",300001)

plan=managed~plan(startReq,300100,"network-plan")
call assert plan~ok & plan~code="PLAN_READY","remote PLAN"
call equal plan~plan~recommendedNodeId,"FD-AUTH-NODE","PLAN node"
allocated=managed~allocate(startReq,300200,30000,"network-allocate")
call assert allocated~ok & wordpos(allocated~code,"PLACED PLACED_REPLAY")>0,"remote ALLOCATE"
lease=allocated~lease
call assert lease<>.nil,"lease"
call equal lease~nodeId,"FD-AUTH-NODE","lease node"
call equal lease~ownerNodeId,"FD-OWNER","lease owner"
checked=managed~check(startReq,lease,300250,"network-check")
call assert checked~ok & checked~code="PLACEMENT_CURRENT","remote CHECK"
renewed=proxy~renewPlacement(lease,placement,300300,30000)
call assert renewed~placed & renewed~code="RENEWED","remote RENEW"
lease2=renewed~lease
call assert lease2~renewalSequence>lease~renewalSequence,"renewal sequence"

/* Migratable Job checks the lease, then QueueRexxPlacedStartExecutor performs
 * a second exact remote CHECK while holding the shared QID lock immediately
 * before migratable.job.start/1 enters the private workload. */
started=managed~start(startReq,lease2,300350,"network-start")
call assert started~ok & started~code="RUNNING","remote START"
call assert app~starts=1 & app~sawLock,"private worker exactly once under QID lock"
call equal app~lastStartId,startReq~startId,"starter binding"
started2=managed~start(startReq,lease2,300360,"network-start-replay")
call assert started2~ok & started2~startResult<>.nil & started2~startResult~replayed,"starter replay"
call assert app~starts=1,"no duplicate worker"
released=managed~release(startReq,lease2,300400,"network-release","qualification cleanup")
call assert released~ok & released~code="RELEASED" & \released~placementHeld,"remote RELEASE"

loaded=intent~load(qid)
call assert loaded~valid & loaded~request<>.nil,"durable NEW intent"
call equal loaded~request~canonical,startReq~canonical,"intent canonical"
call lineout resultFile,"node="||lease2~nodeId||";placement="||lease2~placementId||";starts="||app~starts||";replayed="||started2~startResult~replayed||";auth="||listener~authenticatedCount||";accepted="||listener~acceptedCount
call lineout resultFile
ignore=listener~stop
exit 0

prepareQueueRoot: procedure
  use arg root
  address system "rm -rf "||root
  call SysMkDir root
  do dir over .Array~of("pending","waiting","running","paused","pol_blocked","done","failed","cancelled","interrupted","logs","locks")
    call SysMkDir root||"/"||dir
  end
  call SysMkDir root||"/locks/state"
  return
writeRunning: procedure
  use arg root,qid
  s=.Stream~new(root||"/running/"||qid||".job"); if s~open("WRITE REPLACE")<>"READY:" then return .false
  s~lineOut("JOB_ID='"||qid||"'"); s~lineOut("JOB_NAME='fd private network'"); s~lineOut("JOB_CLASS='DEFAULT'"); s~lineOut("PRIORITY='10'"); s~lineOut("COMMAND=('sleep' '100')"); s~lineOut("RUNNER_USED='direct'"); s~close; return .true
must: procedure
  use arg r,label
  if r==.nil | \r~ok then do; say "FAIL" label; if r<>.nil then say r~code r~detail; exit 70; end
  return
assert: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 73; end
  return
equal: procedure
  use arg got,want,label
  if got<>want then do; say "FAIL" label got want; exit 74; end
  return
::class PrivateFDStartApplication subclass MigratableJobStarterApplication
::attribute starts
::attribute sawLock
::attribute lastStartId
::method init
  expose def root starts sawLock lastStartId
  use strict arg definitionArg,rootArg
  def=definitionArg; root=rootArg~string; starts=0; sawLock=.false; lastStartId=""
::method definition
  expose def
  use strict arg request
  return def
::method startNew
  expose root starts sawLock lastStartId
  use strict arg request,definition
  starts+=1; lastStartId=request~startId; sawLock=SysFileExists(root||"/locks/state/"||definition~jobId||".lock")
  return .MigratableJobResumeResult~success("fd-private:"||request~startId)
::class AllowPolicy subclass QueueOperationPolicyGate
::method assessExecution
  use strict arg record
  return .QueuePolicyVerdict~allow("TEST_ALLOW")
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxMigratableNetwork.cls"
::requires "QueueRexxMigratableJob.cls"
::requires "CryptoForeignRuntimeProvider.cls"

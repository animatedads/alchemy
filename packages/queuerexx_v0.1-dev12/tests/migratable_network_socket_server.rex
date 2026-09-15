bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPort serverPortFile resultFile keyHex
now=300000
qid="FD-NETWORK-MANAGED-1"
registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("FD-AUTH-NODE",3))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("FD-AUTH-NODE",3,8,now,now+600000,16384,16384,8,8000000,0,0))
stack=.QueueRexxAuthorityStack~new(root,registry,.JobNodeEligibilityPolicy~new,.nil,"QUEUEREXX","queue","mj-network1","NODE-B","127.0.0.1",0,"B-admin",now,.TestDigest~new,.nil)
mesh=stack~enablePeerMesh("B",.TestDigest~new)
peer=mesh~bindSocketPeer("A","NODE-A","127.0.0.1",clientPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),.array~of(.QueueRexxPeerOperation~HEALTH),10000)
call must peer,"bind peer"
jna=stack~bindPeerClient("FD-CLIENT","A","JNA.REPLY.FD-CLIENT",.array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE"),"FD-OWNER")
call must jna,"bind JNA"
if \stack~startListener then do; say "FAIL listener" stack~listener~lastError; exit 61; end
call lineout serverPortFile,stack~listener~port; call lineout serverPortFile
/* HEALTH + PLAN + ALLOCATE + CHECK + RENEW + START(2 CHECK) + replay START(2 CHECK) + RELEASE. */
do i=1 to 10
  t=stack~serveTransportOne; call must t,"transport"
  n=stack~drainNetwork(0); call must n,"network drain"
  p=stack~drainPeerControl; call must p,"peer drain"
end
/* Final release must have removed central ownership. */
if stack~ownership~current(qid,310000)<>.nil then do; say "FAIL ownership survived release"; exit 62; end
call lineout resultFile,"auth="||stack~listener~authenticatedCount||";accepted="||stack~listener~acceptedCount
call lineout resultFile
ignore=stack~listener~stop
exit 0
must: procedure
  use arg r,label
  if r==.nil | \r~ok then do; say "FAIL" label; if r<>.nil then say r~code r~detail; exit 60; end
  return
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxAuthority.cls"
::requires "CryptoForeignRuntimeProvider.cls"

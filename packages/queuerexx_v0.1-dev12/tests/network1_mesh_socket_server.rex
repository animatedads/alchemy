bridge=value("QF_CRYPTO_FOREIGN_BRIDGE",,"ENVIRONMENT")
if bridge<>"" then ignore=.CryptoForeignRuntimeInstaller~install(bridge)
parse arg root clientPort serverPortFile resultFile keyHex
now=200000
registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NET-NODE-B",1,"proof-b",.array~of("UK"),.array~of("AUDIO"),.array~of("TRUSTED"),.nil,.nil,.array~of("OOREXX"),.nil,"X86_64",16384,100000,8,"r1"))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NET-NODE-B",1,1,now,now+600000,12000,90000,7,9000,0,0,"obs-b"))
stack=.QueueRexxAuthorityStack~new(root,registry,.JobNodeEligibilityPolicy~new,.nil,"QUEUEREXX","queue","socket-mesh","NODE-B","127.0.0.1",0,"B-admin",now,.TestDigest~new,.nil)
mesh=stack~enablePeerMesh("B",.TestDigest~new)
peer=mesh~bindSocketPeer("A","NODE-A","127.0.0.1",clientPort,"mesh-ab","k1",keyHex,.array~of("127.0.0.1"),.array~of(.QueueRexxPeerOperation~HEALTH),10000)
call must peer,"bind peer"
jna=stack~bindPeerClient("FD-A","A","JNA.REPLY.FD-A",.array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE"),"OWNER-A")
call must jna,"bind JNA"
if \stack~startListener then do; say stack~listener~lastError; exit 41; end
call lineout serverPortFile,stack~listener~port; call lineout serverPortFile
do i=1 to 4
  t=stack~serveTransportOne; call must t,"transport"
  n=stack~drainNetwork(0); call must n,"network drain"
  p=stack~drainPeerControl; call must p,"peer drain"
end
call lineout resultFile,"auth="||stack~listener~authenticatedCount||";accepted="||stack~listener~acceptedCount
call lineout resultFile
ignore=stack~listener~stop
exit 0
must: procedure
  use arg r,label
  if r==.nil | \r~ok then do; say "FAIL" label; if r<>.nil then say r~code r~detail; exit 40; end
  return
::class TestDigest public
::method digest
  use strict arg text
  return "D:"||c2x(text~string)
::requires "QueueRexxAuthority.cls"
::requires "CryptoForeignRuntimeProvider.cls"

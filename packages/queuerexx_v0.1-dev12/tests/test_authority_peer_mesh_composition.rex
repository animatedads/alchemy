root="/mnt/data/queuerexx-dev12-authority-mesh-composition"
address system "rm -rf "||root
call SysMkDir root

registry=.NodeCapabilityRegistry~new
ignore=registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-A",1))
ignore=registry~observeCapacity(.NodeCapacityObservation~new("NODE-A",1,1,1000,5000,8192,16384,8,4000000,0,0,"NODE-A-PROOF"))

stack=.QueueRexxAuthorityStack~new(root,registry,.nil,.nil,"QUEUEREXX","queue","QRX-DEV12","NODE-A","127.0.0.1",0,"qrx-admin",1000,.TestDigest~new)
mesh=stack~enableStandardPeerChecks("A","NODE-A",.TestPolicyProvider~new,.TestDigest~new)
if mesh==.nil | stack~peerMesh<>mesh then call fail "peer mesh not retained by authority stack"
if mesh~managerName<>stack~managerName then call fail "mesh manager differs from authority Queue Fabric manager"
if mesh~service~handler(.QueueRexxPeerOperation~JOB_CHECK)==.nil then call fail "JOB_CHECK handler not installed"
if mesh~service~handler(.QueueRexxPeerOperation~POLICY_CHECK)==.nil then call fail "POLICY_CHECK handler not installed"
if mesh~service~handler(.QueueRexxPeerOperation~LOAD_CHECK)==.nil then call fail "LOAD_CHECK handler not installed"
if mesh~service~handler(.QueueRexxPeerOperation~AUTHORIZE)<>.nil then call fail "semantic authorization was fabricated from transport trust"

ops=.array~of(.QueueRexxPeerOperation~AUTHORIZE,.QueueRexxPeerOperation~JOB_CHECK,.QueueRexxPeerOperation~LOAD_CHECK,.QueueRexxPeerOperation~HEALTH)
bound=mesh~bindFabricPeer("B","NODE-B","mesh-ab",ops,1000)
if \bound~ok then call fail "peer bind "||bound~code||" "||bound~detail
if stack~queueManager~queue("QRX.PEER.REQUEST.B")==.nil then call fail "peer request queue not in authority Queue Fabric manager"
if stack~queueManager~queue("QRX.PEER.REPLY.B")==.nil then call fail "peer reply queue not in authority Queue Fabric manager"
if stack~queueManager~queue("QRX.PEER.XMIT.B")==.nil then call fail "peer transmission queue not in authority Queue Fabric manager"

say "PASS QueueRexx dev12 authority/mesh composition: one Queue Fabric manager, exact JTN authority retained, standard job/policy/load projections installed, semantic AUTHORIZE remains explicit"
exit 0

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::class TestPolicyProvider public
::attribute id get
::attribute version get
::method init
  expose id version
  id="test-policy"; version="1"
::method assess
  use strict arg record
  return .QueuePolicyAssessment~new(.QueuePolicyAssessment~ALLOW,"TEST_ALLOW","test only",self~id,self~version,.directory~new)

::requires "QueueRexxAuthority.cls"

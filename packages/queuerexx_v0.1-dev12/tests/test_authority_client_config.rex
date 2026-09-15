root="/mnt/data/queuerexx-dev12-authority-client-config"
address system "rm -rf "||root
call SysMkDir root

registry=.NodeCapabilityRegistry~new
if \registry~advertiseCapability(.NodeCapabilityStatement~new("NODE-CONFIG",1)) then call fail "capability"
if \registry~observeCapacity(.NodeCapacityObservation~new("NODE-CONFIG",1,1,1000,5000,4096,4096,4,1000000,0,0)) then call fail "capacity"

cfg=.directory~new
cfg["schema"]="queuerexx.job-node.authority-clients/1"
clients=.array~new
c=.directory~new
c["client_id"]="FD-CONFIG"
c["client_manager"]="FD-CONFIG"
c["transport_principal"]="wire-config"
c["key_id"]="k-config"
c["key_hex"]=copies("55",64)
c["allowed_source_ips"]=.Array~of("127.0.0.1")
c["remote_host"]="127.0.0.1"
c["remote_port"]=9
c["client_reply_queue"]="FD.REPLY"
c["client_reply_receiver_channel"]="FD.RECV.AUTH"
c["operations"]=.Array~of("PLAN","ALLOCATE","CHECK","RENEW","RELEASE")
c["owner_node_id"]="FD-OWNER"
clients~append(c); cfg["clients"]=clients
configPath=root||"/authority-clients.json"
.QueueSerialization~toJsonFile(cfg,configPath)

stack=.QueueRexxAuthorityStack~new(root,registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-CONFIG","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
provider=.QueueRexxAuthorityClientConfig~new(configPath)
loaded=provider~load
if \loaded~ok | loaded~value~items<>1 then call fail "load "||loaded~code||" "||loaded~detail
server=.QueueRexxAuthorityServer~new(stack,provider)
started=server~start
if \started~ok then call fail "server start "||started~code||" "||started~detail
binding=stack~clientBindings["FD-CONFIG"]
if binding==.nil then call fail "binding absent"
if binding~ownerNodeId<>"FD-OWNER" then call fail "binding owner"
allowed=.JobPlacementRequest~new("CFG-ALLOW",.JobNodeRequirement~new,"FD-OWNER",0,0)
denied=.JobPlacementRequest~new("CFG-DENY",.JobNodeRequirement~new,"OTHER",0,0)
if \stack~accessPolicy~authorised("FD-CONFIG","ALLOCATE",allowed) then call fail "binding policy allow"
if stack~accessPolicy~authorised("FD-CONFIG","ALLOCATE",denied) | stack~accessPolicy~authorised("FD-CONFIG","BOGUS",allowed) then call fail "binding policy deny"
if stack~queueManager~queue(stack~requestQueue)==.nil then call fail "request queue absent"
if stack~channels~remoteQueue(binding~replyAlias)==.nil then call fail "reply route absent"
ignore=server~stop

/* Changed/malformed config is rejected before listener startup. */
bad=.directory~new; bad["schema"]="queuerexx.job-node.authority-clients/1"; rows=.array~new; broken=.directory~new; broken["client_id"]="BROKEN"; rows~append(broken); bad["clients"]=rows
badPath=root||"/bad.json"; .QueueSerialization~toJsonFile(bad,badPath)
stack2=.QueueRexxAuthorityStack~new(root||"/badroot",registry,.nil,.nil,"QUEUEREXX","queue","QRX-CONFIG","AUTH-BAD","127.0.0.1",0,"auth-admin",1000,.TestDigest~new)
badServer=.QueueRexxAuthorityServer~new(stack2,.QueueRexxAuthorityClientConfig~new(badPath))
r=badServer~start
if r~ok | r~code<>"AUTHORITY_CLIENT_CONFIG_INVALID" then call fail "bad config not fail closed"
if badServer~running then call fail "bad config started listener"

say "PASS QueueRexx dev12 bootstrap authority-client configuration: legacy combined peer/JNA JSON restores the general peer first, then exact network1 ACL/reply binding before listen; malformed configuration fails closed"
exit 0

fail: procedure
  parse arg message
  say "FAIL" message
  exit 1

::class TestDigest public
::method digest
  use strict arg text
  return c2x(text~string)

::requires "QueueRexxAuthority.cls"

/* Semantic qualification; does not require nftables or QueueRexx. */
call testIpv4
call testBlockPolicy
call testProtected
call testPeerIdentity
call testReplay
say "PASS firewall.control/0.1 semantic qualification"
exit 0

fail:
  say "FAIL" condition("D")
  exit 1

testIpv4:
  call assertEqual "198.51.100.148", .FirewallControlCodec~normaliseIpv4("198.51.100.148"), "normalise IPv4"
  call assertEqual "198.51.100.0/24", .FirewallControlCodec~network24("198.51.100.148"), "derive /24"
  call assertEqual "", .FirewallControlCodec~normaliseIpv4("999.1.2.3"), "reject invalid IPv4"
  return

testBlockPolicy:
  p=.FirewallMemoryProvider~new
  protected=.FirewallProtectedSources~new
  access=.FirewallPeerAccessPolicy~new~allow("REXXOS1")
  service=.FirewallControlService~new("GATEWAY",p,protected,access)
  started=service~start
  call assertTrue started~ok, "provider ready"
  req=.FirewallControlCodec~newRequest("r1","REXXOS1","GATEWAY",.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,"198.51.100.148","HOSTILE_HTTPS_SCAN","access-1040")
  res=service~handleFrom("REXXOS1",req)
  call assertEqual "OK",res["status"],"block status"
  call assertEqual "BLOCKED",res["code"],"block code"
  call assertEqual 1440,p~exactMinutes("198.51.100.148"),"exact 1440 minutes"
  call assertEqual 10,p~networkMinutes("198.51.100.0/24"),"/24 10 minutes"
  return

testProtected:
  p=.FirewallMemoryProvider~new
  protected=.FirewallProtectedSources~new~protect("192.0.2.44")
  access=.FirewallPeerAccessPolicy~new~allow("REXXOS1")
  service=.FirewallControlService~new("GATEWAY",p,protected,access)
  req=.FirewallControlCodec~newRequest("r2","REXXOS1","GATEWAY",.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,"192.0.2.44")
  res=service~handleFrom("REXXOS1",req)
  call assertEqual "DENIED_PROTECTED_SOURCE",res["code"],"protected source denied"
  call assertEqual 0,p~operationCount,"protected source did not reach provider"
  return

testPeerIdentity:
  p=.FirewallMemoryProvider~new
  protected=.FirewallProtectedSources~new
  access=.FirewallPeerAccessPolicy~new~allow("REXXOS1")
  service=.FirewallControlService~new("GATEWAY",p,protected,access)
  req=.FirewallControlCodec~newRequest("r3","OTHER","GATEWAY",.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,"198.51.100.10")
  res=service~handleFrom("REXXOS1",req)
  call assertEqual "PEER_IDENTITY_MISMATCH",res["code"],"payload identity cannot forge peer"
  return

testReplay:
  p=.FirewallMemoryProvider~new
  protected=.FirewallProtectedSources~new
  access=.FirewallPeerAccessPolicy~new~allow("REXXOS1")
  service=.FirewallControlService~new("GATEWAY",p,protected,access)
  req=.FirewallControlCodec~newRequest("r4","REXXOS1","GATEWAY",.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,"198.51.100.10")
  res1=service~handleFrom("REXXOS1",req)
  res2=service~handleFrom("REXXOS1",req)
  call assertEqual "BLOCKED",res1["code"],"initial block"
  call assertEqual "REPLAY",res2["code"],"exact replay"
  call assertEqual 1,p~operationCount,"replay does not extend timeout"
  changed=.FirewallControlCodec~newRequest("r4","REXXOS1","GATEWAY",.FirewallControlOperation~BLOCK_HOSTILE_SOURCE,"198.51.100.11")
  res3=service~handleFrom("REXXOS1",changed)
  call assertEqual "REQUEST_ID_CONFLICT",res3["code"],"changed-content replay rejected"
  return

assertTrue: procedure
  use strict arg actual,label
  if actual==.true then return
  raise syntax 88.900 array(label)

assertEqual: procedure
  use strict arg expected,actual,label
  if expected==actual then return
  raise syntax 88.900 array(label,"expected="||expected,"actual="||actual)

::requires "../src/FirewallControl.cls"

parse arg root
if root = "" then root = directory()

say "RUNTIME REGISTRY LIVE RELOAD DEMO"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

f1 = .RuntimeArtifactFactory~fromFile("demo.capability", "CAPABILITY", "1.0.0", "fixture:capability:v1", "DemoCapability", root || "/fixtures/modules/DemoCapability_v1.cls")
f2 = .RuntimeArtifactFactory~fromFile("demo.capability", "CAPABILITY", "2.0.0", "fixture:capability:v2", "DemoCapability", root || "/fixtures/modules/DemoCapability_v2.cls")
if \f1~ok | \f2~ok then do
  say "fixture load failed"
  exit 2
end

v1 = f1~value
v2 = f2~value
pinResult = verifier~pin(v1~artifactId, v1~sourceLines)
pinResult = verifier~pin(v2~artifactId, v2~sourceLines)

stage1 = kernel~stage("prod", v1)
if \stage1~ok then do
  say stage1~code stage1~detail
  exit 3
end
g1 = stage1~value
activate1 = kernel~activate("prod", v1~moduleId, g1~generationId)

oldRequest = kernel~acquire("prod", v1~moduleId)~value
say "old request before upgrade:" oldRequest~module~answer("request-A")

stage2 = kernel~stage("prod", v2)
if \stage2~ok then do
  say stage2~code stage2~detail
  exit 4
end
g2 = stage2~value
activate2 = kernel~activate("prod", v2~moduleId, g2~generationId)

newRequest = kernel~acquire("prod", v2~moduleId)~value
say "old request after upgrade: " oldRequest~module~answer("request-A")
say "new request after upgrade: " newRequest~module~answer("request-B")
say "old generation state:      " g1~state "leases=" || g1~leaseCount
say "new generation state:      " g2~state "leases=" || g2~leaseCount

releaseResult = oldRequest~release
releaseResult = newRequest~release
collectResult = kernel~collectRetired
say "old generation after drain:" g1~state

rollback = kernel~activate("prod", v1~moduleId, g1~generationId)
if \rollback~ok then do
  say "rollback failed:" rollback~code rollback~detail
  exit 5
end
rollbackLease = kernel~acquire("prod", v1~moduleId)~value
say "rollback request:           " rollbackLease~module~answer("request-C")
releaseResult = rollbackLease~release

say "RUNTIME REGISTRY LIVE RELOAD DEMO: OK"
exit 0

::requires "src/RuntimeRegistry.cls"

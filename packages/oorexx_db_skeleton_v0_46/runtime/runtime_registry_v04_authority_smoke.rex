builder1 = .RuntimeBundleBuilder~new
r = builder1~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v1"
r = builder1~addFile("DatabaseCoreRuntimeModule_v1.cls", "DatabaseCoreRuntimeModule_v1.cls")
call assert r~ok, "add wrapper v1"
b1r = builder1~build
call assert b1r~ok, "build v1 bundle"

builder2 = .RuntimeBundleBuilder~new
r = builder2~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v2"
r = builder2~addFile("DatabaseCoreRuntimeModule_v2.cls", "DatabaseCoreRuntimeModule_v2.cls")
call assert r~ok, "add wrapper v2"
b2r = builder2~build
call assert b2r~ok, "build v2 bundle"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

a1 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.39-a", "dbcore:rr04:v1", -
  "DatabaseCoreRuntimeModule", b1r~value~sourceLines)
a2 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.39-b", "dbcore:rr04:v2", -
  "DatabaseCoreRuntimeModule", b2r~value~sourceLines)

pr = verifier~pin(a1~artifactId, a1~sourceLines)
call assert pr~ok, "pin v1"
pr = verifier~pin(a2~artifactId, a2~sourceLines)
call assert pr~ok, "pin v2"

s1 = kernel~stage("prod", a1)
call assert s1~ok, "stage v1"
g1 = s1~value
ar = kernel~activate("prod", "database.core", g1~generationId)
call assert ar~ok, "activate v1"

leaseResult = kernel~acquire("prod", "database.core")
call assert leaseResult~ok, "acquire v1"
lease = leaseResult~value
module1 = lease~module

/* v0.4: a lease may inspect its generation but cannot control lifecycle. */
heldGeneration = lease~generation
call assert heldGeneration~state = "ACTIVE", "held generation active"

if heldGeneration~hasMethod("BEGINDRAIN") then do
  unauthorizedDrain = heldGeneration~beginDrain
  call assert \unauthorizedDrain~ok, "direct beginDrain denied"
  call assert unauthorizedDrain~code = "LIFECYCLE_AUTHORITY_REQUIRED", "direct drain authority code"
end
else call assert .true, "read-only generation view exposes no beginDrain"
call assert heldGeneration~state = "ACTIVE", "denied drain leaves generation active"

if heldGeneration~hasMethod("RELEASEOBJECTS") then do
  unauthorizedRelease = heldGeneration~releaseObjects
  call assert \unauthorizedRelease~ok, "direct release denied"
  call assert unauthorizedRelease~code = "LIFECYCLE_AUTHORITY_REQUIRED", "direct release authority code"
end
else call assert .true, "read-only generation view exposes no releaseObjects"
call assert heldGeneration~state = "ACTIVE", "denied release leaves generation active"

/* Work pinned by the lease remains fully usable after failed lifecycle escape. */
tx1 = module1~beginTransaction
tx1~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")
call assert tx1~prepare~validate~status = module1~errorClass~SUCCESS, "held transaction validates"

/* Registry-owned activation performs the legitimate transition. */
s2 = kernel~stage("prod", a2)
call assert s2~ok, "stage v2"
g2 = s2~value
ar = kernel~activate("prod", "database.core", g2~generationId)
call assert ar~ok, "registry activates v2"
call assert g1~state = "DRAINING", "v1 draining after legitimate activation"
call assert g1~leaseCount = 1, "held v1 lease remains"

commit1 = tx1~commit
call assert commit1~status = module1~errorClass~SUCCESS, "held v1 transaction commits"

lease2Result = kernel~acquire("prod", "database.core")
call assert lease2Result~ok, "new v2 lease"
lease2 = lease2Result~value
module2 = lease2~module
call assert module2~generationLabel = "DBCORE-V2", "new work uses v2"
call assert module1~coreClass \== module2~coreClass, "generation class universes isolated"

rr = lease2~release
call assert rr~ok, "release v2"
rr = lease~release
call assert rr~ok, "release v1"
call assert g1~state = "RETIRED", "v1 retires after final lease"

releaseOld = kernel~releaseGeneration(g1~generationId)
call assert releaseOld~ok, "registry releases retired generation"
call assert g1~state = "RELEASED", "v1 released"

say "DATABASE CORE RUNTIME REGISTRY V0.4 AUTHORITY SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "RuntimeBundleBuilder.cls"

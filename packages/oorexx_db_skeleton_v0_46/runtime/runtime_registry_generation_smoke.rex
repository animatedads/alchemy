builder1 = .RuntimeBundleBuilder~new
r = builder1~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v1"
r = builder1~addFile("DatabaseCoreRuntimeModule_v1.cls", "DatabaseCoreRuntimeModule_v1.cls")
call assert r~ok, "add runtime wrapper v1"
b1r = builder1~build
call assert b1r~ok, "build v1 bundle"
bundle1 = b1r~value

builder2 = .RuntimeBundleBuilder~new
r = builder2~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v2"
r = builder2~addFile("DatabaseCoreRuntimeModule_v2.cls", "DatabaseCoreRuntimeModule_v2.cls")
call assert r~ok, "add runtime wrapper v2"
b2r = builder2~build
call assert b2r~ok, "build v2 bundle"
bundle2 = b2r~value

call assert bundle1~localRequiresRemoved~items = 1, "v1 local requires removed"
call assert bundle2~localRequiresRemoved~items = 1, "v2 local requires removed"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)

artifact1 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.38-a", -
  "dbcore:runtime:v1", "DatabaseCoreRuntimeModule", bundle1~sourceLines)
artifact2 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.38-b", -
  "dbcore:runtime:v2", "DatabaseCoreRuntimeModule", bundle2~sourceLines)

pinResult = verifier~pin(artifact1~artifactId, artifact1~sourceLines)
call assert pinResult~ok, "pin v1"
pinResult = verifier~pin(artifact2~artifactId, artifact2~sourceLines)
call assert pinResult~ok, "pin v2"

stage1 = kernel~stage("prod", artifact1)
call assert stage1~ok, "stage v1"
g1 = stage1~value
activate1 = kernel~activate("prod", "database.core", g1~generationId)
call assert activate1~ok, "activate v1"

lease1Result = kernel~acquire("prod", "database.core")
call assert lease1Result~ok, "acquire v1 lease"
lease1 = lease1Result~value
module1 = lease1~module
call assert module1~generationLabel = "DBCORE-V1", "held module is v1"

/* Begin real Database Core work before publication of the next generation. */
tx1 = module1~beginTransaction
tx1~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")
plan1 = tx1~prepare
call assert plan1~validate~status = module1~errorClass~SUCCESS, "v1 transaction validates"

stage2 = kernel~stage("prod", artifact2)
call assert stage2~ok, "stage v2"
g2 = stage2~value
activate2 = kernel~activate("prod", "database.core", g2~generationId)
call assert activate2~ok, "activate v2"
call assert g1~state = "DRAINING", "v1 drains"
call assert g1~leaseCount = 1, "v1 transaction lease remains held"
call assert module1~quiesces = 1, "v1 quiesce hook called"

/* Existing transaction remains owned by the old generation after publication. */
call assert module1~generationLabel = "DBCORE-V1", "held lease still v1"
commit1 = tx1~commit
call assert commit1~status = module1~errorClass~SUCCESS, "held v1 transaction commits after v2 publication"
call assert tx1~state = "committed", "v1 transaction committed"

lease2Result = kernel~acquire("prod", "database.core")
call assert lease2Result~ok, "acquire new v2 lease"
lease2 = lease2Result~value
module2 = lease2~module
call assert module2~generationLabel = "DBCORE-V2", "new work gets v2"

/* The two Database classes live in distinct generation-private packages. */
call assert module1~coreClass \== module2~coreClass, "database class universes are isolated"

tx2 = module2~beginTransaction
tx2~execute("UPDATE account SET balance = balance + 2 WHERE id = 1")
commit2 = tx2~commit
call assert commit2~status = module2~errorClass~SUCCESS, "v2 transaction commits"
call assert tx2~state = "committed", "v2 transaction committed"

release2 = lease2~release
call assert release2~ok, "release v2 lease"
call assert g1~state = "DRAINING", "v1 still drains while old lease held"

release1 = lease1~release
call assert release1~ok, "release v1 lease"
call assert g1~state = "RETIRED", "v1 retires on last lease release"

collect = kernel~collectRetired
call assert collect~ok, "collect retired"
releaseOld = kernel~releaseGeneration(g1~generationId)
call assert releaseOld~ok, "release old generation objects"
call assert g1~state = "RELEASED", "v1 generation released"

say "DATABASE CORE RUNTIME REGISTRY GENERATION SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "RuntimeBundleBuilder.cls"

builder1 = .RuntimeBundleBuilder~new
r = builder1~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v1"
r = builder1~addFile("DatabaseCoreRuntimeModule_v1.cls", "DatabaseCoreRuntimeModule_v1.cls")
call assert r~ok, "add wrapper v1"
b1 = builder1~build
call assert b1~ok, "build v1 bundle"

builder2 = .RuntimeBundleBuilder~new
r = builder2~addFile("database_core.cls", "database_core.cls")
call assert r~ok, "add database core v2"
r = builder2~addFile("DatabaseCoreRuntimeModule_v2.cls", "DatabaseCoreRuntimeModule_v2.cls")
call assert r~ok, "add wrapper v2"
b2 = builder2~build
call assert b2~ok, "build v2 bundle"

verifier = .RuntimePinnedSourceVerifier~new
kernel = .RuntimeKernel~new(verifier)
a1 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.40-a", "dbcore:rr11:v1", -
  "DatabaseCoreRuntimeModule", b1~value~sourceLines)
a2 = .RuntimeArtifact~new("database.core", "CAPABILITY", "0.40-b", "dbcore:rr11:v2", -
  "DatabaseCoreRuntimeModule", b2~value~sourceLines)
pr = verifier~pin(a1~artifactId, a1~sourceLines)
call assert pr~ok, "pin v1"
pr = verifier~pin(a2~artifactId, a2~sourceLines)
call assert pr~ok, "pin v2"

s1 = kernel~stage("prod", a1)
call assert s1~ok, "stage v1"
g1 = s1~value
ar = kernel~activate("prod", "database.core", g1~generationId)
call assert ar~ok, "activate v1"

lr1 = kernel~acquire("prod", "database.core")
call assert lr1~ok, "lease v1"
lease1 = lr1~value
module1 = lease1~module
view1 = lease1~generation
call assert view1~class~id = "RUNTIMEGENERATIONVIEW", "generation is read-only view"
call assert \view1~hasMethod("BEGINDRAIN"), "generation view exposes no lifecycle mutation"

evidence1 = lease1~executionEvidence
call assert evidence1~generationId = g1~generationId, "evidence generation id"
call assert evidence1~artifactId = a1~artifactId, "evidence artifact id"

/* Database Core receives the detached evidence as an opaque object. */
tx1 = module1~beginTransactionWithEvidence(evidence1, "db://runtime/accounts/tx-1")
tx1~execute("UPDATE account SET balance = balance + 1 WHERE id = 1")

s2 = kernel~stage("prod", a2)
call assert s2~ok, "stage v2"
g2 = s2~value
ar = kernel~activate("prod", "database.core", g2~generationId)
call assert ar~ok, "activate v2"
call assert g1~state = "DRAINING", "v1 draining after v2 publish"

rs1 = tx1~commit
call assert rs1~status = module1~errorClass~SUCCESS, "v1 transaction commits after v2 publish"
call assert rs1~evidence == evidence1, "transaction result retains detached evidence by identity"
call assert rs1~executionContext~locator = "db://runtime/accounts/tx-1", "transaction locator retained"
call assert rs1~evidence~generationId = g1~generationId, "result proves old generation"
call assert rs1~evidence~artifactId = a1~artifactId, "result proves old artifact"

lr2 = kernel~acquire("prod", "database.core")
call assert lr2~ok, "lease v2"
lease2 = lr2~value
module2 = lease2~module
evidence2 = lease2~executionEvidence
call assert evidence2~generationId = g2~generationId, "new evidence uses v2"

tx2 = module2~beginTransactionWithEvidence(evidence2, "db://runtime/accounts/tx-2")
tx2~execute("UPDATE account SET balance = balance + 2 WHERE id = 1")
rs2 = tx2~commit
call assert rs2~status = module2~errorClass~SUCCESS, "v2 transaction commits"
call assert rs2~evidence~generationId = g2~generationId, "v2 result evidence"
call assert rs1~evidence~generationId \= rs2~evidence~generationId, "results distinguish generations"

rr = lease2~release
call assert rr~ok, "release v2"
rr = lease1~release
call assert rr~ok, "release v1"
call assert g1~state = "RETIRED", "v1 retired"

/* Detached evidence remains usable after the originating lease is released. */
call assert rs1~evidence~generationId = g1~generationId, "detached old evidence survives lease release"
prov = rs1~executionContext~provenance
call assert prov["evidence"]["generation_id"] = g1~generationId, "neutral context projects runtime provenance"

say "DATABASE CORE RUNTIME REGISTRY V0.11 EVIDENCE SMOKE: OK"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "ASSERTION FAILED:" label
    exit 9
  end
  return

::requires "RuntimeBundleBuilder.cls"

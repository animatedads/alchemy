s=.OrchestratorTestSupport; base=s~tempDir("orch-semantic"); setup=s~initRepo(base); runner=setup[1]; repo=setup[3]
s~write(repo || "/README.md","base" || "0a"x); runner~require(.array~of("git","add","README.md"),repo); runner~require(.array~of("git","commit","-q","-m","base"),repo); runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
/* Directory lies. Manifest identity is semantic_dep@1.2. */
accept=base || "/accept"; runner~require(.array~of("git","worktree","add","-q","--detach",accept,"refs/remotes/origin/main"),repo)
root=accept || "/packages/not_semantic_dep_v999"
manifest='{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"semantic_dep","version":"1.2","kind":"oorexx"},"tests":[{"name":"noop","argv":["true"]}],"publish":{"artifact_only":true}}'
s~write(root || "/integration.json",manifest)
s~write(root || "/src/SemanticMarker.cls",'::class SemanticMarker public' || "0a"x || '::constant VALUE "SEMANTIC_OK"' || "0a"x)
runner~require(.array~of("git","add","packages"),accept); runner~require(.array~of("git","config","user.email","test@example.invalid"),accept); runner~require(.array~of("git","config","user.name","Alchemy Test"),accept); runner~require(.array~of("git","commit","-q","-m","semantic dependency"),accept); runner~require(.array~of("git","push","-q","origin","HEAD:refs/heads/main"),accept); runner~require(.array~of("git","worktree","remove","--force",accept),repo)
/* Consumer requests manifest identity, not directory spelling. */
pkg=base || "/consumer"; s~mkdir(pkg || "/tests")
consumer='{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"semantic_consumer","version":"1"},"dependencies":[{"name":"semantic_dep","version":"1.2","export":"SEMANTIC_DEP_ROOT"}],"tests":[{"name":"probe","argv":["rexx","tests/probe.rex"],"environment":{"require_dirs":["SEMANTIC_DEP_ROOT"]}}],"publish":{"artifact_only":true}}'
s~write(pkg || "/integration.json",consumer)
probe='if .SemanticMarker~VALUE <> "SEMANTIC_OK" then raise syntax 88.900 array("semantic dependency missing")' || "0a"x || 'say "PASS semantic manifest identity"' || "0a"x || '::requires "SemanticMarker.cls"' || "0a"x
s~write(pkg || "/tests/probe.rex",probe)
workspace=base || "/workspace"; s~mkdir(workspace)
orch=.AlchemyOrchestrator~new(runner)~processLocalDirectory(repo,pkg,workspace)
s~eq("PASS",orch~status,"semantic consumer status")
s~true(orch~execution~tests[1]~process~stdout~pos("PASS semantic manifest identity")>0,"semantic marker loaded")
s~remove(base); say "PASS test_manifest_dependency_identity"; exit 0
::requires "AlchemyOrchestrator.cls"
::requires "OrchestratorTestSupport.cls"

s=.OrchestratorTestSupport; base=s~tempDir; setup=s~initRepo(base); runner=setup[1]; repo=setup[3]
s~write(repo || "/README.md","base" || "0a"x); runner~require(.array~of("git","add","README.md"),repo); runner~require(.array~of("git","commit","-q","-m","base"),repo); runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
pkg=base || "/pkg"; s~mkdir(pkg || "/tests")
s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"badprobe","version":"1"},"tests":[{"name":"bad","argv":["rexx","tests/bad.rex"]}],"publish":{"tree":{"source":".","path":"packages/badprobe_v1"}}}')
s~write(pkg || "/tests/bad.rex",'say "EXPECTED FAIL"' || "0a"x || 'exit 7' || "0a"x)
workspace=base || "/workspace"; s~mkdir(workspace)
orchResult=.AlchemyOrchestrator~new(runner)~processLocalDirectory(repo,pkg,workspace)
s~eq("FAIL",orchResult~status,"overall failed")
s~eq("FAIL",orchResult~execution~status,"execution failed")
s~eq("REJECTED_TEST_FAILURE",orchResult~publication~status,"publication rejected")
missing=runner~run(.array~of("git","cat-file","-e","origin/main:packages/badprobe_v1"),repo)
s~true(missing~rc<>0,"failed package absent from main")
s~remove(base); say "PASS test_failure_not_published"; exit 0
::requires "AlchemyOrchestrator.cls"
::requires "OrchestratorTestSupport.cls"

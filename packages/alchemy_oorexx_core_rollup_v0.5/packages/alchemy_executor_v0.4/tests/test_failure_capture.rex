s=.ExecutorTestSupport; base=s~tempDir("exec-fail"); pkg=base || "/pkg"; repo=base || "/repo"; s~mkdir(pkg); s~mkdir(repo); s~mkdir(pkg || "/tests")
s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"fail","version":"1"},"tests":[{"name":"bad","argv":["rexx","tests/bad.rex"],"timeout_seconds":10}],"publish":{"artifact_only":true}}')
s~write(pkg || "/tests/bad.rex",'say "EXPECTED FAILURE"' || "0a"x || 'exit 7' || "0a"x)
mat=.AlchemyMaterializedPackage~new(pkg,.AlchemyTransportSource~new("local-directory",pkg)); r=.AlchemyExecutor~new~execute(mat,.AlchemyDependencyFloor~new,repo)
s~assertEq("FAIL",r~status,"failure status"); s~assertEq(7,r~tests[1]~process~rc,"failure rc"); s~assertTrue(r~tests[1]~process~stdout~pos("EXPECTED FAILURE")>0,"failure stdout")
s~remove(base); say "PASS test_failure_capture"; exit 0
::requires "AlchemyExecutor.cls"
::requires "ExecutorTestSupport.cls"

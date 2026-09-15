s=.ExecutorTestSupport; base=s~tempDir("exec-timeout"); pkg=base || "/pkg"; repo=base || "/repo"; s~mkdir(pkg); s~mkdir(repo); s~mkdir(pkg || "/tests")
s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"timeout","version":"1"},"tests":[{"name":"slow","argv":["rexx","tests/slow.rex"],"timeout_seconds":1}],"publish":{"artifact_only":true}}')
s~write(pkg || "/tests/slow.rex",'call SysSleep 3' || "0a"x || 'exit 0' || "0a"x)
mat=.AlchemyMaterializedPackage~new(pkg,.AlchemyTransportSource~new("local-directory",pkg)); r=.AlchemyExecutor~new~execute(mat,.AlchemyDependencyFloor~new,repo)
s~assertEq("FAIL",r~status,"timeout status"); s~assertEq(124,r~tests[1]~process~rc,"timeout rc"); s~assertTrue(r~tests[1]~process~timedOut,"timeout flag")
s~remove(base); say "PASS test_timeout_capture"; exit 0
::requires "AlchemyExecutor.cls"
::requires "ExecutorTestSupport.cls"

s=.ExecutorTestSupport; base=s~tempDir("exec-env"); pkg=base || "/pkg"; repo=base || "/repo"; dep=repo || "/packages/dep_v1"
s~mkdir(pkg || "/src"); s~mkdir(pkg || "/tests/a"); s~mkdir(pkg || "/tests/b"); s~mkdir(dep || "/src")
manifest='{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"exec_probe","version":"1","kind":"oorexx"},"dependencies":[{"name":"dep","version":"1","export":"DEP_ROOT"}],"environment":{"rexx_path":{"mode":"prepend","entries":["${PACKAGE_ROOT}/src"],"require_entries":true}},"tests":[{"name":"a","argv":["rexx","tests/a.rex"],"environment":{"set":{"WHICH":"A"},"rexx_path":{"mode":"prepend","entries":["${PACKAGE_ROOT}/tests/a"],"require_entries":true}}},{"name":"b","argv":["rexx","tests/b.rex"],"environment":{"set":{"WHICH":"B"},"rexx_path":{"mode":"replace","entries":["${PACKAGE_ROOT}/tests/b"],"require_entries":true}}}],"publish":{"artifact_only":true}}'
s~write(pkg || "/integration.json",manifest)
s~write(pkg || "/tests/a.rex",'if value("WHICH",,"ENVIRONMENT")<>"A" then exit 11' || "0a"x || 'if value("DEP_ROOT",,"ENVIRONMENT")="" then exit 12' || "0a"x || 'say "PASS EXEC A"' || "0a"x)
s~write(pkg || "/tests/b.rex",'if value("WHICH",,"ENVIRONMENT")<>"B" then exit 21' || "0a"x || 'rp=value("REXX_PATH",,"ENVIRONMENT")' || "0a"x || 'if rp~pos("tests/b")=0 then exit 22' || "0a"x || 'if rp~pos("dep_v1")>0 then exit 23' || "0a"x || 'say "PASS EXEC B"' || "0a"x)
floor=.AlchemyDependencyFloor~new~add(.AlchemyDependencyFloorEntry~new(.AlchemyPackageId~new("dep","1"),dep,"DEP_ROOT",.array~of("src")))
source=.AlchemyTransportSource~new("local-directory",pkg)
mat=.AlchemyMaterializedPackage~new(pkg,source)
baseEnv=.table~new; baseEnv["PATH"]=value("PATH",,"ENVIRONMENT"); baseEnv["REXX_PATH"]="/ambient"
execResult=.AlchemyExecutor~new~execute(mat,floor,repo,baseEnv)
s~assertEq("PASS",execResult~status,"package status")
s~assertEq(2,execResult~tests~items,"test count")
s~assertTrue(execResult~tests[1]~process~stdout~pos("PASS EXEC A")>0,"A output")
s~assertTrue(execResult~tests[2]~process~stdout~pos("PASS EXEC B")>0,"B output")
s~remove(base); say "PASS test_exact_environment_execution"; exit 0
::requires "AlchemyExecutor.cls"
::requires "ExecutorTestSupport.cls"

s=.PublisherTestSupport; runner=.AlchemyCommandRunner~new; base=s~tempDir; bare=base || "/remote.git"; repo=base || "/repo"
s~mkdir(bare); runner~require(.array~of("git","init","-q","--bare",bare),base); runner~require(.array~of("git","clone","-q",bare,repo),base); runner~require(.array~of("git","checkout","-q","-b","main"),repo); runner~require(.array~of("git","config","user.email","t@x"),repo); runner~require(.array~of("git","config","user.name","T"),repo); s~write(repo || "/README","x"); runner~require(.array~of("git","add","README"),repo); runner~require(.array~of("git","commit","-q","-m","base"),repo); runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
pkg=base || "/pkg"; s~mkdir(pkg || "/tests"); s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"badpub","version":"1"},"tests":[{"name":"bad","argv":["rexx","tests/bad.rex"]}],"publish":{"tree":{"source":".","path":"packages/badpub_v1"}}}'); s~write(pkg || "/tests/bad.rex",'exit 9' || "0a"x)
mat=.AlchemyMaterializedPackage~new(pkg,.AlchemyTransportSource~new("local-directory",pkg)); exec=.AlchemyExecutor~new~execute(mat,.AlchemyDependencyFloor~new,repo); p=.AlchemyPublisher~new(runner)~publish(mat,exec,repo); s~eq("REJECTED_TEST_FAILURE",p~status,"failed rejection")
exists=runner~run(.array~of("git","cat-file","-e","origin/main:packages/badpub_v1"),repo); s~ok(\exists~ok,"failed package absent")
s~remove(base); say "PASS test_failed_not_published"; exit 0
::requires "AlchemyPublisher.cls"
::requires "PublisherTestSupport.cls"

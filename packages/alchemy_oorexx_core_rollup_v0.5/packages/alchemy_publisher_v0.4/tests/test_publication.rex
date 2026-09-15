s=.PublisherTestSupport; runner=.AlchemyCommandRunner~new; base=s~tempDir; bare=base || "/remote.git"; repo=base || "/repo"
s~mkdir(bare); runner~require(.array~of("git","init","-q","--bare",bare),base); runner~require(.array~of("git","clone","-q",bare,repo),base); runner~require(.array~of("git","checkout","-q","-b","main"),repo)
runner~require(.array~of("git","config","user.email","test@example.invalid"),repo); runner~require(.array~of("git","config","user.name","Publish Test"),repo); s~write(repo || "/README.md","base"); runner~require(.array~of("git","add","README.md"),repo); runner~require(.array~of("git","commit","-q","-m","base"),repo); runner~require(.array~of("git","push","-q","-u","origin","main"),repo)
s~write(repo || "/LOCAL_DIRT.txt","DIRTY"); statusBefore=runner~require(.array~of("git","status","--porcelain"),repo)~stdout
pkg=base || "/pkg"; s~mkdir(pkg || "/tests"); s~write(pkg || "/payload.txt","V1")
s~write(pkg || "/integration.json",'{"schema":"alchemy.autobuild.integration/0.4","package":{"name":"pubprobe","version":"1"},"tests":[{"name":"ok","argv":["rexx","tests/ok.rex"]}],"publish":{"tree":{"source":".","path":"packages/pubprobe_v1"}}}')
s~write(pkg || "/tests/ok.rex",'say "PASS"' || "0a"x || 'exit 0' || "0a"x)
mat=.AlchemyMaterializedPackage~new(pkg,.AlchemyTransportSource~new("local-directory",pkg)); exec=.AlchemyExecutor~new~execute(mat,.AlchemyDependencyFloor~new,repo)
pub=.AlchemyPublisher~new(runner); first=pub~publish(mat,exec,repo); s~eq("PUBLISHED",first~status,"first publication")
remotePayload=.AlchemyTransportText~firstLine(runner~require(.array~of("git","show","origin/main:packages/pubprobe_v1/payload.txt"),repo)~stdout); s~eq("V1",remotePayload,"remote payload")
statusAfter=runner~require(.array~of("git","status","--porcelain"),repo)~stdout; s~eq(statusBefore,statusAfter,"dirty checkout unchanged")
second=pub~publish(mat,exec,repo); s~eq("NOOP_IDENTICAL",second~status,"identical no-op")
s~write(pkg || "/payload.txt","V2")
raised=.false; signal on syntax name collision; pub~publish(mat,exec,repo); signal off syntax; say "FAIL collision accepted"; exit 1
collision: signal off syntax
s~remove(base); say "PASS test_publication"; exit 0
::requires "AlchemyPublisher.cls"
::requires "PublisherTestSupport.cls"

s=.FloorTestSupport; base=s~tempDir("floor-manifest-id"); repo=base || "/repo"
s~mkdir(repo); s~mkdir(repo || "/packages"); root=repo || "/packages/misleading_directory_v999"; s~mkdir(root); s~mkdir(root || "/src")
manifest='{"schema":"alchemy.autobuild.integration/0.3","package":{"name":"semantic_dep","version":"1.2","kind":"oorexx"},"tests":[{"name":"noop","argv":["true"]}],"publish":{"artifact_only":true}}'
s~write(root || "/integration.json",manifest)
floor=.AlchemyRepositoryDependencyCatalog~new~build(repo)
s~assertEq(1,floor~size,"manifest catalog size")
e=floor~resolve(.AlchemyDependencyRef~new("semantic_dep","1.2"))
s~assertTrue(e<>.nil,"semantic identity resolved")
s~assertTrue(floor~resolve(.AlchemyDependencyRef~new("misleading_directory","999"))==.nil,"directory spelling not semantic identity")
s~assertEq("MANIFEST",e~identitySource,"manifest provenance")
s~assertEq(root || "/integration.json",e~manifestPath,"manifest path evidence")
s~assertEq("SEMANTIC_DEP_ROOT",e~exportName,"semantic conventional export")
s~remove(base); say "PASS test_manifest_identity"; exit 0
::requires "AlchemyDependencyFloor.cls"
::requires "TestFloorSupport.cls"

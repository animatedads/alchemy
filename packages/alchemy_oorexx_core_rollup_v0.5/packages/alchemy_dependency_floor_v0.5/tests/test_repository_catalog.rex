s=.FloorTestSupport; base=s~tempDir("floor-catalog"); repo=base || "/repo"
s~mkdir(repo)
empty=.AlchemyRepositoryDependencyCatalog~new~build(repo)
s~assertEq(0,empty~size,"empty repository catalog")
s~mkdir(repo || "/packages/reputation_effect_v0.2/src")
s~mkdir(repo || "/packages/runtime_registry_v0.12")
s~mkdir(repo || "/packages/not_versioned")
floor=.AlchemyRepositoryDependencyCatalog~new~build(repo)
s~assertEq(2,floor~size,"catalog size")
e=floor~resolve(.AlchemyDependencyRef~new("reputation_effect","0.2"))
r=floor~resolve(.AlchemyDependencyRef~new("runtime_registry","0.12"))
s~assertTrue(e<>.nil,"effect resolved"); s~assertTrue(r<>.nil,"registry resolved")
s~assertEq("DIRECTORY_FALLBACK",e~identitySource,"legacy provenance")
s~assertEq("REPUTATION_EFFECT_ROOT",e~exportName,"conventional export")
s~assertEq(2,e~rexxEntries~items,"src plus root"); s~assertEq("src",e~rexxEntries[1],"src first"); s~assertEq(".",e~rexxEntries[2],"root second")
s~assertEq(1,r~rexxEntries~items,"root only")
s~remove(base); say "PASS test_repository_catalog"; exit 0
::requires "AlchemyDependencyFloor.cls"
::requires "TestFloorSupport.cls"

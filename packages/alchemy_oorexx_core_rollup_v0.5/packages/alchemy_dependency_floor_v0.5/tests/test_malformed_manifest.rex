s=.FloorTestSupport; base=s~tempDir("floor-bad-manifest"); repo=base || "/repo"
s~mkdir(repo); s~mkdir(repo || "/packages"); root=repo || "/packages/looks_valid_v1.0"; s~mkdir(root)
s~write(root || "/integration.json",'{ definitely-not-json ')
raised=.false
signal on syntax name expectedSyntax
ignored=.AlchemyRepositoryDependencyCatalog~new~build(repo)
signal off syntax
s~remove(base)
raise syntax 88.900 array("FAIL malformed present manifest was silently ignored")
expectedSyntax:
  signal off syntax
  s~remove(base)
  say "PASS test_malformed_manifest"
  exit 0
::requires "AlchemyDependencyFloor.cls"
::requires "TestFloorSupport.cls"

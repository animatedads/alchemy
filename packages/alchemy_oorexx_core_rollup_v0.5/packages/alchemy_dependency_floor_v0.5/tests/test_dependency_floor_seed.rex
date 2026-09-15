support=.FloorTestSupport
runner=.AlchemyCommandRunner~new
base=support~tempDir("floor-seed")
bare=base || "/remote.git"; repo=base || "/repo"
support~mkdir(bare)
runner~require(.array~of("git", "init", "-q", "--bare", bare), base)
runner~require(.array~of("git", "clone", "-q", bare, repo), base)
runner~require(.array~of("git", "checkout", "-q", "-b", "main"), repo)
runner~require(.array~of("git", "config", "user.email", "test@example.invalid"), repo)
runner~require(.array~of("git", "config", "user.name", "Floor Test"), repo)
support~mkdir(repo || "/packages/existing_v1")
support~write(repo || "/packages/existing_v1/value.txt", "KEEP")
runner~require(.array~of("git", "add", "packages"), repo)
runner~require(.array~of("git", "commit", "-q", "-m", "base"), repo)
runner~require(.array~of("git", "push", "-q", "-u", "origin", "main"), repo)
/* ordinary checkout deliberately dirty */
support~write(repo || "/LOCAL_DIRT.txt", "DIRTY")
statusBefore=runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout

make=base || "/make"; support~mkdir(make)
support~mkdir(make || "/existing_v1"); support~write(make || "/existing_v1/value.txt", "REPLACE_ME")
runner~require(.array~of("zip", "-qr", base || "/existing_v1.zip", "existing_v1"), make)
support~mkdir(make || "/new_v2"); support~write(make || "/new_v2/value.txt", "NEW")
runner~require(.array~of("zip", "-qr", base || "/new_v2.zip", "new_v2"), make)
outer=base || "/outer"; support~mkdir(outer || "/current")
runner~require(.array~of("cp", base || "/existing_v1.zip", outer || "/current/"), base)
runner~require(.array~of("cp", base || "/new_v2.zip", outer || "/current/"), base)
bundle=base || "/bundle.zip"; runner~require(.array~of("zip", "-qr", bundle, "current"), outer)

seedResult=.AlchemyDependencyFloorSeeder~new(runner)~seed(repo, bundle, .false)
statusAfter=runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout
keep=.AlchemyTransportText~firstLine(runner~require(.array~of("git", "show", "origin/main:packages/existing_v1/value.txt"), repo)~stdout)
newv=.AlchemyTransportText~firstLine(runner~require(.array~of("git", "show", "origin/main:packages/new_v2/value.txt"), repo)~stdout)
ledgerCheck=runner~run(.array~of("git", "cat-file", "-e", "origin/main:" || seedResult~ledgerPath), repo)

support~assertEq(statusBefore, statusAfter, "dirty checkout untouched")
support~assertEq("KEEP", keep, "existing preserved")
support~assertEq("NEW", newv, "new package seeded")
support~assertTrue(ledgerCheck~ok, "ledger committed")
support~assertEq(1, seedResult~seeded~items, "seeded count")
support~assertEq(1, seedResult~preserved~items, "preserved count")
support~remove(base)
say "PASS test_dependency_floor_seed"
exit 0
::requires "AlchemyDependencyFloor.cls"
::requires "TestFloorSupport.cls"

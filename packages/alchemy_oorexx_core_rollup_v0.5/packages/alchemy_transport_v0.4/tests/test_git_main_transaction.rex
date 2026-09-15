support = .AlchemyTestSupport
base = support~tempDir("alchemy-tx")
bare = base || "/remote.git"
repo = base || "/repo"
support~mkdir(bare)
runner = .AlchemyCommandRunner~new
runner~require(.array~of("git", "init", "-q", "--bare", bare), base)
runner~require(.array~of("git", "clone", "-q", bare, repo), base)
runner~require(.array~of("git", "checkout", "-q", "-b", "main"), repo)
runner~require(.array~of("git", "config", "user.email", "test@example.invalid"), repo)
runner~require(.array~of("git", "config", "user.name", "Alchemy Test"), repo)
support~write(repo || "/README.md", "base")
runner~require(.array~of("git", "add", "README.md"), repo)
runner~require(.array~of("git", "commit", "-q", "-m", "base"), repo)
runner~require(.array~of("git", "push", "-q", "-u", "origin", "main"), repo)

/* Deliberately dirty the ordinary checkout. */
support~write(repo || "/LOCAL_DIRT.txt", "must survive")
headBefore = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
statusBefore = runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout

tx = .AlchemyGitMainTransaction~new(repo, runner)~begin
support~mkdir(tx~root || "/bootstrap")
support~write(tx~root || "/bootstrap/seed.txt", "SEEDED_BY_OOREXX")
newCommit = tx~commitAndPush(.array~of("bootstrap/seed.txt"), "test: ooRexx transaction")
tx~close

headAfter = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
statusAfter = runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout
remoteText = runner~require(.array~of("git", "show", "origin/main:bootstrap/seed.txt"), repo)~stdout

support~assertEq(headBefore, headAfter, "ordinary checkout head unchanged")
support~assertEq(statusBefore, statusAfter, "ordinary checkout dirt unchanged")
support~assertTrue(newCommit \= "", "transaction commit returned")
support~assertEq("SEEDED_BY_OOREXX", .AlchemyTransportText~firstLine(remoteText), "remote updated")
support~remove(base)
say "PASS test_git_main_transaction"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"

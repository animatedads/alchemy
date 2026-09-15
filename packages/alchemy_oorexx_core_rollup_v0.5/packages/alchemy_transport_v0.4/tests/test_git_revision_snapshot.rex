support = .AlchemyTestSupport
base = support~tempDir("alchemy-snapshot")
bare = base || "/remote.git"
repo = base || "/repo"
support~mkdir(bare)
runner = .AlchemyCommandRunner~new
runner~require(.array~of("git", "init", "-q", "--bare", bare), base)
runner~require(.array~of("git", "clone", "-q", bare, repo), base)
runner~require(.array~of("git", "checkout", "-q", "-b", "main"), repo)
runner~require(.array~of("git", "config", "user.email", "test@example.invalid"), repo)
runner~require(.array~of("git", "config", "user.name", "Alchemy Test"), repo)
support~write(repo || "/README.md", "base" || "0a"x)
runner~require(.array~of("git", "add", "README.md"), repo)
runner~require(.array~of("git", "commit", "-q", "-m", "base"), repo)
runner~require(.array~of("git", "push", "-q", "-u", "origin", "main"), repo)
headBefore = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)

/* Advance accepted main elsewhere, leaving the ordinary checkout stale and dirty. */
accept = base || "/accept"
runner~require(.array~of("git", "worktree", "add", "-q", "--detach", accept, "refs/remotes/origin/main"), repo)
support~mkdir(accept || "/packages")
support~write(accept || "/packages/accepted.txt", "REMOTE_ONLY" || "0a"x)
runner~require(.array~of("git", "add", "packages/accepted.txt"), accept)
runner~require(.array~of("git", "config", "user.email", "test@example.invalid"), accept)
runner~require(.array~of("git", "config", "user.name", "Alchemy Test"), accept)
runner~require(.array~of("git", "commit", "-q", "-m", "accepted remote advance"), accept)
runner~require(.array~of("git", "push", "-q", "origin", "HEAD:refs/heads/main"), accept)
runner~require(.array~of("git", "worktree", "remove", "--force", accept), repo)
support~write(repo || "/LOCAL_DIRT.txt", "DO NOT TOUCH" || "0a"x)
statusBefore = runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout

snapshot = .AlchemyGitRevisionSnapshot~new(repo, runner)~begin
support~assertTrue(.AlchemyTransportFs~isFile(snapshot~root || "/packages/accepted.txt"), "snapshot sees remote-only accepted file")
support~assertEq("REMOTE_ONLY" || "0a"x, support~read(snapshot~root || "/packages/accepted.txt"), "snapshot content")
support~assertTrue(snapshot~commit \= headBefore, "snapshot advanced beyond stale checkout")
snapshot~close

headAfter = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
statusAfter = runner~require(.array~of("git", "status", "--porcelain"), repo)~stdout
support~assertEq(headBefore, headAfter, "ordinary checkout head unchanged")
support~assertEq(statusBefore, statusAfter, "ordinary checkout dirt unchanged")
support~remove(base)
say "PASS test_git_revision_snapshot"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"

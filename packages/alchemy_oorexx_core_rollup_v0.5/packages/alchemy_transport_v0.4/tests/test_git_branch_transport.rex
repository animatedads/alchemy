support = .AlchemyTestSupport
base = support~tempDir("alchemy-git")
repo = base || "/repo"
work = base || "/work"
support~mkdir(repo)
support~mkdir(work)
runner = .AlchemyCommandRunner~new
runner~require(.array~of("git", "init", "-q", "-b", "main"), repo)
runner~require(.array~of("git", "config", "user.email", "test@example.invalid"), repo)
runner~require(.array~of("git", "config", "user.name", "Alchemy Test"), repo)
support~write(repo || "/README.md", "main")
runner~require(.array~of("git", "add", "README.md"), repo)
runner~require(.array~of("git", "commit", "-q", "-m", "main"), repo)
mainHead = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)

sid = "20260822T120000Z-TEST-package"
branch = "submit/test"
runner~require(.array~of("git", "checkout", "-q", "-b", branch), repo)
path = repo || "/autobuild/inbox/" || sid
runner~require(.array~of("mkdir", "-p", path || "/package"), repo)
support~write(path || "/package/integration.json", '{"schema":"alchemy.autobuild.integration/0.2"}')
support~write(path || "/package/payload.txt", "GIT_PAYLOAD")
ready = '{"schema":"alchemy.autobuild.git-submission/0.1","submission_id":"' || sid || '","submitted_by":"TEST","package_path":"package"}'
support~write(path || "/ready.json", ready)
runner~require(.array~of("git", "add", "autobuild"), repo)
runner~require(.array~of("git", "commit", "-q", "-m", "submission"), repo)
submitHead = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
runner~require(.array~of("git", "checkout", "-q", "main"), repo)

beforeHead = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
beforeBranch = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "branch", "--show-current"), repo)~stdout)
source = .AlchemyGitSubmissionDiscovery~new~discover(repo, submitHead, sid, runner)
context = .AlchemyTransportContext~new(work, repo, runner)
mat = .AlchemyGitBranchTransport~new~materialize(source, context)
afterHead = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "rev-parse", "HEAD"), repo)~stdout)
afterBranch = .AlchemyTransportText~firstLine(runner~require(.array~of("git", "branch", "--show-current"), repo)~stdout)

support~assertEq(mainHead, beforeHead, "main head before")
support~assertEq(beforeHead, afterHead, "head unchanged")
support~assertEq(beforeBranch, afterBranch, "branch unchanged")
support~assertEq("main", afterBranch, "still main")
support~assertEq(submitHead, mat~source~immutableId, "exact commit provenance")
support~assertEq("TEST", mat~source~metadata["submitted_by"], "ready metadata")
support~assertEq("GIT_PAYLOAD", support~read(mat~root || "/payload.txt"), "git payload")
support~remove(base)
say "PASS test_git_branch_transport"
exit 0

::requires "AlchemyTransport.cls"
::requires "TestSupport.cls"

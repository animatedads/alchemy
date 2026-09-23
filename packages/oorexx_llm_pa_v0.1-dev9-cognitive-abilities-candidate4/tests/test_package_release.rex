/* Package release contract: a dirty working tree produces a clean immutable
 * ZIP without modifying or deleting the source tree.  Cognitive pruning is
 * explicit; source/runtime ambiguity is never guessed away. */
parse source . . here
root = filespec("L", here)
work = "/tmp/llmpa-release-test-" || random(100000,999999)
call makeDir work

/* --- hygiene and immutable release --- */
source = work || "/working"
releaseRoot = work || "/releases"
call makeDir source
call makeDir source || "/src"
call makeDir source || "/bin"
call makeDir source || "/runtime"
call makeDir source || "/tests"
call makeDir source || "/tests/live-gemma-store-123"
call makeDir source || "/py"
call makeDir source || "/py/__pycache__"

call seedPackage source, "test-package"
call write source || "/src/Test.cls", "::class Test public"
call write source || "/bin/tool", "#!/bin/sh" || "0a"x || "exit 0"
call write source || "/runtime/queue.journal", "live-state"
call write source || "/tests/live-gemma-store-123/traffic.log", "live-test-state"
call write source || "/py/__pycache__/helper.cpython-313.pyc", "compiled-python"
call write source || "/LEDGERPATH", "budget-runtime-ledger"
call write source || "/scratch.pyc", "compiled-python"
call write source || "/MANIFEST.sha256", "stale manifest"

releaser = .LlmPaPackageRelease~new(releaseRoot, .nil, .nil, .nil, work)
outcome = releaser~release(source, "test-package-0.1")
call must outcome, "release succeeds"
receipt = outcome~value
call mustBool receipt["status"] = "RELEASE_READY", "ready status"
call mustBool receipt["excluded_count"] >= 6, "detritus excluded"
call mustBool receipt["archive_inventory_verified"] = .true, "archive inventory verified"
call mustBool stream(receipt["artifact"], "C", "QUERY EXISTS") \= "", "artifact exists"
call mustBool stream(receipt["snapshot"] || "/MANIFEST.sha256", "C", "QUERY EXISTS") \= "", "fresh manifest exists"
call mustBool stream(receipt["snapshot"] || "/scratch.pyc", "C", "QUERY EXISTS") = "", "pyc absent"
call mustBool stream(receipt["snapshot"] || "/py/__pycache__/helper.cpython-313.pyc", "C", "QUERY EXISTS") = "", "pycache absent"
call mustBool stream(receipt["snapshot"] || "/LEDGERPATH", "C", "QUERY EXISTS") = "", "ledger absent"
call mustBool stream(receipt["snapshot"] || "/runtime/queue.journal", "C", "QUERY EXISTS") = "", "runtime absent"
call mustBool stream(receipt["snapshot"] || "/tests/live-gemma-store-123/traffic.log", "C", "QUERY EXISTS") = "", "live test store absent"
call mustBool stream(source || "/scratch.pyc", "C", "QUERY EXISTS") \= "", "source pyc retained"
call mustBool stream(source || "/runtime/queue.journal", "C", "QUERY EXISTS") \= "", "source runtime retained"

again = releaser~release(source, "test-package-0.1")
call must again, "repeat release succeeds"
call mustBool again~value["tree_manifest_sha256"] = receipt["tree_manifest_sha256"], "tree identity stable"
call mustBool again~value["artifact"] = receipt["artifact"], "artifact reused"

/* --- source/dependency logical shadow --- */
shadow = work || "/shadow"
call makeDir shadow
call makeDir shadow || "/src"
call makeDir shadow || "/deps"
call makeDir shadow || "/deps/pkg"
call seedPackage shadow, "shadow-package"
call write shadow || "/src/Shared.cls", "::class Shared public" || "0a"x || "::method value" || "0a"x || "return 'src'"
call write shadow || "/deps/pkg/Shared.cls", "::class Shared public" || "0a"x || "::method value" || "0a"x || "return 'deps'"

shadowAnalysis = releaser~analyse(shadow)
call must shadowAnalysis, "shadow analysis succeeds"
call mustBool shadowAnalysis~value["unresolved_conflicts"]~items = 1, "one logical shadow"
shadowConflict = shadowAnalysis~value["unresolved_conflicts"][1]
call mustBool shadowConflict["kind"] = "PRODUCTION_LOGICAL_SHADOW", "logical shadow kind"
blocked = releaser~release(shadow, "shadow-package")
call mustFail blocked, "RELEASE_REVIEW_REQUIRED", "unresolved shadow blocks release"

/* KEEP_BOTH is deliberately insufficient for two different public classes. */
unsafeKeep = .LlmPaPackageReleaseDecisionSet~new
ignore = unsafeKeep~keepBoth(shadowConflict["conflict_id"], "both looked useful", "codex")
stillBlocked = releaser~release(shadow, "shadow-package-keepboth", unsafeKeep)
call mustFail stillBlocked, "RELEASE_REVIEW_REQUIRED", "public identity keep-both rejected"

/* An explicit cognitive prune resolves it. */
shadowDecisions = .LlmPaPackageReleaseDecisionSet~new
ignore = shadowDecisions~prune("deps/pkg/Shared.cls", "src Shared is the release authority; dependency copy is stale", "architect")
shadowRelease = releaser~release(shadow, "shadow-package-resolved", shadowDecisions)
call must shadowRelease, "shadow resolved by explicit prune"
call mustBool stream(shadowRelease~value["snapshot"] || "/src/Shared.cls", "C", "QUERY EXISTS") \= "", "authoritative source retained"
call mustBool stream(shadowRelease~value["snapshot"] || "/deps/pkg/Shared.cls", "C", "QUERY EXISTS") = "", "pruned shadow absent"
call mustBool shadowRelease~value["decision_effects"]~items = 1, "prune decision recorded"

/* --- competing integration cuts: preserve as conflict evidence --- */
cuts = work || "/cuts"
call makeDir cuts
call makeDir cuts || "/src"
call makeDir cuts || "/cuts"
call makeDir cuts || "/cuts/chat-a"
call makeDir cuts || "/cuts/chat-b"
call seedPackage cuts, "cuts-package"
call write cuts || "/src/Main.cls", "::class Main public"
cutName = "queuerexx.71.workupdate.1717x.zip"
call write cuts || "/cuts/chat-a/" || cutName, "integration cut A"
call write cuts || "/cuts/chat-b/" || cutName, "integration cut B"

cutAnalysis = releaser~analyse(cuts)
call must cutAnalysis, "cut analysis succeeds"
call mustBool cutAnalysis~value["unresolved_conflicts"]~items = 1, "one competing archive conflict"
cutConflict = cutAnalysis~value["unresolved_conflicts"][1]
call mustBool cutConflict["kind"] = "COMPETING_ARCHIVE_CUT", "archive conflict kind"

quarantine = .LlmPaPackageReleaseDecisionSet~new
ignore = quarantine~quarantineConflict(cutConflict["conflict_id"], "two chats produced competing integration cuts; preserve both for review", "architect")
cutRelease = releaser~release(cuts, "cuts-package-quarantine", quarantine)
call must cutRelease, "quarantined cut release succeeds"
call mustBool cutRelease~value["status"] = "RELEASE_READY_WITH_QUARANTINE", "quarantine status"
qroot = cutRelease~value["snapshot"] || "/_release_conflicts/" || cutConflict["conflict_id"]
call mustBool stream(qroot || "/cuts/chat-a/" || cutName, "C", "QUERY EXISTS") \= "", "cut A preserved in conflict folder"
call mustBool stream(qroot || "/cuts/chat-b/" || cutName, "C", "QUERY EXISTS") \= "", "cut B preserved in conflict folder"
call mustBool stream(cutRelease~value["snapshot"] || "/cuts/chat-a/" || cutName, "C", "QUERY EXISTS") = "", "cut A removed from active tree"
call mustBool stream(cutRelease~value["snapshot"] || "/cuts/chat-b/" || cutName, "C", "QUERY EXISTS") = "", "cut B removed from active tree"

/* Or the Architect can explicitly retain both at their existing distinct paths. */
keepBoth = .LlmPaPackageReleaseDecisionSet~new
ignore = keepBoth~keepBoth(cutConflict["conflict_id"], "both cuts are required as comparative inputs", "architect")
keptRelease = releaser~release(cuts, "cuts-package-keep-both", keepBoth)
call must keptRelease, "explicit keep-both release succeeds"
call mustBool stream(keptRelease~value["snapshot"] || "/cuts/chat-a/" || cutName, "C", "QUERY EXISTS") \= "", "cut A kept"
call mustBool stream(keptRelease~value["snapshot"] || "/cuts/chat-b/" || cutName, "C", "QUERY EXISTS") \= "", "cut B kept"

say "PASS test_package_release"
exit 0

seedPackage: procedure
  use arg path, packageName
  call write path || "/VERSION.txt", "0.1-test"
  call write path || "/README.md", "test package"
  call write path || "/integration.json", '{"schema":"test.integration/1","package":"' || packageName || '","api":"test/1","dependencies":[]}'
  return

makeDir: procedure
  use arg path
  rows = .array~new
  call SysFileTree path, rows, "DO"
  if rows~items = 1 then return
  rc = SysMkDir(path)
  if rc \= 0 then do
    say "FAIL makeDir" path "rc="rc
    exit 1
  end
  return

write: procedure
  use arg path, text
  call lineout path, text
  call stream path, "C", "CLOSE"
  return

must: procedure
  use arg answer, label
  if \answer~ok then do
    say "FAIL" label answer~code answer~detail
    exit 1
  end
  return

mustFail: procedure
  use arg answer, code, label
  if answer~ok | answer~code \= code then do
    say "FAIL" label "expected="code "actual="answer~code answer~detail
    exit 1
  end
  return

mustBool: procedure
  use arg answer, label
  if \answer then do
    say "FAIL" label
    exit 1
  end
  return

::requires "LlmPaPackageRelease.cls"

/* Real staging qualification uses a tiny safe archive and verifies the
 * content-addressed generation, manifest and durable receipt. */
parse source . . here
root = filespec("L", here)
work = "/tmp/llmpa-stage-test-" || random(100000,999999)
address system "mkdir -p " || work || "/pkg " || work || "/input"
call lineout work || "/input/VERSION.txt", "0.1-test"
call lineout work || "/input/payload.txt", "hello"
call lineout work || "/input/integration.json", '{"schema":"test","dependencies":[]}'
call lineout work || "/input/MANIFEST.sha256", ""
call stream work || "/input/VERSION.txt", "C", "CLOSE"
call stream work || "/input/payload.txt", "C", "CLOSE"
call stream work || "/input/integration.json", "C", "CLOSE"
call stream work || "/input/MANIFEST.sha256", "C", "CLOSE"
address system "cd " || work || "/input && sha256sum payload.txt > MANIFEST.sha256"
/* Use an archive whose top-level tree is deterministic. */
address system "cd " || work || "/input && zip -q -r " || work || "/package.zip ."
stageRoot = work || "/stage"
s = .LlmPaPackageStage~new(stageRoot)
outcome = s~stage(work || "/package.zip")
call must outcome, "stage succeeds"
call mustBool outcome~value["status"] = "STAGED_READY", "stage status"
call mustBool outcome~value["generation"] \= "", "generation published"
call mustBool stream(stageRoot || "/receipts/" || outcome~value["package_sha256"] || ".json", "C", "QUERY EXISTS") \= "", "receipt exists"
say "PASS test_package_stage"
exit 0

must: procedure
  use arg answer, label
  if \answer~ok then do; say "FAIL" label answer~code answer~detail; exit 1; end
return

mustBool: procedure
  use arg answer, label
  if \answer then do; say "FAIL" label; exit 1; end
return

::requires "LlmPaPackageStage.cls"

parse source . . here
root = filespec("L", here)
path = root || "/memory-test.journal"
address command "rm -f" path
m = .LlmPaMemoryStore~new(path)
r = m~remember("ED209E", "Google Server, have to restart it with gcloud", "codex", "r1")
call must r~ok, "remember ED209E"
r = m~remember("GCloud", "should use our tool", "codex", "r2")
call must r~ok, "remember GCloud"
r = m~remember("SSH", "use the ./sshnode.sh", "codex", "r3")
call must r~ok, "remember SSH"
r = m~remind("ed209e crash")
/* Token evidence retrieves ED209E; the PA does not manufacture a crash fact. */
call must r~ok, "remind"
call must r~value~items = 1, "ED209E token retrieval"
call must r~value[1]["key"] = "ED209E", "ED209E token match"
r = m~remind("ED209E")
call must r~value~items = 1, "exact ED209E match"
call must r~value[1]["value"] = "Google Server, have to restart it with gcloud", "ED209E value"
call must m~count = 3, "memory count"
address command "rm -f" path
say "PASS test_memory"
exit 0
must: procedure
  use arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
return
::requires "LlmPaCore.cls"

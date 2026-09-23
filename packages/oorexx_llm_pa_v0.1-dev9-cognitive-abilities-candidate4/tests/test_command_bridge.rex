parse source . . here
root = filespec("L", here)
store = root || "/bridge-store"
memPath = root || "/bridge-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure"
access = .LlmPaCommandAccessPoint~new(binding, "bridge-secret", "127.0.0.1", 0)
call mustBool access~serveAsync \== .false, "bridge start"
badClient = .LlmPaCommandClient~new("127.0.0.1", access~port, "wrong-secret")
badMade = .LlmPaRequestFactory~create("remember", "BAD", "must not queue", "codex", "LLMPA.REPLY", "bridge-bad")
badSubmit = badClient~submit(badMade~value)
call mustBool \badSubmit~ok & badSubmit~code = "BRIDGE_AUTH_FAILED", "bridge auth fail closed"
call mustBool manager~depth("LLMPA.REQUEST", "gemma")~value["ready"] = 0, "bad auth did not queue"
client = .LlmPaCommandClient~new("127.0.0.1", access~port, "bridge-secret")
made = .LlmPaRequestFactory~create("remember", "SSH", "use the ./sshnode.sh", "codex", "LLMPA.REPLY", "bridge-r1")
call mustBool made~ok, "make request"
submitted = client~submit(made~value)
call mustBool submitted~ok, "client submit"
call mustBool manager~depth("LLMPA.REQUEST", "gemma")~value["ready"] = 1, "persistent queue put"
worker = .LlmPaWorker~new(binding, .LlmPaMemoryStore~new(memPath))
call mustBool worker~processOne~ok, "worker"
reply = client~nextReply
call mustBool reply~ok, "client next reply"
call mustBool reply~value["request_id"] = "bridge-r1", "reply correlation"
call mustBool reply~value["text"]~pos("Remembered SSH. Indexed under:") = 1, "reply text"
ignore = access~stop
address command "rm -rf" store memPath
say "PASS test_command_bridge"
exit 0
must: procedure
  use arg r, label
  if \r~ok then do
    say "FAIL" label r~code r~detail
    exit 1
  end
return
mustBool: procedure
  use arg ok, label
  if \ok then do
    say "FAIL" label
    exit 1
  end
return
::requires "LlmPaWorker.cls"
::requires "LlmPaCommandBridge.cls"
::requires "LlmPaCommandClient.cls"

parse source . . here
root = filespec("L", here)
store = root || "/memory-index-store"
memPath = root || "/memory-index-memory.journal"
address command "rm -rf" store memPath
address command "mkdir -p" store
manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
orch = .IndexOrchestrator~new
worker = .LlmPaWorker~new(binding, memory, orch, "gemma2:2b")

submitted = binding~submit("remember", "for ssh we have a configured script ./sshnode.sh", "")
call must submitted, "submit remember"
call must worker~processOne, "process remember"
reply = binding~collectReply(submitted~value["request_id"])
call must reply, "collect remember"
call mustBool reply~value["memory_index_model_used"] = .true, "Gemma indexed memory"
call mustBool reply~value["lookup_keys_source"] = "gemma:gemma2:2b", "index provenance"
call mustBool hasKey(reply~value["lookup_keys"], "sshnode"), "sshnode key"
call mustBool hasKey(reply~value["lookup_keys"], "sshnode.sh"), "sshnode.sh key"
call mustBool reply~value["text"]~lower~pos("indexed under") > 0, "visible index acknowledgement"

found = memory~remind("sshnode")
call must found, "lookup sshnode"
call mustBool found~value~items = 1, "one indexed fact"
call mustBool found~value[1]["key"]~lower~pos("configured script") > 0, "original fact preserved"

asked = binding~submit("message", "what is the ssh command to use?")
call must asked, "submit ask"
call must worker~processOne, "process ask"
answer = binding~collectReply(asked~value["request_id"])
call must answer, "collect ask"
call mustBool orch~lastPrompt~pos("./sshnode.sh") > 0, "remembered fact supplied to Gemma"
call mustBool orch~lastPrompt~lower~pos("lookup keys:") = 0, "lookup keys remain retrieval metadata"

/* Backward-compatible legacy journal rows acquire deterministic lookup keys
 * when read, so old memories do not become unsearchable after dev6. */
legacyPath = root || "/legacy-memory.journal"
legacyKey = "for ssh we have a configured script ./sshnode.sh"
row = "20260912T14:00:00" || "09"x || c2x(legacyKey) || "09"x || c2x("") || "09"x || c2x("codex") || "09"x || c2x("legacy-r1")
call lineout legacyPath, row
call lineout legacyPath
legacy = .LlmPaMemoryStore~new(legacyPath)
legacyFound = legacy~remind("sshnode")
call must legacyFound, "legacy indexed read"
call mustBool legacyFound~value~items = 1, "legacy fact found by derived key"
call mustBool legacyFound~value[1]["lookup_keys_source"] = "legacy", "legacy provenance"

address command "rm -rf" store memPath legacyPath
say "PASS test_memory_index"
exit 0

hasKey: procedure
  use arg keys, wanted
  do key over keys
    if key~string~caselessEquals(wanted) then return .true
  end
  return .false

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class IndexOrchestrator public
::attribute lastPrompt get
::attribute calls get
::method init
  expose lastPrompt calls
  lastPrompt = ""
  calls = 0
::method runOnce
  expose lastPrompt calls
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  calls += 1
  if prompt~pos("Create a compact lookup index") > 0 then return .LlmPaResult~success(.IndexModelResult~new("KEYS: SSH | sshnode | sshnode.sh | remote access | configured script"))
  return .LlmPaResult~success(.IndexModelResult~new("Use the remembered ./sshnode.sh procedure, Codex."))

::class IndexModelResult public
::attribute text get
::attribute toolExecuted get
::attribute toolName get
::attribute toolCallId get
::method init
  expose text toolExecuted toolName toolCallId
  use arg textArg
  text = textArg
  toolExecuted = .false
  toolName = ""
  toolCallId = ""

::requires "LlmPaWorker.cls"

parse source . . here
root = filespec("L", here)
store = root || "/local-knowledge-store"
memPath = root || "/local-knowledge-memory.journal"
knowledgeRoot = root || "/local-knowledge.d"
address command "rm -rf" store memPath knowledgeRoot
address command "mkdir -p" store knowledgeRoot

/* This is test authority: the command syntax exists in a local knowledge file,
 * not in PA memory and not in the model's prior knowledge. */
doc = knowledgeRoot || "/sshnode.md"
call lineout doc, "# sshnode local procedure"
call lineout doc, "For this installation the approved SSH wrapper is ./sshnode.sh."
call lineout doc, "Authoritative invocation: ./sshnode.sh NODE"
call lineout doc, "Do not replace this with a guessed raw ssh command."
call lineout doc

manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
memory = .LlmPaMemoryStore~new(memPath)
/* Memory deliberately knows only that a tool exists, not invocation syntax. */
call must memory~remember("ssh", "we have a tool for running ssh commands called sshnode", "codex", "r1", .array~of("ssh", "sshnode"), "operator"), "remember ssh"
knowledge = .LlmPaKnowledgeStore~new(knowledgeRoot)
orch = .GroundingOrchestrator~new
worker = .LlmPaWorker~new(binding, memory, orch, "gemma2:2b", .nil, knowledge)

found = knowledge~context("what is the ssh command to use?", 6)
call must found, "knowledge context"
call mustBool found~value~items = 1, "one local knowledge document"
call mustBool found~value[1]["text"]~pos("./sshnode.sh NODE") > 0, "authoritative syntax present"
call mustBool found~value[1]["path"]~right(10) = "sshnode.md", "knowledge provenance path"

q = binding~submit("message", "what is the ssh command to use on ed209?")
call must q, "submit ask"
call must worker~processOne, "process ask"
answer = binding~collectReply(q~value["request_id"])
call must answer, "collect ask"
call mustBool orch~lastPrompt~pos("./sshnode.sh NODE") > 0, "local procedure supplied to Gemma"
call mustBool orch~lastPrompt~pos("we have a tool for running ssh commands called sshnode") > 0, "memory fact supplied"
call mustBool orch~lastPrompt~lower~pos("do not invent") > 0, "grounding rule supplied"
call mustBool orch~lastPrompt~lower~pos("lookup keys:") = 0, "lookup keys hidden from answer prompt"
call mustBool orch~lastPrompt~lower~pos("source=") > 0, "provenance supplied"

/* Direct read lets Codex see what local material is available without model prose. */
k = binding~submit("knowledge", "sshnode")
call must k, "submit knowledge"
call must worker~processOne, "process knowledge"
kr = binding~collectReply(k~value["request_id"])
call must kr, "collect knowledge"
call mustBool kr~value["kind"] = "KNOWLEDGE", "knowledge reply kind"
call mustBool kr~value["knowledge"]~items = 1, "knowledge payload"

address command "rm -rf" store memPath knowledgeRoot
say "PASS test_local_knowledge"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class GroundingOrchestrator public
::attribute lastPrompt get
::method init
  expose lastPrompt
  lastPrompt = ""
::method runOnce
  expose lastPrompt
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  return .LlmPaResult~success(.GroundingModelResult~new("I will use only the supplied facts."))

::class GroundingModelResult public
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
::requires "LlmPaKnowledge.cls"

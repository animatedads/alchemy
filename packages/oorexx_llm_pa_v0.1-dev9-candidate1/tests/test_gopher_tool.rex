parse source . . here
testRoot = filespec("L", here)
packageRoot = directory()
envRoot = testRoot || "/gopher-test-env"
store = testRoot || "/gopher-worker-store"
memPath = testRoot || "/gopher-worker-memory.journal"
address command "rm -rf" envRoot store memPath
address command "mkdir -p" store

gopher = .LlmPaGopherTool~new(packageRoot || "/deps/llm_gopher_v0.21-dev1", packageRoot || "/deps/gopher_spheres", envRoot, packageRoot || "/deps/gopher_catalog.tsv")
call must gopher~probe, "gopher probe"
call mustBool gopher~name = "gopher_read", "tool name"
call mustBool gopher~accessMode = "READ_ONLY", "read only"
call mustBool gopher~eventable, "eventable"
call mustBool \gopher~mutating, "non mutating"
call mustBool gopher~authorityClass = "EVIDENCE_ONLY", "evidence authority"

r = gopher~invoke("What does Queue Fabric say about queue authority and claims?")
call must r, "gopher invoke"
call mustBool r~value["matched"], "matched sphere"
call mustBool r~value["sphere"] = "queue-fabric", "queue fabric sphere"
call mustBool r~value["article_id"] = "queue-fabric.queue-authority", "authority article"
call mustBool r~value["summary"]~pos("Queue manager authority owns internal queue/envelope/UOW mutation") > 0, "project summary"
call mustBool r~value["provenance"]~items > 0, "provenance returned"
call mustBool r~value["provenance"][1]["sha256"] = "05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262", "queue fabric provenance sha"

manager = .ObjectQueueManager~new(store, .QueueGraphPayloadCodec~new, "llmpa-admin")
binding = .LlmPaQueueBinding~new(manager)
call must binding~ensureQueues, "ensure queues"
orch = .CaptureOrchestrator~new
worker = .LlmPaWorker~new(binding, .LlmPaMemoryStore~new(memPath), orch, "gemma2:2b", .nil, .nil, gopher)
q = binding~submit("message", "What does Queue Fabric say about queue authority and claims?")
call must q, "submit"
call must worker~processOne, "process"
reply = binding~collectReply(q~value["request_id"])
call must reply, "collect"
call mustBool reply~value["model_used"], "model used"
call mustBool reply~value["gopher_used"], "gopher used metadata"
call mustBool reply~value["gopher_sphere"] = "queue-fabric", "gopher sphere metadata"
call mustBool reply~value["gopher_article_id"] = "queue-fabric.queue-authority", "gopher article metadata"
call mustBool orch~lastPrompt~pos("Relevant LLM Gopher evidence") > 0, "gopher evidence in prompt"
call mustBool orch~lastPrompt~pos("queue-fabric.queue-authority") > 0, "article in prompt"
call mustBool orch~lastPrompt~pos("05b3cbc92aff353dc3a44eb0373d7efb1e49a5e81071892b410a8b8f63fa2262") > 0, "provenance in prompt"
call mustBool orch~lastPrompt~pos("grants no execution authority") > 0 | orch~lastPrompt~pos("not live state or authority") > 0, "authority boundary in prompt"

/* Direct gopher command returns evidence without asking the model to paraphrase it. */
gq = binding~submit("gopher", "Queue Fabric authority claims")
call must gq, "submit direct gopher"
call must worker~processOne, "process direct gopher"
gr = binding~collectReply(gq~value["request_id"])
call must gr, "collect direct gopher"
call mustBool gr~value["kind"] = "GOPHER", "gopher reply kind"
call mustBool gr~value["gopher"]["sphere"] = "queue-fabric", "direct sphere"

address command "rm -rf" envRoot store memPath
say "PASS test_gopher_tool"
exit 0

must: procedure
  use arg r,label
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 1; end
return
mustBool: procedure
  use arg ok,label
  if \ok then do; say "FAIL" label; exit 1; end
return

::class CaptureOrchestrator public
::attribute lastPrompt get
::method init
  expose lastPrompt
  lastPrompt = ""
::method runOnce
  expose lastPrompt
  use arg modelName, prompt, maxTokens
  lastPrompt = prompt
  return .LlmPaResult~success(.CaptureModelResult~new("Grounded in Gopher evidence."))

::class CaptureModelResult public
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
::requires "LlmPaGopher.cls"
